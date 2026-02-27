# frozen_string_literal: true

module BillingHelper
  PLAN_COMPARISON_ROWS = [
    { key: :max_team_members,             label: "Membros da equipe",        format: :limit   },
    { key: :max_customers,                label: "Clientes",                 format: :limit   },
    { key: :max_scheduling_links,         label: "Links de agendamento",     format: :limit   },
    { key: :whatsapp_monthly_quota,       label: "Mensagens WhatsApp",       format: :quota   },
    { key: "personalized_booking_page",   label: "Página personalizada",     format: :feature },
    { key: "custom_appointment_policies", label: "Políticas personalizadas", format: :feature },
    { key: "priority_support",            label: "Suporte prioritário",      format: :feature }
  ].freeze

  def billing_event_label(event_type)
    return "" if event_type.blank?

    key = "billing.event_types.#{event_type.tr('.', '_')}"
    I18n.t(key, default: event_type.humanize)
  end

  def format_plan_limit(value)
    value.nil? ? "Ilimitado" : value.to_s
  end

  def format_whatsapp_quota(value)
    return "Ilimitado" if value.nil?
    return "Compre pacotes" if value == 0

    "#{value}/mês"
  end

  def format_plan_feature(plan, key)
    plan.feature?(key.to_s) ? "✓" : "—"
  end
end
