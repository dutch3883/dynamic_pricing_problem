class RateApiService
  PERIODS = %w[Summer Autumn Winter Spring].freeze
  HOTELS  = %w[FloatingPointResort GitawayHotel RecursionRetreat].freeze
  ROOMS   = %w[SingletonRoom BooleanTwin RestfulKing].freeze

  CachedRate = Struct.new(:rate, :fetched_at)

  def initialize(strategy:, cache_interval:, http_client: RateApiHttpClient.new)
    @strategy       = strategy
    @cache_interval = cache_interval
    @http_client    = http_client
  end

  def fetch_rate(period:, hotel:, room:)
    cache_key = "rate:#{period}:#{hotel}:#{room}"
    cached = Rails.cache.read(cache_key)

    if cached && cached.rate && Time.now - cached.fetched_at < @cache_interval
      Rails.logger.debug("[RateApiService] CACHE HIT  #{cache_key}")
      return cached.rate
    end

    Rails.logger.debug("[RateApiService] CACHE MISS #{cache_key} — fetching from API")
    attributes = @strategy.expand(period: period, hotel: hotel, room: room)
    response = @http_client.post_pricing(attributes)

    if response.success?
      rates = JSON.parse(response.body)["rates"]
      return unless rates
      cache_all(rates)
      Rails.cache.read(cache_key)&.rate
    end
  end

  private

  def cache_all(rates)
    fetched_at = Time.now
    rates.each do |r|
      next unless r['rate']
      key = "rate:#{r['period']}:#{r['hotel']}:#{r['room']}"
      Rails.cache.write(key, CachedRate.new(r['rate'], fetched_at))
    end
  end
end
