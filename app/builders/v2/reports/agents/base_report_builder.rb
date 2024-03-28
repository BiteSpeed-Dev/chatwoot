class V2::Reports::Agents::BaseReportBuilder
  include ActiveModel::Validations
  include DateRangeHelper

  attr_reader :account, :params

  DEFAULT_GROUP_BY = 'day'.freeze
  PERMITTED_GROUP_BY_FILTERS = %w[day week month year hour].freeze

  validates :business_hours, inclusion: { in: [true, false] }
  validates :group_by, presence: true, inclusion: { in: PERMITTED_GROUP_BY_FILTERS }

  def initialize(account:, params:)
    @account = account
    @params = params
    validate!

    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]&.name
  end

  def perform
    ## implement in child class
  end

  private

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

  ## used during validations
  def method_missing(method_name, *arguments, &)
    if @params.key?(method_name)
      @params[method_name]
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @params.key?(method_name) || super
  end
end
