# frozen_string_literal: true

require "test_helper"

module Observability
  class UnexpectedErrorReporterTest < ActiveSupport::TestCase
    class DemoJob
      attr_reader :job_id, :queue_name, :priority, :executions, :arguments

      def initialize(job_id:, queue_name:, priority:, executions:, arguments:)
        @job_id = job_id
        @queue_name = queue_name
        @priority = priority
        @executions = executions
        @arguments = arguments
      end
    end

    test "job context filters sensitive arguments and includes runtime metadata" do
      job = DemoJob.new(
        job_id: "job-123",
        queue_name: "default",
        priority: 10,
        executions: 2,
        arguments: [
          {
            email: "maria@example.com",
            phone_number: "+5511999999999",
            nested: { body: "secret note" }
          }
        ]
      )

      context = UnexpectedErrorReporter.decorate_context(
        UnexpectedErrorReporter.job_context(job)
      )

      assert_equal "job-123", context["job_id"]
      assert_equal "Observability::UnexpectedErrorReporterTest::DemoJob", context["job_class"]
      assert_equal "[FILTERED]", context["arguments"][0]["email"]
      assert_equal "[FILTERED]", context["arguments"][0]["phone_number"]
      assert_equal "[FILTERED]", context["arguments"][0]["nested"]["body"]
      assert_equal Rails.env, context[:deployment_environment]
      assert_equal "appointment-scheduler", context[:service_name]
      assert_equal "dev", context[:service_version]
    end

    test "decorate context tolerates nil context" do
      context = UnexpectedErrorReporter.decorate_context(nil)

      assert_equal Rails.env, context[:deployment_environment]
      assert_equal "appointment-scheduler", context[:service_name]
      assert_equal "dev", context[:service_version]
    end

    test "incident payload contains a stable fingerprint and trimmed backtrace" do
      error = RuntimeError.new("boom")
      error.set_backtrace([
        "#{Rails.root}/app/services/example_service.rb:12:in 'call'",
        "/usr/local/lib/ruby/example.rb:1:in 'block in call'"
      ])

      payload = UnexpectedErrorReporter.incident_payload(
        error,
        handled: false,
        severity: :error,
        source: "application.controller",
        context: { request_id: "req-123" }
      )

      assert_equal "unexpected_error", payload[:event]
      assert_equal "application.controller", payload[:source]
      assert_equal "RuntimeError", payload[:exception_class]
      assert_equal "req-123", payload[:context][:request_id]
      assert_equal 64, payload[:fingerprint].length
      assert_equal "#{Rails.root}/app/services/example_service.rb:12:in 'call'", payload[:backtrace].first
    end
  end
end
