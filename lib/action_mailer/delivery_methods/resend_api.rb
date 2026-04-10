# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "uri"

module ActionMailer
  module DeliveryMethods
    class ResendApi
      class DeliveryError < StandardError; end

      DEFAULT_API_URL = "https://api.resend.com/emails"
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 15

      attr_accessor :settings

      def initialize(settings = {})
        @settings = {
          api_key: nil,
          api_url: DEFAULT_API_URL,
          open_timeout: DEFAULT_OPEN_TIMEOUT,
          read_timeout: DEFAULT_READ_TIMEOUT,
          user_agent: "appointment_scheduler-action_mailer"
        }.merge((settings || {}).symbolize_keys)
      end

      def deliver!(mail)
        raise DeliveryError, "Resend API key is missing" if settings[:api_key].blank?

        uri = URI.parse(settings[:api_url])
        response = http_client(uri).request(build_request(uri, mail))

        raise_delivery_error(response) unless success_response?(response)

        response
      rescue DeliveryError
        raise
      rescue StandardError => error
        raise DeliveryError, "Resend delivery failed: #{error.message}"
      end

      private

      def build_request(uri, mail)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{settings[:api_key]}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request["User-Agent"] = settings[:user_agent]
        request.body = JSON.generate(payload_for(mail))
        request
      end

      def payload_for(mail)
        {
          from: formatted_address(mail, :from).first,
          to: formatted_address(mail, :to),
          cc: formatted_address(mail, :cc).presence,
          bcc: formatted_address(mail, :bcc).presence,
          reply_to: formatted_address(mail, :reply_to).presence,
          subject: mail.subject.to_s,
          html: html_body(mail),
          text: text_body(mail),
          headers: custom_headers(mail).presence,
          attachments: attachments_payload(mail).presence
        }.compact
      end

      def formatted_address(mail, field)
        header = mail[field]
        return header.formatted if header.respond_to?(:formatted)

        Array(mail.public_send(field)).compact_blank
      end

      def html_body(mail)
        return mail.html_part.decoded if mail.html_part
        return mail.body.decoded if mail.mime_type == "text/html"

        nil
      end

      def text_body(mail)
        return mail.text_part.decoded if mail.text_part
        return mail.body.decoded if mail.mime_type == "text/plain"

        nil
      end

      def custom_headers(mail)
        {}.tap do |headers|
          headers["In-Reply-To"] = mail[:"In-Reply-To"]&.value if mail[:"In-Reply-To"]&.value.present?
          headers["References"] = mail[:References]&.value if mail[:References]&.value.present?
        end
      end

      def attachments_payload(mail)
        mail.attachments.map do |attachment|
          {
            filename: attachment.filename,
            content: Base64.strict_encode64(attachment.body.decoded)
          }
        end
      end

      def http_client(uri)
        return settings[:http] if settings[:http]

        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = settings[:open_timeout]
          http.read_timeout = settings[:read_timeout]
        end
      end

      def success_response?(response)
        response.code.to_i.between?(200, 299)
      end

      def raise_delivery_error(response)
        message = parse_error_message(response.body)
        raise DeliveryError, "Resend delivery failed (HTTP #{response.code}): #{message}"
      end

      def parse_error_message(body)
        payload = JSON.parse(body)
        payload["message"].presence || payload["name"].presence || body
      rescue JSON::ParserError, TypeError
        body.presence || "unknown error"
      end
    end
  end
end
