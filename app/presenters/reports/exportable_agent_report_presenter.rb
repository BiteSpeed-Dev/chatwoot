class Reports::ExportableAgentReportPresenter < SimpleDelegator
  attr_accessor :agent_reports, :params

  def initialize(agent_reports, report_params)
    super(agent_reports)
    @agent_reports = agent_reports
    @params = report_params
  end

  def csv_rows
    rows = []
    presented_data = present  # assuming present method gives the structured data

    presented_data.each do |metric, date_data|
      rows << report_section_title(metric)
      # Start with a header row for each metric
      header_row = ["Date"]
      # Assuming we have a method to fetch agent names, and all dates have the same agent names
      agents = date_data.values.first.keys
      header_row += agents
      rows << header_row

      # Add data rows for each date
      date_data.each do |date, agent_data|
        row = [date]
        agents.each do |agent_name|
          row << metric_value(metric, agent_data[agent_name])
        end
        rows << row
      end

      # Add a blank row between metrics for readability
      rows << []
    end

    rows
  end

  private

  def pivot_data(data)
    # Pivot the data to have dates as rows and agent names as columns
    pivoted = {}

    data.each do |agent_data|
      agent_data[:entries].each do |date, value|
        pivoted[date] ||= {}
        pivoted[date][agent_data[:name]] = value
      end
    end

    pivoted
  end

  def present
    # Initialize a hash to store the pivoted data
    pivoted_data = {}

    agent_reports.each do |metric, data|
      pivoted_data[metric] = pivot_data(data)
    end

    pivoted_data
  end

  def report_section_title(metric)
    if %w[avg_first_response_time avg_resolution_time reply_time].include?(metric.to_s)
      ["#{metric.to_s.titleize} (in minutes)"]
    else
      [metric.to_s.titleize]
    end
  end

  def metric_value(metric, data_point)
    if %w[avg_first_response_time avg_resolution_time reply_time].include?(metric.to_s)
      time_to_minutes(data_point)
    else
      data_point
    end
  end

  def time_to_minutes(time_in_seconds)
    (time_in_seconds / 60).to_i
  end
end
