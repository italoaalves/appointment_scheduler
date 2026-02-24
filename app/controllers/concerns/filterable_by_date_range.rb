# frozen_string_literal: true

module FilterableByDateRange
  def apply_date_range_filter(scope, field: :scheduled_at, timezone:)
    from = parse_date(params[:date_from])
    to = parse_date(params[:date_to])
    tz = TimezoneResolver.zone(timezone)
    scope = scope.where(field => tz.local(from.year, from.month, from.day, 0, 0, 0)..) if from
    scope = scope.where(field => ..tz.local(to.year, to.month, to.day, 0, 0, 0).end_of_day) if to
    scope
  end

  def parse_date(str)
    return nil if str.blank?

    Date.parse(str.to_s)
  rescue ArgumentError
    nil
  end
end
