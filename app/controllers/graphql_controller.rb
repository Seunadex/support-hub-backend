# frozen_string_literal: true

class GraphqlController < ApplicationController
  before_action :authenticate_user!, unless: :public_operation?
  respond_to :json

  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { errors: [ "Invalid CSRF token" ] }, status: :unauthorized
  end

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: @current_user
    }
    result = SupportHubBackendSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  def public_operation?
    return false unless params[:operationName]
    [ "Login", "Signup" ].include?(params[:operationName])
  end

  def authenticate_user!
   header = request.headers["Authorization"]
    token = header&.split(" ")&.last
    return unauthorized unless token

    begin
      secret = Warden::JWTAuth.config.secret
      alg = Warden::JWTAuth.config.algorithm
      decoded = JWT.decode(token, secret, true, { algorithm: alg })
      @token_payload = decoded.first
      @current_user = User.find_by(id: @token_payload["sub"])
      unauthorized unless @current_user
    rescue JWT::ExpiredSignature
      unauthorized("Token expired")
    rescue JWT::DecodeError
      unauthorized("Invalid token")
    end
  end

  def unauthorized(message = "Unauthorized")
    render json: { errors: [ message ] }, status: :unauthorized
  end

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end
end
