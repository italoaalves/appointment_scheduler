# frozen_string_literal: true

module AccountDeletionRequests
  class Canceler
    Result = Struct.new(:success?, :request, :error, keyword_init: true)

    def self.call(user:, actor: nil, request: nil, metadata: {})
      new(user:, actor:, request:, metadata:).call
    end

    def initialize(user:, actor:, request:, metadata:)
      @user = user
      @actor = actor
      @request_context = request
      @metadata = metadata
    end

    def call
      request = @user.account_deletion_requests.active.first
      return Result.new(success?: false, error: :not_found) unless request

      request.update!(status: :canceled, canceled_at: Time.current)
      AuditLogs::EventLogger.call(
        event_type: "privacy.deletion_canceled",
        actor: @actor,
        space: @user.space,
        subject: @user,
        auditable: request,
        request: @request_context,
        impersonated: @metadata[:impersonated] || false,
        metadata: @metadata.except(:impersonated)
      )
      Result.new(success?: true, request:)
    end
  end
end
