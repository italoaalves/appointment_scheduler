# frozen_string_literal: true

require "uri"

module MailerConfiguration
  module_function

  def default_url_options(force_ssl: false, credentials: Rails.application.credentials)
    uri = base_uri(credentials)
    host = credentials.dig(:mailer, :host).presence || uri&.host || "example.com"
    protocol = credentials.dig(:mailer, :protocol).presence || uri&.scheme || (force_ssl ? "https" : "http")

    {
      host: host,
      protocol: protocol
    }.tap do |options|
      port = credentials.dig(:mailer, :port).presence || non_default_port(uri)
      options[:port] = port if port.present?
    end
  end

  def sender(credentials: Rails.application.credentials)
    credentials.dig(:mailer, :from).presence || "noreply@#{domain(credentials)}"
  end

  def domain(credentials = Rails.application.credentials)
    credentials.dig(:mailer, :domain).presence ||
      credentials.dig(:mailer, :host).presence ||
      base_uri(credentials)&.host ||
      "example.com"
  end

  def base_uri(credentials)
    raw = credentials.dig(:app, :base_url).presence
    return if raw.blank?

    URI.parse(raw)
  rescue URI::InvalidURIError
    nil
  end

  def non_default_port(uri)
    return unless uri&.port
    return if uri.port == uri.default_port

    uri.port
  end
end
