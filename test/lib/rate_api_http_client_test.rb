require "test_helper"

class RateApiHttpClientTest < ActiveSupport::TestCase
  ATTRIBUTES = [{ period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }]

  def success_response
    OpenStruct.new(success?: true, body: '{"rates":[]}', code: 200)
  end

  def failure_response
    OpenStruct.new(success?: false, body: '{"error":"unavailable"}', code: 503)
  end

  def soft_failure_response
    OpenStruct.new(success?: true, body: '{"message":"Failed to process rates due to an intermittent issue.","status":"error"}', code: 200)
  end

  test "returns response immediately on success" do
    client = RateApiHttpClient.new
    call_count = 0

    client.stub(:wait, nil) do
      RateApiHttpClient.stub(:post, proc { call_count += 1; success_response }) do
        result = client.post_pricing(ATTRIBUTES)
        assert result.success?
        assert_equal 1, call_count
      end
    end
  end

  test "retries on failure and returns success when retry succeeds" do
    client = RateApiHttpClient.new
    call_count = 0

    client.stub(:wait, nil) do
      RateApiHttpClient.stub(:post, proc { call_count += 1; call_count < 3 ? failure_response : success_response }) do
        result = client.post_pricing(ATTRIBUTES)
        assert result.success?
        assert_equal 3, call_count
      end
    end
  end

  test "raises after exhausting all 5 retries" do
    client = RateApiHttpClient.new
    call_count = 0

    client.stub(:wait, nil) do
      RateApiHttpClient.stub(:post, proc { call_count += 1; failure_response }) do
        assert_raises(RuntimeError) { client.post_pricing(ATTRIBUTES) }
        assert_equal 6, call_count
      end
    end
  end

  test "uses fibonacci delays between retries" do
    client = RateApiHttpClient.new
    delays = []

    client.stub(:wait, ->(ms) { delays << ms }) do
      RateApiHttpClient.stub(:post, proc { failure_response }) do
        assert_raises(RuntimeError) { client.post_pricing(ATTRIBUTES) }
      end
    end

    assert_equal [100, 100, 200, 300, 500], delays
  end

  test "retries on 200 response with status error in body" do
    client = RateApiHttpClient.new
    call_count = 0

    client.stub(:wait, nil) do
      RateApiHttpClient.stub(:post, proc { call_count += 1; call_count < 3 ? soft_failure_response : success_response }) do
        result = client.post_pricing(ATTRIBUTES)
        assert result.success?
        assert_equal 3, call_count
      end
    end
  end

  test "retries on network error" do
    client = RateApiHttpClient.new
    call_count = 0

    client.stub(:wait, nil) do
      RateApiHttpClient.stub(:post, proc { call_count += 1; raise Timeout::Error, "timed out" }) do
        assert_raises(Timeout::Error) { client.post_pricing(ATTRIBUTES) }
        assert_equal 6, call_count
      end
    end
  end
end
