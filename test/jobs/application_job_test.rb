# frozen_string_literal: true

require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  class FailingJob < ApplicationJob
    def perform(payload)
      raise ArgumentError, "could not process #{payload[:email]}"
    end
  end

  test "reports unexpected job failures with filtered context before raising" do
    reports = capture_error_reports(ArgumentError) do
      assert_raises(ArgumentError) do
        FailingJob.perform_now(email: "maria@example.com", phone_number: "+5511999999999")
      end
    end

    report = reports.find { |entry| entry.source == "application.active_job" }
    assert report, "Expected an unexpected Active Job error to be reported"
    assert_equal false, report.handled?
    assert_equal :error, report.severity
    arguments = report.context["arguments"] || report.context[:arguments]
    job_class = report.context["job_class"] || report.context[:job_class]

    assert_equal "[FILTERED]", arguments[0]["email"]
    assert_equal "[FILTERED]", arguments[0]["phone_number"]
    assert_equal "ApplicationJobTest::FailingJob", job_class
  end
end
