# frozen_string_literal: true

class DateRangeFilterService
  def self.call(scope, date_from:, date_to:, field: :scheduled_at, timezone:)
    new(scope: scope, date_from: date_from, date_to: date_to, field: field, timezone: timezone).call
  end

  def initialize(scope:, date_from:, date_to:, field: :scheduled_at, timezone:)
    @scope = scope
    @date_from = parse_date(date_from)
    @date_to = parse_date(date_to)
    @field = field
    @timezone = timezone
  end

  def call
    tz = TimezoneResolver.zone(@timezone)
    scope = @scope
    scope = scope.where(@field => tz.local(@date_from.year, @date_from.month, @date_from.day, 0, 0, 0)..) if @date_from
    scope = scope.where(@field => ..tz.local(@date_to.year, @date_to.month, @date_to.day, 0, 0, 0).end_of_day) if @date_to
    scope
  end

  private

  def parse_date(str)
    return nil if str.blank?

    Date.parse(str.to_s)
  rescue ArgumentError
    nil
  end
end
