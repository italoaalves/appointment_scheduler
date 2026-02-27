# frozen_string_literal: true

module BillingHelper
  def billing_event_label(event_type)
    return "" if event_type.blank?

    key = "billing.event_types.#{event_type.tr('.', '_')}"
    I18n.t(key, default: event_type.humanize)
  end
end
