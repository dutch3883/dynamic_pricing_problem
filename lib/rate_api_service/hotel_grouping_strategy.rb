class RateApiService::HotelGroupingStrategy
  include RateApiService::Strategy

  INSTANCE = new.freeze

  def expand(period:, hotel:, room:)
    RateApiService::PERIODS.flat_map { |p| RateApiService::ROOMS.map { |r| { period: p, hotel: hotel, room: r } } }
  end
end
