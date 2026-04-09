# frozen_string_literal: true

require "test_helper"

module Auth
  module Mfa
    module Webauthn
      class GenerateRegistrationOptionsTest < ActiveSupport::TestCase
        test "generates options and stores a registration challenge" do
          user = users(:admin)
          session = {}

          options = GenerateRegistrationOptions.call(user:, session:)

          assert options.challenge.present?
          assert_equal options.challenge, Auth::PendingMfaSession.passkey_registration_challenge(session:)
          assert user.reload.webauthn_id.present?
        end
      end
    end
  end
end
