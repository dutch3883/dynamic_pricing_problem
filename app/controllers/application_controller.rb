class ApplicationController < ActionController::API
  rescue_from StandardError, with: :internal_server_error

  def not_found
    render json: { error: "Not found" }, status: :not_found
  end

  private

  def internal_server_error(error)
    render json: { error: error.message }, status: :internal_server_error
  end
end
