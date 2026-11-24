# frozen_string_literal: true

module Hightouch
  class Analytics
    class Response
      attr_reader :status, :error, :retryable

      # public: Simple class to wrap responses from the API
      #
      #
      def initialize(status = 200, error = nil, retryable: true)
        @status = status
        @error  = error
        @retryable = retryable
      end
    end
  end
end
