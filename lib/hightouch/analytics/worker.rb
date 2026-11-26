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
        @lock = Monitor.new
        @ready = @lock.new_cond
        @deferred = []
        @deferred_count = 0
        @limit = options[:max_queue_size] || Defaults::Queue::MAX_SIZE
        @transport = Transport.new(options)
      end

      # public: Continuously runs the loop to check for new events
      #
      def run
        until Thread.current[:should_exit]
          deferred = @lock.synchronize { next_batch }
          return if deferred.nil?

          res = @transport.send(@write_key, @batch, :probe => deferred)
          next if retryable?(res) && park_batch(deferred)

          begin
            @on_error.call(res.status, res.error) unless res.status == 200
          ensure
            @lock.synchronize do
              @deferred_count -= @batch.length if deferred
              @batch.clear
            end
          end
        end
      ensure
        @transport.shutdown
      end

      # public: Check whether we have outstanding requests.
      #
      def is_requesting?
        @lock.synchronize { !@batch.empty? || deferred_ready? }
      end

      def enqueue_if_room(message)
        @lock.synchronize do
          return false if @queue.length + @deferred_count >= @limit

          @queue << message
          @ready.signal
          true
        end
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def deferred_ready?
        !@deferred.empty? && @deferred.first[0] <= now
      end

      def waiting_for_retry?
        @queue.empty? && !@deferred.empty? && !deferred_ready?
      end

      def next_batch
        @ready.wait([@deferred.first[0] - now, 0].max) while waiting_for_retry?
        if deferred_ready? && (@queue.empty? || !@prefer_fresh)
          _, @batch = @deferred.shift
          @prefer_fresh = true
          return true
        end
        return if @queue.empty?

        @prefer_fresh = false
        consume_message_from_queue! until @batch.full? || @queue.empty?
        false
      end

      def retryable?(response)
        (response.status == -1 && response.retryable) || [408, 429].include?(response.status) ||
          (500..599).cover?(response.status)
      end

      def park_batch(reserved)
        @lock.synchronize do
          slots = reserved ? 0 : @batch.length
          return false if @deferred_count + @queue.length + slots > @limit

          @deferred << [now + Defaults::BackoffPolicy::MAX_TIMEOUT_MS / 1000.0, @batch]
          @deferred_count += slots
          @batch = MessageBatch.new(@batch_size)
          true
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
