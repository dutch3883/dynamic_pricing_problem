class Api::V1::PricingController < ApplicationController
  before_action :validate_params

  def index
    period = params[:period]
    hotel  = params[:hotel]
    room   = params[:room]

    service = Api::V1::PricingService.new(period:, hotel:, room:)
    service.run
    if service.valid?
      render json: { rate: service.result }
    elsif service.upstream_error?
      render json: { error: service.errors.join(', ') }, status: :service_unavailable
    else
      render json: { error: service.errors.join(', ') }, status: :bad_request
    end
  end

  private

  def validate_params
    unless params[:period].present? && params[:hotel].present? && params[:room].present?
      return render json: { error: "Missing required parameters: period, hotel, room" }, status: :bad_request
    end

    unless RateApiService::PERIODS.include?(params[:period])
      return render json: { error: "Invalid period. Must be one of: #{RateApiService::PERIODS.join(', ')}" }, status: :bad_request
    end

    unless RateApiService::HOTELS.include?(params[:hotel])
      return render json: { error: "Invalid hotel. Must be one of: #{RateApiService::HOTELS.join(', ')}" }, status: :bad_request
    end

    unless RateApiService::ROOMS.include?(params[:room])
      return render json: { error: "Invalid room. Must be one of: #{RateApiService::ROOMS.join(', ')}" }, status: :bad_request
    end
  end
end
