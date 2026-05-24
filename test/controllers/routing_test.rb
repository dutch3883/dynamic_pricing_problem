require "test_helper"

class RoutingTest < ActionDispatch::IntegrationTest
  test "unknown route returns 404 JSON" do
    get "/unknown/endpoint"

    assert_response :not_found
    assert_equal "application/json", @response.media_type
    assert_includes JSON.parse(@response.body)["error"], "Not found"
  end

  test "unknown route with any HTTP method returns 404 JSON" do
    post "/nonexistent"

    assert_response :not_found
    assert_equal "application/json", @response.media_type
  end
end
