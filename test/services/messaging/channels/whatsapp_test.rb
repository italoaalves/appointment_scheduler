# frozen_string_literal: true

require "test_helper"

module Messaging
  module Channels
    class WhatsappTest < ActiveSupport::TestCase
      class FakeClient
        attr_reader :calls

        def initialize(response: nil)
          @response = response || { "messages" => [ { "id" => "wamid.test123" } ] }
          @calls    = []
        end

        def send_template(**kwargs)
          @calls << [ :send_template, kwargs ]
          @response
        end

        def send_text(**kwargs)
          @calls << [ :send_text, kwargs ]
          @response
        end
      end

      class FailingClient
        def send_template(**); raise ::Whatsapp::Client::ApiError.new("template failed"); end
        def send_text(**);     raise ::Whatsapp::Client::ApiError.new("text failed"); end
      end

      setup do
        @fake_client = FakeClient.new
        @channel     = Whatsapp.new
      end

      def deliver_with_fake(to:, body: "Hello", template: nil, **opts)
        ::Whatsapp::Client.stub(:new, @fake_client) do
          @channel.deliver(to: to, body: body, template: template, **opts)
        end
      end

      # ── Phone validation ───────────────────────────────────────────────────

      test "raises DeliveryError when recipient has no phone" do
        recipient = OpenStruct.new(email: "customer@example.com")

        assert_raises(Messaging::DeliveryError) do
          @channel.deliver(to: recipient, body: "Hello!")
        end
      end

      test "raises DeliveryError when phone is blank" do
        recipient = OpenStruct.new(phone: "")

        assert_raises(Messaging::DeliveryError) do
          @channel.deliver(to: recipient, body: "Hello!")
        end
      end

      # ── Template delivery ──────────────────────────────────────────────────

      test "sends template when template param provided" do
        recipient = OpenStruct.new(phone: "+5511999999999")
        template  = { name: "appointment_booked_v1", language: "pt_BR", components: [] }

        deliver_with_fake(to: recipient, template: template)

        assert_equal 1, @fake_client.calls.size
        call = @fake_client.calls.first
        assert_equal :send_template,          call[0]
        assert_equal "appointment_booked_v1", call[1][:template_name]
        assert_equal "pt_BR",                 call[1][:language]
      end

      test "defaults language to pt_BR when not specified in template" do
        recipient = OpenStruct.new(phone: "+5511999999999")
        template  = { name: "appointment_confirmed_v1" }

        deliver_with_fake(to: recipient, template: template)

        assert_equal "pt_BR", @fake_client.calls.first[1][:language]
      end

      test "passes components to send_template" do
        recipient  = OpenStruct.new(phone: "+5511999999999")
        components = [ { type: "body", parameters: [ { type: "text", text: "João" } ] } ]
        template   = { name: "appointment_booked_v1", components: components }

        deliver_with_fake(to: recipient, template: template)

        assert_equal components, @fake_client.calls.first[1][:components]
      end

      # ── Text delivery ──────────────────────────────────────────────────────

      test "sends text when no template provided" do
        recipient = OpenStruct.new(phone: "+5511999999999")

        deliver_with_fake(to: recipient, body: "Hello there")

        call = @fake_client.calls.first
        assert_equal :send_text,     call[0]
        assert_equal "Hello there",  call[1][:body]
      end

      test "accepts string phone number as recipient" do
        deliver_with_fake(to: "+5511999999999", body: "Hi")

        assert_equal :send_text, @fake_client.calls.first[0]
      end

      # ── Return value ───────────────────────────────────────────────────────

      test "returns success hash with whatsapp_message_id" do
        recipient = OpenStruct.new(phone: "+5511999999999")

        result = deliver_with_fake(to: recipient, body: "Hi")

        assert result[:success]
        assert_equal "wamid.test123", result[:whatsapp_message_id]
      end

      # ── Error handling ─────────────────────────────────────────────────────

      test "raises DeliveryError when ApiError raised on send_text" do
        recipient = OpenStruct.new(phone: "+5511999999999")

        ::Whatsapp::Client.stub(:new, FailingClient.new) do
          error = assert_raises(Messaging::DeliveryError) do
            @channel.deliver(to: recipient, body: "Hi")
          end
          assert_includes error.message, "text failed"
        end
      end

      test "raises DeliveryError when ApiError raised on send_template" do
        recipient = OpenStruct.new(phone: "+5511999999999")
        template  = { name: "appointment_booked_v1" }

        ::Whatsapp::Client.stub(:new, FailingClient.new) do
          error = assert_raises(Messaging::DeliveryError) do
            @channel.deliver(to: recipient, body: "Hi", template: template)
          end
          assert_includes error.message, "template failed"
        end
      end

      # ── Outbound message recording ─────────────────────────────────────────

      test "records outbound WhatsappMessage on successful delivery" do
        space    = spaces(:one)
        customer = customers(:one)
        customer.update!(phone: "+5511999990099")

        # customer.space resolves to spaces(:one), so Current.space not needed here
        ::Whatsapp::Client.stub(:new, @fake_client) do
          assert_difference "WhatsappMessage.count", 1 do
            @channel.deliver(to: customer, body: "Hi", template: { name: "appointment_booked_v1" })
          end
        end

        msg = WhatsappMessage.last
        assert_equal "wamid.test123", msg.wamid
        assert msg.outbound?
        assert_equal "template",      msg.message_type
        assert msg.pending?
      end

      test "uses Client.for_space when space option provided" do
        space    = spaces(:one)
        customer = customers(:one)
        customer.update!(phone: "+5511999990099")

        client_called = false
        fake_for_space = ->(_space) {
          client_called = true
          @fake_client
        }

        ::Whatsapp::Client.stub(:for_space, fake_for_space) do
          @channel.deliver(to: customer, body: "Hi", space: space)
        end

        assert client_called
      end

      test "recording failure does not raise — delivery still succeeds" do
        # No space: opt and recipient has no .space — warning is logged, delivery still succeeds
        recipient = OpenStruct.new(phone: "+5511999999999")

        result = nil
        assert_nothing_raised do
          ::Whatsapp::Client.stub(:new, @fake_client) do
            result = @channel.deliver(to: recipient, body: "Hi")
          end
        end

        assert result[:success]
      end

      test "logs warning when no space context available for recording" do
        recipient = OpenStruct.new(phone: "+5511999999999")
        warned    = false

        Rails.logger.stub(:warn, ->(msg) { warned = true if msg.include?("No space context") }) do
          ::Whatsapp::Client.stub(:new, @fake_client) do
            @channel.deliver(to: recipient, body: "Hi")
          end
        end

        assert warned, "Expected a warning log when no space context is available"
      end

      test "records outbound message when space: opt is passed explicitly" do
        space    = spaces(:one)
        customer = customers(:one)
        customer.update!(phone: "+5511999990098")

        fake_for_space = ->(_space) { @fake_client }

        ::Whatsapp::Client.stub(:for_space, fake_for_space) do
          assert_difference "WhatsappMessage.count", 1 do
            @channel.deliver(
              to:       customer,
              body:     "Hi",
              template: { name: "appointment_booked_v1" },
              space:    space
            )
          end
        end

        msg = WhatsappMessage.last
        assert_equal "wamid.test123", msg.wamid
        assert msg.outbound?
      end
    end
  end
end
