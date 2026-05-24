module RateApiService::Strategy
  def expand(period:, hotel:, room:)
    raise NotImplementedError, "#{self.class} must implement #expand"
  end
end
