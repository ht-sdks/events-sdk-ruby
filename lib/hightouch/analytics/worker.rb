# frozen_string_literal: true

require 'monitor'
require 'hightouch/analytics/defaults'
require 'hightouch/analytics/message_batch'
require 'hightouch/analytics/transport'
require 'hightouch/analytics/utils'

module Hightouch
  class Analytics
    class Worker
      include Hightouch::Analytics::Utils
      include Hightouch::Analytics::Defaults
      include Hightouch::Analytics::Logging

      # public: Creates a new worker
      #
      # The worker continuously takes messages off the queue
      # and makes requests to the hightouch api
      #
      # queue   - Queue synchronized between client and worker
      # write_key  - String of the project's Write key
      # options - Hash of worker options
      #           batch_size - Fixnum of how many items to send in a batch
      #           on_error   - Proc of what to do on an error
      #
      def initialize(queue, write_key, options = {})
        symbolize_keys! options
        @queue = queue
        @write_key = write_key
        @on_error = options[:on_error] || proc { |status, error| }
        @batch_size = options[:batch_size] || Defaults::MessageBatch::MAX_SIZE
        @batch = MessageBatch.new(@batch_size)
        @deferred = []
        @deferred_count = 0
        @prefer_fresh = false
        @retry_at = 0
        @lock = Monitor.new
        @transport = Transport.new(options)
        @retry_delay = 1
      end

      # public: Continuously runs the loop to check for new events
      #
      def run
        until Thread.current[:should_exit]
          remaining = @retry_at - monotonic_time
          return remaining if remaining > 0

          probe = @lock.synchronize { @batch.empty? ? select_batch : true }
          return if probe.nil?

          res = @transport.send(@write_key, @batch, :probe => probe)
          delay = defer_if_retryable(res)
          begin
            report_error(res, delay) unless res.status == 200
          ensure
            @lock.synchronize { @batch.clear } unless delay
          end
          return delay if delay
        end
      ensure
        @transport.shutdown
      end

      # public: Check whether we have outstanding requests.
      #
      def is_requesting?
        @lock.synchronize { !@batch.empty? || !@deferred.empty? }
      end

      def enqueue_if_room(message, limit)
        @lock.synchronize do
          in_flight = @probing ? @batch.length : 0
          return false if @queue.length + @deferred_count + in_flight >= limit

          @queue << message
          true
        end
      end

      private

      def report_error(res, delay)
        @on_error.call(res.status, res.error)
      rescue StandardError => e
        raise unless delay

        logger.warn("Error handler raised while a batch was pending: #{e}")
      end

      def select_batch
        return if @queue.empty? && @deferred.empty?

        @probing = !@deferred.empty?
        if @probing && (@queue.empty? || !@prefer_fresh)
          @batch = @deferred.shift
          @deferred_count -= @batch.length
          @prefer_fresh = true
          return true
        end

        consume_message_from_queue! until @batch.full? || @queue.empty?
        @prefer_fresh = false
        @probing
      end

      def monotonic_time
        return Time.now.to_f unless Process.respond_to?(:clock_gettime)

        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def defer_if_retryable(res)
        if (res.status == -1 && res.retryable) || [408, 429].include?(res.status) || (500..599).cover?(res.status)
          delay = @retry_delay
          @retry_delay = [delay * 2, 60].min
          logger.warn("Collector returned #{res.status}. Retaining batch for retry in #{delay}s.")
          @lock.synchronize do
            @deferred << @batch
            @deferred_count += @batch.length
            @batch = MessageBatch.new(@batch_size)
            @retry_at = monotonic_time + delay
          end
          return delay
        end
        @retry_delay = 1
        nil
      end

      def consume_message_from_queue!
        @batch << @queue.pop
      rescue MessageBatch::JSONGenerationError => e
        @on_error.call(-1, e.to_s)
      end
    end
  end
end
