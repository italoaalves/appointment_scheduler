# frozen_string_literal: true

module Tenant
  class CustomersController < Tenant::BaseController
    before_action :set_customer, only: [ :show, :edit, :update, :destroy ]

    def index
      @customers = current_tenant.customers.order(:name)
    end

    def show
      @appointments = @customer.appointments
                               .includes(:space)
                               .where.not(status: :cancelled)
                               .order(scheduled_at: :desc)
                               .page(params[:page])
                               .per(10)
    end

    def new
      @customer = current_tenant.customers.build
    end

    def create
      @customer = current_tenant.customers.build(customer_params)

      if @customer.save
        redirect_to customer_path(@customer), notice: t("space.customers.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @customer.update(customer_params)
        redirect_to customer_path(@customer), notice: t("space.customers.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @customer.destroy
      redirect_to customers_path, notice: t("space.customers.destroy.notice")
    end

    private

    def set_customer
      @customer = current_tenant.customers.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(:name, :phone, :address, :email)
    end
  end
end
