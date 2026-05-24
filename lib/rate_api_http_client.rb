class RateApiHttpClient
  include HTTParty
  base_uri ENV.fetch('RATE_API_URL', 'http://localhost:8080')
  headers "Content-Type" => "application/json"
  headers 'token' => ENV.fetch('RATE_API_TOKEN', '04aa6f42aa03f220c2ae9a276cd68c62')

  MAX_RETRIES = 5
  FIBONACCI_DELAYS_MS = [100, 100, 200, 300, 500].freeze

  def post_pricing(attributes)
    attempts = 0
    begin
      attempts += 1
      response = self.class.post("/pricing", body: { attributes: attributes }.to_json, timeout: 2)
      raise "HTTP #{response.code}" unless response.success?
      raise "API error: #{JSON.parse(response.body)['message']}" if error_body?(response)
      response
    rescue => e
      if attempts <= MAX_RETRIES
        delay = FIBONACCI_DELAYS_MS[attempts - 1]
        Rails.logger.warn("[RateApiHttpClient] Attempt #{attempts} failed (#{e.message}), retrying in #{delay}ms")
        wait(delay)
        retry
      end
      Rails.logger.error("[RateApiHttpClient] All #{MAX_RETRIES} retries exhausted")
      raise
    end
  end

  private

  def wait(ms)
    sleep(ms / 1000.0)
  end

  def error_body?(response)
    JSON.parse(response.body)["status"] == "error"
  rescue JSON::ParserError
    false
  end
end
