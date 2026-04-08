# frozen_string_literal: true

require "test_helper"

module Retention
  class ProcessAccountDeletionRequestsJobTest < ActiveJob::TestCase
    test "processes due requests and leaves future requests pending" do
      due_user = users(:manager_two)
      due_user.update!(phone_number: "+5511999990888", cpf_cnpj: "12345678901")
      future_user = users(:secretary)
      due_request = due_user.account_deletion_requests.create!(
        status: :pending,
        requested_at: 8.days.ago,
        scheduled_for: 1.day.ago
      )
      future_request = future_user.account_deletion_requests.create!(
        status: :pending,
        requested_at: Time.current,
        scheduled_for: 2.days.from_now
      )

      ProcessAccountDeletionRequestsJob.perform_now

      assert due_request.reload.completed?
      assert future_request.reload.pending?
      assert_not due_user.reload.active_for_authentication?
    end

    test "is idempotent when run more than once" do
      user = users(:manager_two)
      request = user.account_deletion_requests.create!(
        status: :pending,
        requested_at: 8.days.ago,
        scheduled_for: 1.day.ago
      )

      ProcessAccountDeletionRequestsJob.perform_now
      anonymized_email = user.reload.email

      assert_no_difference "AccountDeletionRequest.pending.count" do
        ProcessAccountDeletionRequestsJob.perform_now
      end

      assert_equal anonymized_email, user.reload.email
      assert request.reload.completed?
    end
  end
end
