# frozen_string_literal: true

require "test_helper"

module Whatsapp
  class VerifyOwnershipTest < ActiveSupport::TestCase
    def setup
      @phone_number_id = "12345678"
      @waba_id = "waba_abc"
    end

    test "returns success when phone_number_id and waba_id match" do
      service = service_with_response(
        "id" => @phone_number_id,
        "whatsapp_business_account" => { "id" => @waba_id }
      )

      result = service.call(phone_number_id: @phone_number_id, waba_id: @waba_id)

      assert result.success?
      assert_nil result.error
    end

    test "returns failure when phone_number_id does not match" do
      service = service_with_response(
        "id" => "different_id",
        "whatsapp_business_account" => { "id" => @waba_id }
      )

      result = service.call(phone_number_id: @phone_number_id, waba_id: @waba_id)

      assert_not result.success?
      assert_equal "Phone number ID mismatch", result.error
    end

    test "returns failure when waba_id does not match" do
      service = service_with_response(
        "id" => @phone_number_id,
        "whatsapp_business_account" => { "id" => "wrong_waba" }
      )

      result = service.call(phone_number_id: @phone_number_id, waba_id: @waba_id)

      assert_not result.success?
      assert_equal "WABA ID mismatch", result.error
    end

    test "returns failure on API error" do
      service = service_raising(Whatsapp::Client::ApiError.new("Unauthorized"))

      result = service.call(phone_number_id: @phone_number_id, waba_id: @waba_id)

      assert_not result.success?
      assert_equal "Unauthorized", result.error
    end

    test "returns failure on unexpected error" do
      service = service_raising(StandardError.new("Network error"))

      result = service.call(phone_number_id: @phone_number_id, waba_id: @waba_id)

      assert_not result.success?
      assert_equal "Verification failed", result.error
    end

    private

    def service_with_response(response_hash)
      service = Whatsapp::VerifyOwnership.new
      service.define_singleton_method(:fetch_phone_number) { |_id| response_hash }
      service
    end

    def service_raising(error)
      service = Whatsapp::VerifyOwnership.new
      service.define_singleton_method(:fetch_phone_number) { |_id| raise error }
      service
    end
  end
end
