ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "ostruct"

module ActiveSupport
  class TestCase
    # Default to serial execution because PostgreSQL fixture reloads are not
    # deterministic under multi-process test runs in this environment.
    workers = ENV.fetch("PARALLEL_WORKERS", "1").to_i
    parallelize(workers: workers) if workers > 1

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
