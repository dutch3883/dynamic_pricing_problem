require "test_helper"

class HotelGroupingStrategyTest < ActiveSupport::TestCase
  EXPECTED_EXPANSION = [
    { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" },
    { period: "Summer", hotel: "FloatingPointResort", room: "BooleanTwin"   },
    { period: "Summer", hotel: "FloatingPointResort", room: "RestfulKing"   },
    { period: "Autumn", hotel: "FloatingPointResort", room: "SingletonRoom" },
    { period: "Autumn", hotel: "FloatingPointResort", room: "BooleanTwin"   },
    { period: "Autumn", hotel: "FloatingPointResort", room: "RestfulKing"   },
    { period: "Winter", hotel: "FloatingPointResort", room: "SingletonRoom" },
    { period: "Winter", hotel: "FloatingPointResort", room: "BooleanTwin"   },
    { period: "Winter", hotel: "FloatingPointResort", room: "RestfulKing"   },
    { period: "Spring", hotel: "FloatingPointResort", room: "SingletonRoom" },
    { period: "Spring", hotel: "FloatingPointResort", room: "BooleanTwin"   },
    { period: "Spring", hotel: "FloatingPointResort", room: "RestfulKing"   },
  ].freeze

  test "expands to all periods and rooms for the given hotel regardless of input period and room" do
    result = RateApiService::HotelGroupingStrategy::INSTANCE.expand(
      period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom"
    )

    assert_equal EXPECTED_EXPANSION, result
  end
end
