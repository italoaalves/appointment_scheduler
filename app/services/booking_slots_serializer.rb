# frozen_string_literal: true

class BookingSlotsSerializer
  LABEL_FORMAT = "%a %b %d, %Y at %l:%M %p"

  def self.to_json(slots)
    slots.map { |slot| { value: slot.iso8601, label: slot.strftime(LABEL_FORMAT) } }
  end
end
