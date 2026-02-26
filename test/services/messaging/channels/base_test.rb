# frozen_string_literal: true

require "test_helper"

module Messaging
  module Channels
    class BaseTest < ActiveSupport::TestCase
      test "raise NotImplementedError when deliver is not implemented" do
        assert_raises(NotImplementedError) do
          Base.new.deliver(to: nil, body: "")
        end
      end
    end
  end
end
