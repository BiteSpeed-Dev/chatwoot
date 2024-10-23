class Api::V2::Accounts::CustomReportsController < Api::V1::Accounts::BaseController
  def index
    builder = V2::CustomReportBuilder.new(Current.account, params)
    result = builder.fetch_data
    render json: result
  end

  def agents_overview
    render json: process_grouped_data(build_report(agents_overview_params))
  end

  def agent_wise_conversation_states
    render json: process_grouped_data(build_report(agent_wise_conversation_states_params))
  end

  def download_agents_overview
    enqueue_report_generation(download_agents_overview_params)
  end

  def download_agent_wise_conversation_states
    enqueue_report_generation(download_agent_wise_conversation_states_params)
  end

  private

  def build_report(input)
    V2::CustomReportBuilder.new(Current.account, input).fetch_data
  end

  def process_grouped_data(result)
    result[:data][:grouped_data].filter_map do |group, data|
      data.merge(id: group) unless data.is_a?(String)
    end
  end

  def enqueue_report_generation(input)
    # TODO: Implement job for report generation
    render json: { message: 'Report generation started', email: params[:email], input: input }
  end

  def base_filters
    {
      time_period: {
        type: 'custom',
        start_date: params[:since],
        end_date: params[:until]
      },
      business_hours: params[:business_hours],
      inboxes: params[:inboxes],
      agents: params[:agents],
      labels: params[:labels]
    }
  end

  def agents_overview_params
    {
      metrics: %w[resolved avg_first_response_time avg_resolution_time avg_response_time avg_csat_score
                  median_first_response_time median_resolution_time median_response_time median_csat_score],
      group_by: 'agent',
      filters: base_filters
    }
  end

  def agent_wise_conversation_states_params
    {
      metrics: %w[handled new_assigned open reopened carry_forwarded resolved snoozed],
      group_by: 'agent',
      filters: base_filters
    }
  end

  def download_agents_overview_params
    {
      metrics: ['resolved'] + send(:"#{params[:metric_type]&.downcase}_metrics"),
      group_by: 'agent',
      filters: base_filters
    }
  end

  def download_agent_wise_conversation_states_params
    agent_wise_conversation_states_params
  end

  def average_metrics
    %w[avg_first_response_time avg_resolution_time avg_response_time avg_csat_score]
  end

  def median_metrics
    %w[median_first_response_time median_resolution_time median_response_time median_csat_score]
  end
end
