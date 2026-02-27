# frozen_string_literal: true

module UiHelper
  BUTTON_BASE = "inline-flex items-center rounded-md text-xs font-semibold shadow-sm transition-colors " \
                "disabled:opacity-50 disabled:cursor-not-allowed " \
                "focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 " \
                "active:scale-[0.98]"

  def button_classes(variant = :primary)
    base = "#{BUTTON_BASE} px-3 py-2"
    case variant.to_sym
    when :primary   then "#{base} bg-slate-900 text-white hover:bg-slate-800"
    when :secondary then "#{base} border border-slate-300 bg-white text-slate-800 hover:bg-slate-50"
    when :success   then "#{base} bg-emerald-500 text-white hover:bg-emerald-600"
    when :danger    then "#{base} bg-slate-700 text-white hover:bg-slate-900"
    when :cancel    then "#{base} bg-amber-500 text-white hover:bg-amber-600"
    when :destructive then "#{base} bg-red-500 text-white shadow-sm hover:bg-red-600"
    when :muted     then "#{base} bg-slate-100 text-slate-900 hover:bg-slate-200"
    when :neutral   then "#{base} bg-slate-500 text-white hover:bg-slate-600"
    when :table_link then "#{BUTTON_BASE} border border-slate-300 bg-white px-2.5 py-1 text-slate-700 hover:bg-slate-50"
    when :table_success then "#{BUTTON_BASE} bg-emerald-500 px-2.5 py-1 text-white hover:bg-emerald-600"
    when :table_danger then "#{BUTTON_BASE} bg-slate-700 px-2.5 py-1 text-white hover:bg-slate-900"
    when :table_cancel then "#{BUTTON_BASE} bg-amber-500 px-2.5 py-1 text-white hover:bg-amber-600"
    when :table_muted then "#{BUTTON_BASE} bg-slate-500 px-2.5 py-1 text-white hover:bg-slate-600"
    else base
    end
  end

  def form_label_classes
    "block text-sm font-medium text-slate-700"
  end

  def form_label_classes_sm
    "text-xs font-medium text-slate-600"
  end

  def form_input_classes(extra = nil)
    base = "mt-1 block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 shadow-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
    width = extra || "max-w-sm"
    [ base, width ].join(" ")
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
