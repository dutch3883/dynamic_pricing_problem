# Dynamic Pricing Service

👉 See [REQUIREMENT.md](REQUIREMENT.md) for the original problem statement.

---

## Quick Start

```bash
docker-compose up -d --build
curl 'http://localhost:3000/api/v1/pricing?period=Summer&hotel=FloatingPointResort&room=SingletonRoom'
# {"rate":"52000"}
```

## API

```
GET /api/v1/pricing
```

| Parameter | Valid values |
|-----------|-------------|
| `period`  | `Summer`, `Autumn`, `Winter`, `Spring` |
| `hotel`   | `FloatingPointResort`, `GitawayHotel`, `RecursionRetreat` |
| `room`    | `SingletonRoom`, `BooleanTwin`, `RestfulKing` |

| Status | Meaning |
|--------|---------|
| `200`  | `{"rate": "52000"}` |
| `400`  | Missing/invalid parameters, or rate unavailable |
| `503`  | Upstream timeout |
| `500`  | Unexpected error |

## Running Tests

```bash
# Full suite
docker-compose run --rm web bundle exec rails test

# Specific file
docker-compose run --rm web bundle exec rails test test/lib/rate_api_service/cache_test.rb
```

## Test Scripts

```bash
./scripts/test_pricing.sh      # all 36 combinations via this service
./scripts/test_rate_api.sh     # all 36 combinations directly against rate API
```

---

## Architecture

```
Request
  └── PricingController          validates params, routes errors (400 / 503 / 500)
        └── PricingService       domain logic, exposes run / result pattern
              └── RateApiService     caching + grouping strategy
                    └── RateApiHttpClient   HTTP, retry with Fibonacci backoff
                          └── External rate API  POST /pricing
```

**Key files**

```
app/controllers/api/v1/pricing_controller.rb
app/services/api/v1/pricing_service.rb
lib/rate_api_service.rb
lib/rate_api_service/hotel_grouping_strategy.rb
lib/rate_api_http_client.rb
```

---

## Staying Under 1,000 API Calls/Day

**The constraint:** 36 combinations (4 periods × 3 hotels × 3 rooms) fetched every 4 minutes = **12,960 naive calls/day** — 13× over budget.

| Approach | Calls/day | Tradeoff |
|----------|-----------|----------|
| One rate per request | 12,960 | Simple, over budget |
| Prefetch all 36 on boot | ~288/day | Needs background job, may over-fetch combinations that are never requested |
| **Hotel-level batching (chosen)** | **≤ 864/day** | One call warms 12 combos for a hotel — fetches only hotels that are actually requested, saving calls vs. prefetching all 36 |
| Period-level batching | ≤ 864/day | Same count, crosses hotel boundaries — less cache-coherent |

**How it works:** When any rate is requested for a hotel, we fetch all 4 periods × 3 rooms for that hotel in one API call (12 rates). All 12 are written to cache together. Subsequent requests for the same hotel within 5 minutes are served from cache.

Worst case: 3 hotels × 1 miss per 5-minute window × 288 windows/day = **864 calls/day**.

The grouping logic lives in `RateApiService::HotelGroupingStrategy` — swappable at the `RateApiService` constructor without touching HTTP or cache code.

---

## Caching

`Rails.cache` backed by **Redis** (configured via `REDIS_URL`). Redis is chosen over the default `:memory_store` because Puma runs multiple worker processes — each with its own isolated memory. With `:memory_store` every worker maintains its own cache, multiplying API calls by worker count. Redis is a single shared store outside the Rails process, so all Puma workers and containers read and write to the same cache, keeping the call budget within ≤ 864/day regardless of how many instances are running.

Each entry stores the rate and a `fetched_at` timestamp via a `CachedRate` struct. TTL is set to **4 minutes 30 seconds** — 30 seconds shorter than the 5-minute validity window to account for processing time and guarantee rates are never served stale. TTL is checked manually (`Time.now - cached.fetched_at < cache_interval`) rather than relying on `expires_in` — makes the window explicit in domain code.

---

## Resilience

The external API fails in three ways — all handled by `RateApiHttpClient`:

| Failure mode | Handling |
|---|---|
| HTTP 5xx | Retry |
| `200` with `{"status":"error"}` body (soft failure) | Detected and retried |
| Network hang / timeout | 2s request timeout, then retry |

**Retry policy:** 5 retries with Fibonacci backoff `[100, 100, 200, 300, 500]` ms. Worst case ~13s per request. After all retries exhausted the error propagates — controller returns 400 (rate unavailable) or 503 (timeout).

---

## Tests

```
test/controllers/api/v1/pricing_controller_test.rb        input validation, HTTP contract
test/controllers/routing_test.rb                          unknown routes return 404 JSON
test/lib/rate_api_http_client_test.rb                     retry, Fibonacci delays, soft failure
test/lib/rate_api_service/cache_test.rb                   cache hit/miss/TTL/warming
test/lib/rate_api_service/hotel_grouping_strategy_test.rb expansion correctness
test/services/api/v1/pricing_service_test.rb              quota: ≤1000 calls/day simulation
```

Cache and retry tests inject a fake `http_client` via constructor — no global class-method patching, no thread-safety concerns.

---

## Key Tradeoffs

**Block fetch strategy over full prefetch:** Rather than fetching all 36 combinations at once, we use a block fetch strategy — one API call per hotel, warming 12 combinations (all periods × rooms for that hotel). This is adjustable: the grouping strategy is injected at construction and can be swapped without touching cache or HTTP code. In the worst case (all hotels accessed within the same window) it makes the same number of calls as full prefetch. In the average case it's cheaper — it's unlikely all hotels are accessed within a single 4.5-minute window, but data for the same hotel has high locality (a user browsing rooms at one hotel will likely request multiple period/room combinations). Block fetch exploits that locality without over-fetching data that may never be requested.

---

## Improvement Ideas

**Background cache refresh:** A single background job (e.g. Sidekiq + cron) could prefetch all 36 combinations every 4 minutes, keeping the cache always warm. This would decouple fetching from request handling entirely and guarantee the budget is exactly 36 calls per 4-minute window rather than up to 864 in the worst case.

---

## AI Assistance

This solution was developed using [Claude Code](https://claude.ai/code) (Anthropic's CLI coding assistant) as a tool to translate my thinking into working code more efficiently.

All core decisions — the batching strategy, the layer decomposition, the caching model, the retry policy — were my own. I used Claude to implement what I had already reasoned through: I described the design I wanted, Claude wrote the code, and I reviewed, questioned, and corrected it at each step.

**Examples of how this played out in practice:**

- I decided to split HTTP and caching into separate classes (`RateApiHttpClient` / `RateApiService`) so each could be tested independently via constructor injection — Claude translated that structure into Ruby
- I chose hotel-level batching after working through the call-budget math myself (36 combos × 288 windows = 12,960 naive calls/day; hotel grouping brings that to ≤ 864) — Claude helped express the tradeoff table in the README
- I specified Fibonacci backoff starting at 100ms with 5 retries — Claude implemented the delay array and retry loop
- When a bug appeared (cached nil rates returning 400, or the `define_singleton_method` closure failing), I diagnosed the cause and directed the fix — Claude applied it

Claude also ran an independent code review pass, which flagged that non-timeout upstream errors were bubbling as 500s instead of 503. I understood the issue immediately (the rescue clause was too narrow) and approved the fix.