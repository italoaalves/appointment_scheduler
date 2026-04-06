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
    active = settings_section_active?(section)
    if variant == :mobile
      classes = active ? "block shrink-0 px-4 py-2 text-sm font-medium text-electric border-b-2 border-electric -mb-px" : "block shrink-0 px-4 py-2 text-sm text-slate-500 hover:text-slate-700 -mb-px"
    else
      classes = active ? "block rounded-card px-3 py-2 text-sm font-medium bg-electric/10 text-electric border-l-2 border-electric" : "block rounded-card px-3 py-2 text-sm text-slate-600 hover:bg-slate-50 hover:text-slate-800"
    end
    content_tag(:li, class: variant == :mobile ? "shrink-0" : nil) do
      link_to label, path, class: classes, aria: (active ? { current: "page" } : {})
    end
  end

  def settings_section_active?(section)
    case section.to_sym
    when :space
      controller_path == "spaces/space" && action_name == "edit"
    when :availability
      controller_path == "spaces/space/availabilities"
    when :policies
      controller_path == "spaces/space/policies"
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

  def pending_appointments_count
    @pending_appointments_count || 0
  end

  def status_badge_classes(status)
    case status.to_s
    when "pending"     then "bg-amber-100 text-amber-800"
    when "confirmed"   then "bg-emerald-100 text-emerald-800"
    when "no_show", "finished" then "bg-slate-100 text-slate-700"
    when "cancelled"   then "bg-red-100 text-red-800"
    when "rescheduled" then "bg-blue-100 text-blue-800"
    when "trialing"    then "bg-blue-100 text-blue-700"
    when "active"     then "bg-emerald-100 text-emerald-700"
    when "past_due"    then "bg-amber-100 text-amber-700"
    when "canceled", "expired" then "bg-red-100 text-red-700"
    when "received", "overdue" then "bg-amber-100 text-amber-700"
    when "refunded", "failed" then "bg-slate-100 text-slate-600"
    else "bg-slate-100 text-slate-700"
    end
  end
end
