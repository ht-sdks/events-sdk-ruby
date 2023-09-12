# frozen_string_literal: true

require 'hightouch/analytics/version'
require 'hightouch/analytics/defaults'
require 'hightouch/analytics/utils'
require 'hightouch/analytics/field_parser'
require 'hightouch/analytics/client'
require 'hightouch/analytics/worker'
require 'hightouch/analytics/transport'
require 'hightouch/analytics/response'
require 'hightouch/analytics/logging'
require 'hightouch/analytics/test_queue'

module Hightouch
  class Analytics
    # Initializes a new instance of {Hightouch::Analytics::Client}, to which all
    # method calls are proxied.
    #
    # @param options includes options that are passed down to
    #   {Hightouch::Analytics::Client#initialize}
    # @option options [Boolean] :stub (false) If true, requests don't hit the
    #   server and are stubbed to be successful.
    def initialize(options = {})
      Transport.stub = options[:stub] if options.has_key?(:stub)
      @client = Hightouch::Analytics::Client.new options
    end

    def method_missing(message, *args, &block)
      if @client.respond_to? message
        @client.send message, *args, &block
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @client.respond_to?(method_name) || super
    end

    include Logging
  end
end
