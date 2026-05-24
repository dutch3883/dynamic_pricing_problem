require "test_helper"

class Api::V1::PricingServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "hotel-grouping strategy stays under 1000 API calls fetching all 36 rates every 4 minutes for a day" do
    all_combinations = RateApiService::PERIODS.flat_map do |period|
      RateApiService::HOTELS.flat_map do |hotel|
        RateApiService::ROOMS.map { |room| { period: period, hotel: hotel, room: room } }
      end
    end

    call_count = 0
    http = Object.new
    http.define_singleton_method(:post_pricing) do |attributes|
      hotel = attributes.first[:hotel]
      call_count += 1
      rates = RateApiService::PERIODS.flat_map do |period|
        RateApiService::ROOMS.map { |room| { "period" => period, "hotel" => hotel, "room" => room, "rate" => "15000" } }
      end
      OpenStruct.new(success?: true, body: { "rates" => rates }.to_json)
    end

    rate_service = RateApiService.new(
      strategy: RateApiService::HotelGroupingStrategy::INSTANCE,
      cache_interval: 4.minutes + 30.seconds,
      http_client: http
    )

    start_time = Time.now
    (24 * 60 / 4).times do |round|
      travel_to(start_time + round * 4.minutes) do
        all_combinations.each do |combo|
          Api::V1::PricingService.new(**combo, client: rate_service).run
        end
      end
    end

    puts "call count: #{call_count}"

    assert call_count <= 1000,
      "Expected ≤ 1000 API calls per day, got #{call_count}"
  end
end
