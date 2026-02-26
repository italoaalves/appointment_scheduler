# frozen_string_literal: true

module Platform
  class SpaceCustomersController < Platform::BaseController
    include Platform::SpaceScoped

    def index
      @customers = @space.customers.order(:name).page(params[:page]).per(20)
    end

    def show
      @customer = @space.customers.find(params[:id])
      @appointments = @customer.appointments
                               .includes(:space)
                               .where.not(status: :cancelled)
                               .order(scheduled_at: :desc)
                               .page(params[:page])
                               .per(10)
    end
  end
end
