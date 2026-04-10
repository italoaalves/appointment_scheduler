# frozen_string_literal: true

require "test_helper"
require "base64"
require "json"

module ActionMailer
  module DeliveryMethods
    class ResendApiTest < ActiveSupport::TestCase
      Response = Struct.new(:code, :body)

      class FakeHttp
        attr_reader :last_request
        attr_accessor :use_ssl, :open_timeout, :read_timeout

        def initialize(response)
          @response = response
        end

        def request(request)
          @last_request = request
          @response
        end
      end

      test "sends multipart emails with attachments to Resend" do
        http = FakeHttp.new(Response.new("200", { id: "email_123" }.to_json))
        delivery_method = ResendApi.new(api_key: "re_test", http: http, user_agent: "test-suite")

        mail = Mail.new do
          from "Acme <noreply@example.com>"
          to "person@example.com"
          cc "copy@example.com"
          bcc "hidden@example.com"
          reply_to "support@example.com"
          subject "Hello"
          text_part do
            body "Plain body"
          end
          html_part do
            content_type "text/html; charset=UTF-8"
            body "<p>HTML body</p>"
          end
        end
        mail.attachments["invite.ics"] = {
          mime_type: "text/calendar",
          content: "BEGIN:VCALENDAR\nEND:VCALENDAR"
        }

        response = delivery_method.deliver!(mail)
        payload = JSON.parse(http.last_request.body)

        assert_equal "200", response.code
        assert_equal "Bearer re_test", http.last_request["Authorization"]
        assert_equal "application/json", http.last_request["Content-Type"]
        assert_equal "test-suite", http.last_request["User-Agent"]
        assert_equal "Acme <noreply@example.com>", payload["from"]
        assert_equal [ "person@example.com" ], payload["to"]
        assert_equal [ "copy@example.com" ], payload["cc"]
        assert_equal [ "hidden@example.com" ], payload["bcc"]
        assert_equal [ "support@example.com" ], payload["reply_to"]
        assert_equal "Hello", payload["subject"]
        assert_equal "<p>HTML body</p>", payload["html"]
        assert_equal "Plain body", payload["text"]
        assert_equal 1, payload["attachments"].size
        assert_equal "invite.ics", payload["attachments"].first["filename"]
        assert_equal Base64.strict_encode64("BEGIN:VCALENDAR\nEND:VCALENDAR"), payload["attachments"].first["content"]
      end

      test "passes threading headers through to Resend" do
        http = FakeHttp.new(Response.new("200", { id: "email_123" }.to_json))
        delivery_method = ResendApi.new(api_key: "re_test", http: http)

        mail = Mail.new do
          from "noreply@example.com"
          to "person@example.com"
          subject "Re: Hello"
          body "Body"
          header["In-Reply-To"] = "<message-id@example.com>"
          header["References"] = "<message-id@example.com> <another@example.com>"
        end

        delivery_method.deliver!(mail)
        payload = JSON.parse(http.last_request.body)

        assert_equal(
          {
            "In-Reply-To" => "<message-id@example.com>",
            "References" => "<message-id@example.com> <another@example.com>"
          },
          payload["headers"]
        )
      end

      test "raises a delivery error when the api key is missing" do
        error = assert_raises(ResendApi::DeliveryError) do
          ResendApi.new.deliver!(Mail.new)
        end

        assert_includes error.message, "API key is missing"
      end

      test "raises a delivery error when resend rejects the email" do
        http = FakeHttp.new(Response.new("422", { message: "Invalid `from` field." }.to_json))
        delivery_method = ResendApi.new(api_key: "re_test", http: http)

        mail = Mail.new do
          from "noreply@example.com"
          to "person@example.com"
          subject "Hello"
          body "Body"
        end

        error = assert_raises(ResendApi::DeliveryError) do
          delivery_method.deliver!(mail)
        end

        assert_includes error.message, "HTTP 422"
        assert_includes error.message, "Invalid `from` field."
      end
    end
  end
end
