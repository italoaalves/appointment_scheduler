# frozen_string_literal: true

module Platform
  class CreditBundlesController < Platform::BaseController
    before_action :set_bundle, only: [ :show, :edit, :update ]

    def index
      @bundles = Billing::CreditBundle.order(:position)
    end

    def show
      redirect_to edit_platform_credit_bundle_path(@bundle)
    end

    def new
      @bundle = Billing::CreditBundle.new
    end

    def create
      @bundle = Billing::CreditBundle.new(bundle_params)

      if @bundle.save
        redirect_to platform_credit_bundles_path, notice: t("platform.credit_bundles.create.notice")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @bundle.update(bundle_params)
        redirect_to platform_credit_bundles_path, notice: t("platform.credit_bundles.update.notice")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_bundle
      @bundle = Billing::CreditBundle.find(params[:id])
    end

    def bundle_params
      params.require(:credit_bundle).permit(:name, :amount, :price_cents, :position, :active)
    end
  end
end
