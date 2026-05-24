require "test_helper"

class Api::V1::PricingControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  def api_response_for(hotel, rate: "15000")
    rates = RateApiService::PERIODS.flat_map do |period|
      RateApiService::ROOMS.map { |room| { "period" => period, "hotel" => hotel, "room" => room, "rate" => rate } }
    end
    OpenStruct.new(success?: true, body: { "rates" => rates }.to_json)
  end

  test "should get pricing with all parameters" do
    expected_rate = "15000"
    stub = proc { |*| api_response_for("FloatingPointResort", rate: expected_rate) }

    RateApiHttpClient.stub(:post, stub) do
      get api_v1_pricing_url, params: { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }

      assert_response :success
      assert_equal "application/json", @response.media_type
      assert_equal expected_rate, JSON.parse(@response.body)["rate"]
    end
  end

  test "should return error when rate is unavailable" do
    stub = proc { |*| OpenStruct.new(success?: true, body: { "rates" => [] }.to_json) }

    RateApiHttpClient.stub(:post, stub) do
      get api_v1_pricing_url, params: { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }

      assert_response :bad_request
      assert_includes JSON.parse(@response.body)["error"], "Rate unavailable"
    end
  end

  test "should return 503 when upstream times out" do
    RateApiHttpClient.stub(:post, proc { |*| raise Timeout::Error, "execution expired" }) do
      get api_v1_pricing_url, params: { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }

      assert_response 503
      assert_match(/timeout/i, JSON.parse(@response.body)["error"])
    end
  end

  test "should return 503 when upstream exhausts retries with a runtime error" do
    RateApiHttpClient.stub(:post, proc { |*| raise RuntimeError, "HTTP 503" }) do
      get api_v1_pricing_url, params: { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }

      assert_response 503
      body = JSON.parse(@response.body)
      assert body.key?("error"), "Response should have 'error' key"
      assert_no_match(/HTTP 503/, body["error"], "Internal error message must not leak to client")
    end
  end

  test "should return error without any parameters" do
    get api_v1_pricing_url

    assert_response :bad_request
    assert_includes JSON.parse(@response.body)["error"], "Missing required parameters"
  end

  test "should handle empty parameters" do
    get api_v1_pricing_url, params: { period: "", hotel: "", room: "" }

    assert_response :bad_request
    assert_includes JSON.parse(@response.body)["error"], "Missing required parameters"
  end

  test "should reject invalid period" do
    get api_v1_pricing_url, params: { period: "summer-2024", hotel: "FloatingPointResort", room: "SingletonRoom" }

    assert_response :bad_request
    assert_includes JSON.parse(@response.body)["error"], "Invalid period"
  end

  test "should reject invalid hotel" do
    get api_v1_pricing_url, params: { period: "Summer", hotel: "InvalidHotel", room: "SingletonRoom" }

    assert_response :bad_request
    assert_includes JSON.parse(@response.body)["error"], "Invalid hotel"
  end

  test "should reject invalid room" do
    get api_v1_pricing_url, params: { period: "Summer", hotel: "FloatingPointResort", room: "InvalidRoom" }

    assert_response :bad_request
    assert_includes JSON.parse(@response.body)["error"], "Invalid room"
  end
end
