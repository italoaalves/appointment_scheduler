# frozen_string_literal: true

module Admin
  class ClientsController < Admin::BaseController
    before_action :set_client, only: [ :show, :edit, :update, :destroy ]

    def index
      @clients = current_tenant.clients.order(:name)
    end

    def show
      @appointments = @client.appointments
                            .includes(:space)
                            .where.not(status: :cancelled)
                            .order(scheduled_at: :desc)
                            .page(params[:page])
                            .per(10)
    end

    def new
      @client = current_tenant.clients.build
    end

    def create
      @client = current_tenant.clients.build(client_params)

      if @client.save
        redirect_to admin_client_path(@client), notice: t("admin.clients.create.notice")
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @client.update(client_params)
        redirect_to admin_client_path(@client), notice: t("admin.clients.update.notice")
      else
        render :edit
      end
    end

    def destroy
      @client.destroy
      redirect_to admin_clients_path, notice: t("admin.clients.destroy.notice")
    end

    private

    def set_client
      @client = current_tenant.clients.find(params[:id])
    end

    def client_params
      params.require(:client).permit(:name, :phone, :address)
    end
  end
end
