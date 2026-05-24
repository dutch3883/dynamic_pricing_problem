require "test_helper"

class RateApiService::CacheTest < ActiveSupport::TestCase
  HOTEL = "FloatingPointResort"

  def build_batch_response
    rates = RateApiService::PERIODS.flat_map do |period|
      RateApiService::ROOMS.map do |room|
        { "period" => period, "hotel" => HOTEL, "room" => room, "rate" => rand(5000..50000).to_s }
      end
    end
    OpenStruct.new(success?: true, body: { "rates" => rates }.to_json)
  end

  def build_service(call_counter: nil, cache_interval: 4.minutes + 30.seconds)
    response_builder = method(:build_batch_response)
    http = Object.new
    http.define_singleton_method(:post_pricing) do |_attrs|
      call_counter[:value] += 1 if call_counter
      response_builder.call
    end
    RateApiService.new(
      strategy: RateApiService::HotelGroupingStrategy::INSTANCE,
      cache_interval: cache_interval,
      http_client: http
    )
  end

  setup do
    Rails.cache.clear
  end

  test "cache miss calls the upstream API" do
    counter = { value: 0 }
    service = build_service(call_counter: counter)

    service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")

    assert_equal 1, counter[:value]
  end

  test "cache hit skips the upstream API on second request" do
    counter = { value: 0 }
    service = build_service(call_counter: counter)

    service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")
    service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")

    assert_equal 1, counter[:value]
  end

  test "first request warms cache for neighbouring rooms in same hotel" do
    counter = { value: 0 }
    service = build_service(call_counter: counter)

    service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")
    service.fetch_rate(period: "Summer", hotel: HOTEL, room: "BooleanTwin")

    assert_equal 1, counter[:value]
  end

  test "expired TTL triggers a fresh upstream call" do
    [30.seconds, 2.minutes, 4.minutes + 30.seconds].each do |interval|
      Rails.cache.clear
      counter = { value: 0 }
      service = build_service(call_counter: counter, cache_interval: interval)

      service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")

      travel(interval - 1.second) do
        service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")
        assert_equal 1, counter[:value], "expected cache hit within TTL=#{interval}s"
      end

      travel(interval + 1.second) do
        service.fetch_rate(period: "Summer", hotel: HOTEL, room: "SingletonRoom")
        assert_equal 2, counter[:value], "expected cache miss after TTL=#{interval}s expired"
      end
    end
  end
end
