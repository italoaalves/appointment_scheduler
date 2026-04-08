# frozen_string_literal: true

module Retention
  class ProcessAccountDeletionRequestsJob < ApplicationJob
    queue_as :default

    def perform
      AccountDeletionRequest.due.find_each do |request|
        AccountDeletionRequests::Executor.call(request: request)
      end
    end
  end
end
