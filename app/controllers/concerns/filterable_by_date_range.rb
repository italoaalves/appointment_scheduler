# frozen_string_literal: true

module FilterableByDateRange
  def apply_date_range_filter(scope, field: :scheduled_at, timezone:)
    DateRangeFilterService.call(
      scope,
      date_from: params[:date_from],
      date_to: params[:date_to],
      field: field,
      timezone: timezone
    )
  end
end
