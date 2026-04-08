# frozen_string_literal: true

module Platform
  class SpaceCustomersController < Platform::BaseController
    include Platform::SpaceScoped

    def index
      @customers = @space.customers.order(:name).page(params[:page]).per(20)
    end

    def show
      @customer = @space.customers.find(params[:id])
      AuditLogs::EventLogger.call(
        event_type: "privacy.customer_viewed",
        actor: real_current_user,
        space: @space,
        subject: @customer,
        request: request,
        metadata: audit_context_metadata.merge(surface: "platform_customer_show")
      )
      @appointments = @customer.appointments
                               .includes(:space)
                               .where.not(status: :cancelled)
                               .order(scheduled_at: :desc)
                               .page(params[:page])
                               .per(10)
    end
  end
end
