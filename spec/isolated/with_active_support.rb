# frozen_string_literal: true

require 'spec_helper'
require 'isolated/json_example'

describe 'with active_support', :if => defined?(ActiveSupport) do
  before do
    require 'active_support'
    require 'active_support/json'
  end

  include_examples 'message_batch_json'
end
