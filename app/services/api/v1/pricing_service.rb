module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:, client: RateApiService.new(strategy: RateApiService::HotelGroupingStrategy::INSTANCE, cache_interval: 4.minutes + 30.seconds))
      @period = period
      @hotel  = hotel
      @room   = room
      @client = client
    end

    def run
      @result = @client.fetch_rate(period: @period, hotel: @hotel, room: @room)
      errors << "Rate unavailable" unless @result
    rescue Timeout::Error => e
      Rails.logger.error("[PricingService] Timeout: #{e.message}")
      errors << "Upstream timeout"
      @upstream_error = true
    rescue => e
      Rails.logger.error("[PricingService] Upstream failure: #{e.message}")
      errors << "Upstream error"
      @upstream_error = true
    end
  end
end
