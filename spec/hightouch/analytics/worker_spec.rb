# frozen_string_literal: true

require 'spec_helper'

module Hightouch
  class Analytics
    describe Worker do
      before do
        Hightouch::Analytics::Transport.stub = true
      end

      describe '#init' do
        it 'accepts string keys' do
          queue = Queue.new
          worker = Hightouch::Analytics::Worker.new(queue,
                                                    'secret',
                                                    'batch_size' => 100)
          batch = worker.instance_variable_get(:@batch)
          expect(batch.instance_variable_get(:@max_message_count)).to eq(100)
        end
      end

      describe '#run' do
        before :all do
          Hightouch::Analytics::Defaults::Request::BACKOFF = 0.1
        end

        after :all do
          Hightouch::Analytics::Defaults::Request::BACKOFF = 30.0
        end

        it 'can upload when the runtime has no monotonic clock' do
          queue = Queue.new
          queue << Requested::TRACK
          worker = described_class.new(queue, 'original')
          allow(Process).to receive(:respond_to?).and_call_original
          allow(Process).to receive(:respond_to?).with(:clock_gettime).and_return(false)
          expect(worker.instance_variable_get(:@transport)).to receive(:send).and_return(Response.new(200))
          worker.run
          expect(queue).to be_empty
        end

        it 'lets fresh work pass a failing batch only after the source cooldown' do
          queue = Queue.new
          queue << Requested::TRACK
          now = 0
          on_error = proc do |status, _|
            if status == 429
              now += 1
              raise 'listener'
            end
          end
          worker = described_class.new(queue, 'original', :on_error => on_error)
          transport = worker.instance_variable_get(:@transport)
          batch = worker.instance_variable_get(:@batch)
          allow(worker).to receive(:monotonic_time) { now }
          expect(transport).to receive(:send).with('original', batch, probe: false).ordered.and_return(Response.new(408))
          expect(transport).to receive(:send).with('original', batch, probe: true).ordered do
            expect(worker.enqueue_if_room({ 'id' => 'overflow' }, 1)).to be(false)
            Response.new(429)
          end
          expect(transport).to receive(:send).ordered do |key, fresh, opts|
            expect([key, JSON.parse(fresh.to_json), opts]).to eq(['original', [{ 'id' => 'B' }], { :probe => true }])
            Response.new(200)
          end
          expect(transport).to receive(:send).with('original', batch, probe: true).ordered.and_return(Response.new(200))

          expect(worker.run).to eq(1)
          now = 1
          expect(worker.run).to eq(2)
          expect(worker.enqueue_if_room({ 'id' => 'B' }, 1)).to be(false)
          expect(worker.enqueue_if_room({ 'id' => 'B' }, 2)).to be(true)
          expect(worker.run).to eq(1)
          expect(worker.is_requesting?).to be(true)
          now = 3
          worker.run
          expect(worker.is_requesting?).to be(false)
          expect(worker.enqueue_if_room({ 'id' => 'C' }, 1)).to be(true)
        end

        it 'does not error if the request fails' do
          expect do
            Hightouch::Analytics::Transport
              .any_instance
              .stub(:send)
              .and_return(Hightouch::Analytics::Response.new(-1, 'Unknown error'))

            queue = Queue.new
            queue << {}
            worker = Hightouch::Analytics::Worker.new(queue, 'secret')
            worker.run

            expect(queue).to be_empty

            Hightouch::Analytics::Transport.any_instance.unstub(:send)
          end.to_not raise_error
        end

        it 'executes the error handler if the request is invalid' do
          Hightouch::Analytics::Transport
            .any_instance
            .stub(:send)
            .and_return(Hightouch::Analytics::Response.new(400, 'Some error'))

          status = error = nil
          on_error = proc do |yielded_status, yielded_error|
            sleep 0.2 # Make this take longer than thread spin-up (below)
            status, error = yielded_status, yielded_error
          end

          queue = Queue.new
          queue << {}
          worker = described_class.new(queue, 'secret', :on_error => on_error)

          # This is to ensure that Client#flush doesn't finish before calling
          # the error handler.
          Thread.new { worker.run }
          sleep 0.1 # First give thread time to spin-up.
          sleep 0.01 while worker.is_requesting?

          Hightouch::Analytics::Transport.any_instance.unstub(:send)

          expect(queue).to be_empty
          expect(status).to eq(400)
          expect(error).to eq('Some error')
        end

        it 'does not call on_error if the request is good' do
          on_error = proc do |status, error|
            puts "#{status}, #{error}"
          end

          expect(on_error).to_not receive(:call)

          queue = Queue.new
          queue << Requested::TRACK
          worker = described_class.new(queue,
                                       'testsecret',
                                       :on_error => on_error)
          worker.run

          expect(queue).to be_empty
        end

        it 'calls on_error for bad json' do
          bad_obj = Object.new
          def bad_obj.to_json(*_args)
            raise "can't serialize to json"
          end

          on_error = proc {}
          expect(on_error).to receive(:call).once.with(-1, /serialize to json/)

          good_message = Requested::TRACK
          bad_message = Requested::TRACK.merge({ 'bad_obj' => bad_obj })

          queue = Queue.new
          queue << good_message
          queue << bad_message

          worker = described_class.new(queue,
                                       'testsecret',
                                       :on_error => on_error)
          worker.run
          expect(queue).to be_empty
        end
      end

      describe '#is_requesting?' do
        it 'does not return true if there isn\'t a current batch' do
          queue = Queue.new
          worker = Hightouch::Analytics::Worker.new(queue, 'testsecret')

          expect(worker.is_requesting?).to eq(false)
        end

        it 'returns true if there is a current batch' do
          send_started = Queue.new
          Hightouch::Analytics::Transport
            .any_instance
            .stub(:send) {
              send_started << true
              sleep(0.2)
              Hightouch::Analytics::Response.new(200, 'Success')
            }

          queue = Queue.new
          queue << Requested::TRACK
          worker = Hightouch::Analytics::Worker.new(queue, 'testsecret')

          worker_thread = Thread.new { worker.run }
          send_started.pop
          expect(worker.is_requesting?).to eq(true)

          worker_thread.join
          expect(worker.is_requesting?).to eq(false)

          Hightouch::Analytics::Transport.any_instance.unstub(:send)
        end
      end
    end
  end
end
