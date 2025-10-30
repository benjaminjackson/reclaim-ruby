# frozen_string_literal: true

module Reclaim
  # Base exception class for all Reclaim-related errors
  class Error < StandardError; end

  # Authentication-related errors
  class AuthenticationError < Error; end

  # API-related errors (network issues, invalid responses, etc.)
  class ApiError < Error
    attr_reader :status_code, :response_body

    def initialize(message, status_code = nil, response_body = nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
    end
  end

  # Resource not found errors
  class NotFoundError < Error; end

  # Invalid record/validation errors
  class InvalidRecordError < Error; end
end
