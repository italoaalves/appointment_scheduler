ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "omniauth"
require "ostruct"
require "webauthn"
require "webauthn/fake_client"

OmniAuth.config.test_mode = true

module OmniAuthTestHelpers
  def omniauth_hash(provider:, uid:, email:, name: "Social User", email_verified: true)
    OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: {
        email: email,
        name: name,
        email_verified: email_verified
      },
      extra: {
        raw_info: {
          email: email,
          email_verified: email_verified,
          sub: uid
        }
      }
    )
  end
end

module WebAuthnTestHelpers
  def webauthn_fake_client(origin: Array(WebAuthn.configuration.allowed_origins).first)
    WebAuthn::FakeClient.new(origin)
  end
end

module ActiveSupport
  class TestCase
    # Default to serial execution because PostgreSQL fixture reloads are not
    # deterministic under multi-process test runs in this environment.
    workers = ENV.fetch("PARALLEL_WORKERS", "1").to_i
    parallelize(workers: workers) if workers > 1

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include OmniAuthTestHelpers
    include WebAuthnTestHelpers
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def sign_in(resource, scope: nil, mfa_verified: nil)
    super(resource, scope: scope)

    return unless mfa_verified.nil? ? resource.respond_to?(:super_admin?) && resource.super_admin? : mfa_verified

    Warden.on_next_request do |proxy|
      proxy.request.session["auth.mfa_verified_user_id"] = resource.id
      proxy.request.session["auth.mfa_verified_at"] = Time.current.to_i
    end
  end

  teardown do
    OmniAuth.config.mock_auth.clear
  end
end
