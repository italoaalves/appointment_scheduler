# frozen_string_literal: true

class Rack::Attack
  # Throttle booking creation to prevent spam
  throttle("booking/create", limit: 10, period: 1.minute) do |req|
    if req.path.start_with?("/book/") && req.post?
      req.ip
    end
  end

  # Throttle slot enumeration
  throttle("booking/slots", limit: 30, period: 1.minute) do |req|
    if req.path.match?(%r{/book/.+/slots}) && req.get?
      req.ip
    end
  end

  # Throttle login attempts
  throttle("logins/ip", limit: 20, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  throttle("logins/email", limit: 10, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email")&.downcase&.strip
    end
  end

  self.throttled_responder = ->(req) {
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Rate limit exceeded. Please try again later.\n" ]
    ]
  }
end
