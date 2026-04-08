# frozen_string_literal: true

module AccountDeletionRequests
  class Canceler
    Result = Struct.new(:success?, :request, :error, keyword_init: true)

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      request = @user.account_deletion_requests.active.first
      return Result.new(success?: false, error: :not_found) unless request

      request.update!(status: :canceled, canceled_at: Time.current)
      Result.new(success?: true, request:)
    end
  end
end
