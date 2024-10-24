class V2::CustomReportBuilder
  include DateRangeHelper
  include CustomReportHelper
  attr_reader :account, :params

  DEFAULT_GROUP_BY = 'day'.freeze
  AGENT_RESULTS_PER_PAGE = 25

  def initialize(account, params)
    @account = account
    @config = params

    @metrics = params[:metrics]
    @filters = params[:filters]
    @group_by = params[:group_by]

    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]&.name

    Rails.logger.info "CustomReportBuilder: timezone_offset - #{params}"

    @time_range = process_custom_time_range(@filters[:time_period])
  end

  # type TimeRange = {
  #   type: 'dynamic';
  #   value: number;
  #   unit: 'day' | 'week' | 'month' | 'year';
  # } | {
  #   type: 'custom'; // for custom dates
  #   start_date: string; // Unix Timestamp format
  #   end_date: string;   // Unix Timestamp format
  # };

  # type MetricKey = 'handled' | 'new_assigned' | 'open' | 'reopened' |
  #                 'carry_forwarded' | 'resolved' | 'waiting_agent_response' |
  #                 'waiting_customer_response' | 'snoozed' | 'avg_first_response_time' |
  #                 'avg_resolution_time' | 'avg_response_time' | 'avg_csat_score'
  #                 'median_first_response_time' | 'median_resolution_time' | 'median_response_time' |
  #                 'median_csat_score';

  # type GroupBy = 'agent' | 'inbox' | 'label';

  # interface config {
  #   metrics: MetricKey[];
  #   filters: {
  #     time_period: TimeRange;
  #     business_hours?: boolean;
  #     inboxes?: number[];
  #     agents?: number[];
  #     labels?: string[];
  #   };
  #   group_by?: GroupBy;
  # }

  # Response
  # {
  #   "time_range": {
  #     "start": string, // Unix Timestamp
  #     "end": string    // Unix Timestamp
  #   },
  #   "data": {
  #     [metric: MetricKey]?: number,
  #     "grouped_data"?: {
  # 		    grouped_by: string,
  #         [groupKey: string]: {
  #           [metric: MetricKey]: number,
  #         }
  #       }
  #   }
  # }

  # Metrics
  # - Conversation States
  #     - Handled
  #     - New Assigned
  #     - Open
  #     - Reopened
  #     - Carry Forwarded
  #     - Resolved
  #     - Waiting Agent Response
  #     - Waiting Customer Response
  #     - Snoozed
  # - Agent Metrics
  #     - (Avg) First Response Time
  #     - (Avg) Resolution Time
  #     - (Avg) Response Time
  #     - (Avg) CSAT Score

  ## Filters:
  # - Time Period
  # - Business Hours - toggle
  # - Inboxes
  # - Agents
  # - Labels

  ## Group By:
  # - Agents
  # - Inboxes
  # - Labels

  # !!!TODO: implement for label groupby

  # TODO: figure out if agent filter needs to be applied with ConversationAssignment

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def fetch_data
    data = {}
    data[:grouped_data] = {}

    @metrics.each do |metric|
      data[metric] = calculate_metric(metric)
    end

    if @group_by.present?
      Rails.logger.info "Group by: #{@group_by.inspect}"
      case @group_by
      when 'agent'
        data[:grouped_data] = {
          grouped_by: 'agent'
        }
        @account.users.each do |user|
          data[:grouped_data][user.id] = {}
          @metrics.each do |metric|
            data[:grouped_data][user.id][metric] = data[metric][user.id]
          end
        end
      when 'inbox'
        data[:grouped_data] = {
          grouped_by: 'inbox'
        }
        @account.inboxes.each do |inbox|
          data[:grouped_data][inbox.id] = {}
          @metrics.each do |metric|
            data[:grouped_data][inbox.id][metric] = data[metric][inbox.id]
          end
        end
      end

      # clean up metric objects
      # @metrics.each do |metric|
      #   data.delete(metric)
      # end
    end

    {
      time_range: @filters[:time_period],
      data: data
    }
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength

  private

  def calculate_metric(metric)
    return send(metric) if metric_valid?(metric)

    Rails.logger.error "CustomReportBuilder: Invalid metric - #{metric}"
  end

  def metric_valid?(metric)
    %w[handled
       new_assigned
       open
       reopened
       carry_forwarded
       resolved
       waiting_agent_response
       waiting_customer_response
       snoozed
       avg_first_response_time
       avg_resolution_time
       avg_response_time
       avg_csat_score
       median_first_response_time
       median_resolution_time
       median_response_time
       median_csat_score].include?(metric)
  end
end
