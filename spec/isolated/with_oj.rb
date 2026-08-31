# frozen_string_literal: true

require 'spec_helper'
require 'isolated/json_example'

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7') && RUBY_PLATFORM != 'java'
  describe 'with oj' do
    before do
      require 'oj'
      Oj.mimic_JSON
    end

    include_examples 'message_batch_json'
  end
end
