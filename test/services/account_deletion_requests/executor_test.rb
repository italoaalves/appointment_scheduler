# frozen_string_literal: true

require "test_helper"

module AccountDeletionRequests
  class ExecutorTest < ActiveSupport::TestCase
    setup do
      @user = users(:manager)
      @user.update_columns(phone_number: "+5511999990777", cpf_cnpj: "12345678901", updated_at: Time.current)
      @user.create_user_preference!(locale: "pt-BR") unless @user.user_preference
      customers(:one).update!(user: @user)
      conversations(:needs_reply_one).update!(assigned_to: @user)
      conversation_messages(:outbound_reply).update!(sent_by: @user)
      @whatsapp_message = WhatsappMessage.create!(
        whatsapp_conversation: whatsapp_conversations(:one),
        direction: :outbound,
        status: :sent,
        sent_by: @user,
        body: "Follow up"
      )
      @request = @user.account_deletion_requests.create!(
        status: :pending,
        requested_at: 8.days.ago,
        scheduled_for: 1.day.ago
      )
    end

    test "anonymizes due request user, revokes access, and stores audit fingerprints" do
      original_email = @user.email
      original_name = @user.name
      original_phone = @user.phone_number
      original_cpf = @user.cpf_cnpj

      freeze_time do
        result = Executor.call(request: @request)

        assert result.success?
        assert @request.reload.completed?
        assert_equal Time.current, @request.completed_at
      end

      @user.reload
      assert_not_equal original_email, @user.email
      assert_equal "Deleted User #{@user.id}", @user.name
      assert_nil @user.phone_number
      assert_nil @user.cpf_cnpj
      assert_nil @user.confirmed_at
      assert_not @user.active_for_authentication?
      assert_equal "", @user.role
      assert_nil @user.space_membership
      assert_empty @user.user_permissions
      assert_nil @user.user_preference
      assert_equal 0, Notification.where(user_id: @user.id).count
      assert_nil spaces(:one).reload.owner_id
      assert_nil customers(:one).reload.user_id
      assert_nil conversations(:needs_reply_one).reload.assigned_to_id
      assert_nil conversation_messages(:outbound_reply).reload.sent_by_id
      assert_nil @whatsapp_message.reload.sent_by_id
      assert_equal Security::AuditFingerprint.call(original_email, purpose: :email), @request.email_fingerprint
      assert_equal Security::AuditFingerprint.call(original_name, purpose: :name), @request.name_fingerprint
      assert_equal Security::AuditFingerprint.call(original_phone, purpose: :phone_number), @request.phone_fingerprint
      assert_equal Security::AuditFingerprint.call(original_cpf, purpose: :cpf_cnpj), @request.cpf_cnpj_fingerprint
    end

    test "returns failure when request is not yet due" do
      @request.update!(scheduled_for: 2.days.from_now)

      result = Executor.call(request: @request)

      assert_not result.success?
      assert @request.reload.pending?
      assert_equal users(:manager).email, @user.reload.email
    end
  end
end
