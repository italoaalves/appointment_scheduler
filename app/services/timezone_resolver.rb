# frozen_string_literal: true

class TimezoneResolver
  def self.zone(timezone_string_or_model)
    name = timezone_string_or_model.respond_to?(:timezone) ? timezone_string_or_model.timezone : timezone_string_or_model
    Time.find_zone(name.presence || "UTC")
  end
end
