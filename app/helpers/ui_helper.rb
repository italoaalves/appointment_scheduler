# frozen_string_literal: true

module UiHelper
  def button_classes(variant = :primary, extra_classes = nil)
    classes = case variant.to_sym
    when :primary     then "btn-primary"
    when :secondary   then "btn-secondary"
    when :danger, :destructive then "btn-danger"
    when :success     then "btn-success"
    when :cancel      then "btn-cancel"
    when :muted       then "btn-muted"
    when :neutral     then "btn-neutral"
    when :table_link    then "btn-secondary btn-xs"
    when :table_success then "btn-success btn-xs"
    when :table_danger  then "btn-danger btn-xs"
    when :table_cancel  then "btn-cancel btn-xs"
    when :table_muted   then "btn-neutral btn-xs"
    else
      "btn-primary"
    end
    extra_classes.present? ? "#{classes} #{extra_classes}" : classes
  end

  def form_label_classes
    "form-label"
  end

  def form_label_classes_sm
    "form-label-sm"
  end

  def form_input_classes(extra = nil)
    extra.present? ? "form-input #{extra}" : "form-input"
  end

  def nav_active?(section)
    case section.to_sym
    when :dashboard
      controller_path == "dashboard" && action_name == "index"
    when :appointments
      controller_path.start_with?("spaces/appointments")
    when :booking_links
      controller_path.start_with?("spaces/scheduling_links") ||
        controller_path.start_with?("spaces/personalized_scheduling_links")
    when :customers
      controller_path.start_with?("spaces/customers")
    when :team
      controller_path.start_with?("spaces/users")
    when :settings
      request.path.start_with?("/settings")
    else
      false
    end
  end

  def nav_group_active?(group)
    case group.to_sym
    when :dashboard
      controller_path == "dashboard" && action_name == "index"
    when :appointments
      nav_active?(:dashboard) || nav_active?(:appointments) || nav_active?(:booking_links) || nav_active?(:customers)
    when :communication
      controller_path.start_with?("spaces/inbox")
    when :space
      nav_active?(:team) || nav_active?(:settings) ||
        controller_path.start_with?("spaces/space") ||
        controller_path.start_with?("spaces/billing") ||
        controller_path.start_with?("spaces/credits")
    when :profile
      controller_path.include?("profile") || controller_path.include?("preference")
    else
      false
    end
  end

  def nav_active_classes(section, variant: :desktop)
    active = nav_active?(section)
    case variant.to_sym
    when :desktop
      base = "inline-flex items-center px-2 py-1 rounded-md transition text-sm border-b-2"
      active ? "#{base} text-white border-white" : "#{base} text-slate-200 hover:text-white hover:bg-slate-800 border-transparent"
    when :mobile
      base = "block rounded-md px-3 py-2 text-sm font-medium"
      active ? "#{base} bg-electric/20 text-white" : "#{base} text-slate-100 hover:bg-slate-800"
    else
      active ? "text-white" : "text-slate-200 hover:text-white hover:bg-slate-800"
    end
  end

  def settings_sidebar_link(label, path, section, variant: :desktop)
    build_sidebar_link(
      label,
      path,
      section,
      active: settings_section_active?(section),
      variant: variant,
      description_scope: "settings.sidebar.descriptions"
    )
  end

  def settings_navigation_groups
    [
      {
        title: t("settings.sidebar.business"),
        items: [
          [ t("settings.sidebar.space"), edit_settings_space_path, :space ],
          [ t("settings.sidebar.availability"), edit_settings_space_availability_path, :availability ],
          [ t("settings.sidebar.policies"), edit_settings_space_policies_path, :policies ]
        ]
      },
      {
        title: t("settings.sidebar.communication"),
        items: [
          [ t("settings.sidebar.whatsapp"), settings_whatsapp_path, :whatsapp ]
        ]
      },
      {
        title: t("settings.sidebar.billing_section"),
        items: [
          [ t("settings.sidebar.billing"), settings_billing_path, :billing ],
          [ t("settings.sidebar.credits"), settings_credits_path, :credits ]
        ]
      }
    ]
  end

  def account_sidebar_link(label, path, section, variant: :desktop)
    build_sidebar_link(
      label,
      path,
      section,
      active: account_section_active?(section),
      variant: variant,
      description_scope: "account.sidebar.descriptions"
    )
  end

  def account_navigation_items
    [
      [ t("account.sidebar.profile"), edit_profile_path, :profile ],
      [ t("account.sidebar.preferences"), edit_preferences_path, :preferences ],
      [ t("account.sidebar.security"), profile_security_path, :security ]
    ]
  end

  def settings_section_active?(section)
    case section.to_sym
    when :space
      controller_path == "spaces/space" && action_name == "edit"
    when :availability
      controller_path == "spaces/space/availabilities"
    when :policies
      controller_path == "spaces/space/policies"
    when :whatsapp
      controller_path == "spaces/whatsapp_settings"
    when :billing
      controller_path == "spaces/billing"
    when :credits
      controller_path == "spaces/credits"
    when :inbox
      controller_path == "spaces/inbox"
    else
      false
    end
  end

  def account_section_active?(section)
    case section.to_sym
    when :profile
      controller_path == "profiles" && action_name == "edit"
    when :preferences
      controller_path == "preferences"
    when :security
      controller_path == "profiles/security" || controller_path.start_with?("profiles/security/")
    else
      false
    end
  end

  def pending_appointments_count
    @pending_appointments_count || 0
  end

  def status_badge_classes(status)
    case status.to_s
    when "pending" then "badge-amber"
    when "confirmed" then "badge-emerald"
    when "no_show", "finished" then "badge-slate"
    when "cancelled" then "badge-red"
    when "rescheduled", "trialing" then "badge-blue"
    when "active" then "badge-emerald"
    when "past_due", "received", "overdue" then "badge-amber"
    when "canceled", "expired" then "badge-red"
    when "refunded", "failed" then "badge-slate"
    else "badge-slate"
    end
  end

  def settings_availability_summary(space)
    return t("settings.shared.not_configured") if space.blank?

    space.business_hours.presence || t("settings.shared.not_configured")
  end

  def settings_policy_summary(space)
    return t("settings.shared.not_configured") if space.blank?

    rules = []
    rules << t("settings.shared.policy_summary.cancellation", value: space.cancellation_min_hours_before) if space.cancellation_min_hours_before.present?
    rules << t("settings.shared.policy_summary.reschedule", value: space.reschedule_min_hours_before) if space.reschedule_min_hours_before.present?
    rules << t("settings.shared.policy_summary.max_days", value: space.request_max_days_ahead) if space.request_max_days_ahead.present?
    rules << t("settings.shared.policy_summary.min_notice", value: space.request_min_hours_ahead) if space.request_min_hours_ahead.present?

    rules.first(2).join(" · ").presence || t("settings.shared.policy_summary.flexible")
  end

  def settings_whatsapp_summary(space)
    phone_number = space&.whatsapp_phone_number
    return t("settings.shared.whatsapp.disconnected") unless phone_number&.active?

    phone_number.display_number.presence || t("settings.shared.whatsapp.connected")
  end

  def settings_intro_status(label, value, tone: :neutral)
    {
      label: label,
      value: value,
      tone: tone
    }
  end

  def available_omniauth_providers
    User.omniauth_providers.select { |provider| Devise.omniauth_configs.key?(provider) }
  end

  def omniauth_authorize_path_for(resource_or_scope, provider)
    scope = Devise::Mapping.find_scope!(resource_or_scope)
    public_send("#{scope}_#{provider}_omniauth_authorize_path")
  end

  def omniauth_provider_label(provider)
    case provider.to_s
    when "apple" then "Apple"
    else "Google"
    end
  end

  def linked_identity_summary(user)
    labels = user.user_identities.order(:provider).map { |identity| omniauth_provider_label(identity.provider) }.uniq
    return t("profiles.security.status.none_linked") if labels.blank?

    labels.join(" · ")
  end

  def account_security_summary(user)
    user.mfa_enabled? ? t("profiles.edit.security_enabled") : t("profiles.edit.security_review")
  end

  def profile_locale_label(user_preference)
    locale = user_preference&.locale.presence || I18n.locale.to_s
    label_key = locale == "pt-BR" ? :pt : locale
    t("layout.nav.language.#{label_key}")
  end

  private

  def build_sidebar_link(label, path, section, active:, variant:, description_scope:)
    content_tag(:li, class: variant == :mobile ? "shrink-0" : nil) do
      link_to path, class: sidebar_link_classes(active, variant), aria: (active ? { current: "page" } : {}) do
        content_tag(:div, class: "flex items-center justify-between gap-3") do
          concat(content_tag(:div, class: "min-w-0") do
            concat content_tag(:p, label, class: "text-sm font-semibold leading-5")
            if variant != :mobile
              description = t("#{description_scope}.#{section}")
              concat content_tag(:p, description, class: "mt-1 text-xs leading-5 text-slate-500")
            end
          end)

          next if variant == :mobile

          concat content_tag(:span, "›", class: "text-base leading-none #{active ? 'text-electric' : 'text-slate-300'}", aria: { hidden: true })
        end
      end
    end
  end

  def sidebar_link_classes(active, variant)
    if variant == :mobile
      active ? "block shrink-0 rounded-2xl border border-electric/30 bg-electric/10 px-4 py-2.5 text-sm font-medium text-electric shadow-sm shadow-electric/10" : "block shrink-0 rounded-2xl border border-white/50 bg-white/65 px-4 py-2.5 text-sm text-slate-600 transition hover:border-electric/15 hover:bg-white/80 hover:text-deep"
    else
      active ? "block rounded-card border border-electric/20 bg-electric/10 px-4 py-3 text-electric shadow-sm shadow-electric/10 ring-1 ring-electric/10" : "block rounded-card border border-transparent px-4 py-3 text-slate-600 transition hover:border-white/60 hover:bg-white/70 hover:text-deep"
    end
  end
end
