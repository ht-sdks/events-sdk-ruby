# frozen_string_literal: true

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
        batch_size = options[:batch_size] || Defaults::MessageBatch::MAX_SIZE
        @batch = MessageBatch.new(batch_size)
        @lock = Mutex.new
        @transport = Transport.new(options)
        @retry_delay = 1
      end

      # public: Continuously runs the loop to check for new events
      #
      def run
        until Thread.current[:should_exit]
          return if @queue.empty? && @batch.empty?

          fill_batch if @batch.empty?

          delay = deliver_batch
          return delay if delay

          @lock.synchronize { @batch.clear }
        end
      ensure
        @transport.shutdown
      end

      # public: Check whether we have outstanding requests.
      #
      def is_requesting?
        @lock.synchronize { !@batch.empty? }
      end

      private

      def deliver_batch
        res = @transport.send(@write_key, @batch, :probe => @retry_delay > 1)
        @on_error.call(res.status, res.error) unless res.status == 200
        if (res.status == -1 && res.retryable) || [408, 429].include?(res.status) || (500..599).cover?(res.status)
          delay = @retry_delay
          @retry_delay = [delay * 2, 60].min
          logger.warn("Collector returned #{res.status}. Retaining batch for retry in #{delay}s.")
          return delay
        end
        @retry_delay = 1
        nil
      end

      def fill_batch
        @lock.synchronize do
          consume_message_from_queue! until @batch.full? || @queue.empty?
        end
      end

      def consume_message_from_queue!
        @batch << @queue.pop
      rescue MessageBatch::JSONGenerationError => e
        @on_error.call(-1, e.to_s)
      end
    end
  end
end
