# frozen_string_literal: true

require "zip"

module DataExports
  class PackageBuilder
    Result = Struct.new(:data, :filename, :content_type, keyword_init: true)

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
      @space = user.space
    end

    def call
      buffer = Zip::OutputStream.write_buffer do |zip|
        account_entries.each do |name, csv|
          zip.put_next_entry(name)
          zip.write(csv)
        end

        workspace_entries.each do |name, csv|
          zip.put_next_entry(name)
          zip.write(csv)
        end
      end

      Result.new(
        data: buffer.string,
        filename: "lgpd-export-#{@user.id}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}.zip",
        content_type: "application/zip"
      )
    end

    private

    def account_entries
      {
        "user.csv" => build_csv(user_headers, [ user_row ]),
        "user_preferences.csv" => build_csv(user_preference_headers, user_preference_rows),
        "user_permissions.csv" => build_csv(user_permission_headers, user_permission_rows),
        "notifications.csv" => build_csv(notification_headers, notification_rows),
        "messages.csv" => build_csv(message_headers, message_rows)
      }
    end

    def workspace_entries
      return {} unless include_workspace_data?

      {
        "space.csv" => build_csv(space_headers, [ space_row ]),
        "customers.csv" => build_csv(customer_headers, customer_rows),
        "appointments.csv" => build_csv(appointment_headers, appointment_rows),
        "subscription.csv" => build_csv(subscription_headers, subscription_rows),
        "payments.csv" => build_csv(payment_headers, payment_rows),
        "billing_events.csv" => build_csv(billing_event_headers, billing_event_rows),
        "conversations.csv" => build_csv(conversation_headers, conversation_rows),
        "conversation_messages.csv" => build_csv(conversation_message_headers, conversation_message_rows),
        "whatsapp_conversations.csv" => build_csv(whatsapp_conversation_headers, whatsapp_conversation_rows),
        "whatsapp_messages.csv" => build_csv(whatsapp_message_headers, whatsapp_message_rows)
      }
    end

    def include_workspace_data?
      @space.present? && @user.can?(:manage_space, space: @space)
    end

    def user_row
      {
        id: @user.id,
        email: @user.email,
        name: @user.name,
        phone_number: @user.phone_number,
        cpf_cnpj: @user.cpf_cnpj,
        role: @user.role,
        system_role: @user.system_role,
        terms_of_service_accepted_at: @user.terms_of_service_accepted_at,
        terms_of_service_version: @user.terms_of_service_version,
        privacy_policy_accepted_at: @user.privacy_policy_accepted_at,
        privacy_policy_version: @user.privacy_policy_version,
        created_at: @user.created_at,
        updated_at: @user.updated_at
      }
    end

    def user_headers
      user_row.keys
    end

    def user_preference_rows
      preference = @user.user_preference
      return [] unless preference

      [ {
        id: preference.id,
        locale: preference.locale,
        dismissed_welcome_card: preference.dismissed_welcome_card,
        created_at: preference.created_at,
        updated_at: preference.updated_at
      } ]
    end

    def user_preference_headers
      %i[id locale dismissed_welcome_card created_at updated_at]
    end

    def user_permission_rows
      @user.user_permissions.order(:permission).map do |permission|
        {
          id: permission.id,
          permission: permission.permission,
          created_at: permission.created_at,
          updated_at: permission.updated_at
        }
      end
    end

    def user_permission_headers
      %i[id permission created_at updated_at]
    end

    def notification_rows
      @user.notifications.ordered.map do |notification|
        {
          id: notification.id,
          title: notification.title,
          body: notification.body,
          event_type: notification.event_type,
          read: notification.read,
          notifiable_type: notification.notifiable_type,
          notifiable_id: notification.notifiable_id,
          created_at: notification.created_at,
          updated_at: notification.updated_at
        }
      end
    end

    def notification_headers
      %i[id title body event_type read notifiable_type notifiable_id created_at updated_at]
    end

    def message_rows
      Message.where(sender_id: @user.id).or(Message.where(recipient_id: @user.id)).order(:created_at).map do |message|
        {
          id: message.id,
          sender_id: message.sender_id,
          recipient_id: message.recipient_id,
          channel: message.channel,
          status: message.status,
          content: message.content,
          messageable_type: message.messageable_type,
          messageable_id: message.messageable_id,
          created_at: message.created_at,
          updated_at: message.updated_at
        }
      end
    end

    def message_headers
      %i[id sender_id recipient_id channel status content messageable_type messageable_id created_at updated_at]
    end

    def space_row
      {
        id: @space.id,
        name: @space.name,
        business_type: @space.business_type,
        email: @space.email,
        phone: @space.phone,
        address: @space.address,
        timezone: @space.timezone,
        owner_id: @space.owner_id,
        created_at: @space.created_at,
        updated_at: @space.updated_at
      }
    end

    def space_headers
      space_row.keys
    end

    def customer_rows
      @space.customers.order(:id).map do |customer|
        {
          id: customer.id,
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          address: customer.address,
          whatsapp_opted_in_at: customer.whatsapp_opted_in_at,
          whatsapp_opted_out_at: customer.whatsapp_opted_out_at,
          created_at: customer.created_at,
          updated_at: customer.updated_at
        }
      end
    end

    def customer_headers
      %i[id name email phone address whatsapp_opted_in_at whatsapp_opted_out_at created_at updated_at]
    end

    def appointment_rows
      Appointment.unscoped.where(space_id: @space.id).order(:id).map do |appointment|
        {
          id: appointment.id,
          customer_id: appointment.customer_id,
          status: appointment.status,
          scheduled_at: appointment.scheduled_at,
          requested_at: appointment.requested_at,
          duration_minutes: appointment.duration_minutes,
          discarded_at: appointment.discarded_at,
          created_at: appointment.created_at,
          updated_at: appointment.updated_at
        }
      end
    end

    def appointment_headers
      %i[id customer_id status scheduled_at requested_at duration_minutes discarded_at created_at updated_at]
    end

    def subscription_rows
      subscription = @space.subscription
      return [] unless subscription

      [ {
        id: subscription.id,
        billing_plan_id: subscription.billing_plan_id,
        pending_billing_plan_id: subscription.pending_billing_plan_id,
        status: subscription.status,
        payment_method: subscription.payment_method,
        trial_ends_at: subscription.trial_ends_at,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        canceled_at: subscription.canceled_at,
        created_at: subscription.created_at,
        updated_at: subscription.updated_at
      } ]
    end

    def subscription_headers
      %i[id billing_plan_id pending_billing_plan_id status payment_method trial_ends_at current_period_start current_period_end canceled_at created_at updated_at]
    end

    def payment_rows
      @space.payments.order(:id).map do |payment|
        {
          id: payment.id,
          subscription_id: payment.subscription_id,
          asaas_payment_id: payment.asaas_payment_id,
          amount_cents: payment.amount_cents,
          payment_method: payment.payment_method,
          status: payment.status,
          due_date: payment.due_date,
          paid_at: payment.paid_at,
          created_at: payment.created_at,
          updated_at: payment.updated_at
        }
      end
    end

    def payment_headers
      %i[id subscription_id asaas_payment_id amount_cents payment_method status due_date paid_at created_at updated_at]
    end

    def billing_event_rows
      @space.billing_events.order(:id).map do |event|
        {
          id: event.id,
          subscription_id: event.subscription_id,
          actor_id: event.actor_id,
          event_type: event.event_type,
          metadata: event.metadata,
          created_at: event.created_at
        }
      end
    end

    def billing_event_headers
      %i[id subscription_id actor_id event_type metadata created_at]
    end

    def conversation_rows
      @space.conversations.order(:id).map do |conversation|
        {
          id: conversation.id,
          customer_id: conversation.customer_id,
          assigned_to_id: conversation.assigned_to_id,
          channel: conversation.channel,
          status: conversation.status,
          priority: conversation.priority,
          external_id: conversation.external_id,
          contact_identifier: conversation.contact_identifier,
          contact_name: conversation.contact_name,
          last_message_body: conversation.last_message_body,
          last_message_at: conversation.last_message_at,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        }
      end
    end

    def conversation_headers
      %i[id customer_id assigned_to_id channel status priority external_id contact_identifier contact_name last_message_body last_message_at created_at updated_at]
    end

    def conversation_message_rows
      ConversationMessage.joins(:conversation).where(conversations: { space_id: @space.id }).order(:id).map do |message|
        {
          id: message.id,
          conversation_id: message.conversation_id,
          sent_by_id: message.sent_by_id,
          direction: message.direction,
          status: message.status,
          message_type: message.message_type,
          body: message.body,
          external_message_id: message.external_message_id,
          credit_cost: message.credit_cost,
          created_at: message.created_at,
          updated_at: message.updated_at
        }
      end
    end

    def conversation_message_headers
      %i[id conversation_id sent_by_id direction status message_type body external_message_id credit_cost created_at updated_at]
    end

    def whatsapp_conversation_rows
      @space.whatsapp_conversations.order(:id).map do |conversation|
        {
          id: conversation.id,
          customer_id: conversation.customer_id,
          wa_id: conversation.wa_id,
          customer_phone: conversation.customer_phone,
          customer_name: conversation.customer_name,
          unread: conversation.unread,
          last_message_at: conversation.last_message_at,
          session_expires_at: conversation.session_expires_at,
          created_at: conversation.created_at,
          updated_at: conversation.updated_at
        }
      end
    end

    def whatsapp_conversation_headers
      %i[id customer_id wa_id customer_phone customer_name unread last_message_at session_expires_at created_at updated_at]
    end

    def whatsapp_message_rows
      WhatsappMessage.joins(:whatsapp_conversation).where(whatsapp_conversations: { space_id: @space.id }).order(:id).map do |message|
        {
          id: message.id,
          whatsapp_conversation_id: message.whatsapp_conversation_id,
          sent_by_id: message.sent_by_id,
          direction: message.direction,
          status: message.status,
          message_type: message.message_type,
          body: message.body,
          wamid: message.wamid,
          created_at: message.created_at,
          updated_at: message.updated_at
        }
      end
    end

    def whatsapp_message_headers
      %i[id whatsapp_conversation_id sent_by_id direction status message_type body wamid created_at updated_at]
    end

    def build_csv(headers, rows)
      lines = [ serialize_row(headers) ]
      rows.each do |row|
        lines << serialize_row(headers.map { |header| row[header] })
      end
      lines.join("\n") + "\n"
    end

    def serialize_row(values)
      Array(values).map { |value| escape_csv(normalize_value(value)) }.join(",")
    end

    def normalize_value(value)
      case value
      when nil then ""
      when Time, Date, DateTime then value.iso8601
      when ActiveSupport::TimeWithZone then value.iso8601
      when Hash, Array then value.to_json
      else value.to_s
      end
    end

    def escape_csv(value)
      escaped = value.gsub('"', '""')
      return escaped unless value.match?(/[",\n\r]/)

      %("#{escaped}")
    end
  end
end
