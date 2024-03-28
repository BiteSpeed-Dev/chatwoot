module GroupByReportingHelper
  DEFAULT_GROUP_BY = 'day'.freeze
  PERMITTED_GROUP_BY_FILTERS = %w[day week month year hour].freeze

  def get_grouped_values(relation)
    @grouped_values = relation.group_by_period(
      params[:group_by] || DEFAULT_GROUP_BY,
      :created_at,
      default_value: 0,
      range: range,
      permit: PERMITTED_GROUP_BY_FILTERS,
      time_zone: @timezone
    )
  end
end
