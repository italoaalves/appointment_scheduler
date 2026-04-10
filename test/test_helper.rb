ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "base64"
require "fileutils"
require "minitest/mock"
require "omniauth"
require "ostruct"
require "rack/test"
require "tempfile"
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

module UploadTestHelpers
  TINY_PNG_DATA = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==")

  def image_upload(filename: "image.png", content_type: "image/png", data: TINY_PNG_DATA)
    build_uploaded_file(filename:, content_type:, data:)
  end

  def text_upload(filename: "notes.txt", content_type: "text/plain", data: "not an image")
    build_uploaded_file(filename:, content_type:, data:)
  end

  def cleanup_uploaded_file_fixtures!
    Array(@uploaded_file_tempfiles).each do |tempfile|
      tempfile.close!
    rescue Errno::ENOENT
      nil
    end

    @uploaded_file_tempfiles = []
    FileUtils.rm_rf(Rails.root.join("tmp/stored_files"))
  end

  private

  def build_uploaded_file(filename:, content_type:, data:)
    basename = File.basename(filename, File.extname(filename))
    extension = File.extname(filename)
    tempfile = Tempfile.new([ basename, extension ])
    tempfile.binmode
    tempfile.write(data)
    tempfile.rewind

    @uploaded_file_tempfiles ||= []
    @uploaded_file_tempfiles << tempfile

    Rack::Test::UploadedFile.new(tempfile.path, content_type, true, original_filename: filename)
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
    include UploadTestHelpers

    teardown do
      cleanup_uploaded_file_fixtures!
    end
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
