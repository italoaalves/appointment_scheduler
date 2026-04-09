# frozen_string_literal: true

module Spaces
  module SchedulingLinksHelper
    def scheduling_links_intro_statuses(space, personalized_link:)
      active_links_count = space.scheduling_links.usable.count
      usage_limit = Billing::PlanEnforcer.limit_for(space, :max_scheduling_links)

      [
        settings_intro_status(
          t("space.scheduling_links.index.statuses.active_links"),
          t("space.scheduling_links.index.statuses.active_links_value", count: active_links_count),
          tone: active_links_count.positive? ? :success : :neutral
        ),
        settings_intro_status(
          t("space.scheduling_links.index.statuses.personalized_page"),
          personalized_link_overview_label(space, personalized_link: personalized_link),
          tone: personalized_link.present? ? :accent : (Billing::PlanEnforcer.can?(space, :access_personalized_booking_page) ? :warning : :neutral)
        ),
        settings_intro_status(
          t("space.scheduling_links.index.statuses.usage"),
          usage_limit.present? ? t("space.scheduling_links.index.statuses.usage_value", count: space.scheduling_links.count, limit: usage_limit) : t("space.scheduling_links.index.statuses.usage_unlimited", count: space.scheduling_links.count),
          tone: Billing::PlanEnforcer.can?(space, :create_scheduling_link) ? :neutral : :warning
        )
      ]
    end

    def scheduling_link_type_label(link)
      t("space.scheduling_links.index.link_types.#{link.link_type}")
    end

    def scheduling_link_status(link)
      if link.single_use? && link.used_at.present?
        { label: t("space.scheduling_links.index.statuses.used"), tone: :neutral }
      elsif link.single_use? && link.expires_at.present? && link.expires_at <= Time.current
        { label: t("space.scheduling_links.index.statuses.expired"), tone: :warning }
      elsif link.usable?
        { label: t("space.scheduling_links.index.statuses.active"), tone: :success }
      else
        { label: t("space.scheduling_links.index.statuses.inactive"), tone: :neutral }
      end
    end

    def scheduling_link_metadata(link)
      timezone = link.space&.timezone

      if link.permanent?
        t("space.scheduling_links.index.row.always_active")
      elsif link.used_at.present?
        t("space.scheduling_links.index.row.used_at", value: format_datetime_in_zone(link.used_at, timezone))
      elsif link.expires_at.present? && link.expires_at <= Time.current
        t("space.scheduling_links.index.row.expired_at", value: format_datetime_in_zone(link.expires_at, timezone))
      elsif link.expires_at.present?
        t("space.scheduling_links.index.row.expires_at", value: format_datetime_in_zone(link.expires_at, timezone))
      else
        t("space.scheduling_links.index.statuses.inactive")
      end
    end

    def personalized_link_constraints(space)
      changes_left = [ 3 - space.personalized_slug_changes_count.to_i, 0 ].max
      return t("space.scheduling_links.index.personalized.no_changes_left") if changes_left.zero?

      next_allowed_days = personalized_link_wait_days(space)
      return t("space.scheduling_links.index.personalized.change_wait", count: changes_left, days: next_allowed_days) if next_allowed_days.positive?

      t("space.scheduling_links.index.personalized.change_ready", count: changes_left)
    end

    def personalized_link_overview_label(space, personalized_link:)
      return t("space.scheduling_links.index.statuses.personalized_live") if personalized_link.present?
      return t("space.scheduling_links.index.statuses.personalized_available") if Billing::PlanEnforcer.can?(space, :access_personalized_booking_page)

      t("space.scheduling_links.index.statuses.personalized_unavailable")
    end

    private

    def personalized_link_wait_days(space)
      return 0 if space.personalized_slug_last_changed_at.blank?

      next_change_date = space.personalized_slug_last_changed_at.to_date + 14.days
      [ (next_change_date - Date.current).to_i, 0 ].max
    end
  end
end
