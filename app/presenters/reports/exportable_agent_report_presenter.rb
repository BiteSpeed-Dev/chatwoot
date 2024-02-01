class Reports::ExportableAgentReportPresenter < SimpleDelegator
  attr_accessor :agent_reports, :params

  def initialize(agent_reports, report_params)
    super(agent_reports)
    @agent_reports = agent_reports
    @params = report_params
  end

  def csv_rows
    rows = []

    V2::ReportBuilder::REPORT_METRICS.map(&:to_sym).each do |metric|
      detailed_report_for_metric(metric, rows)
    end

    rows
  end

  private

  def report_section_title(metric)
    if V2::ReportBuilder::TIME_METRICS.include?(metric.to_s)
      ["#{metric.to_s.titleize} (in minutes)"]
    else
      [metric.to_s.titleize]
    end
  end

  def group_by_row_headers
    # Assume all agents have the same metrics and timestamps
    # so that we can capture a sample metric and its timestamps for structure
    sample_agent_report = agent_reports.values.first
    sample_metric = sample_agent_report.keys.first
    readable_group_by_csv_labels(sample_agent_report[sample_metric], params[:group_by])
  end

  def column_headers
    ['Date', *agent_reports.keys]
  end

  def detailed_report_for_metric(metric, rows)
    # Split each metric into its own section of the detailed report
    rows << report_section_title(metric)

    # Prepare row with agent names
    rows << column_headers

    # Prepare data rows for each group_by label (day, week, month, year) and corresponding agent values
    group_by_row_headers.each do |group_by_label|
      group_by_row = [group_by_label]
      agent_reports.each do |_agent_name, report|
        data_point = report[metric].find do |data|
          readable_group_by_csv_labels([data], params[:group_by]).first == group_by_label
        end
        value = data_point ? metric_value(metric, data_point) : 0
        group_by_row << value
      end
      rows << group_by_row
    end

    # Add empty row for separation
    rows << []
  end

  def metric_value(metric, data_point)
    if V2::ReportBuilder::TIME_METRICS.include?(metric.to_s)
      time_to_minutes(data_point[:value])
    else
      data_point[:value]
    end
  end

  def time_to_minutes(time_in_seconds)
    (time_in_seconds / 60).to_i
  end

  # TODO change these to the correct timezone later on
  def timestamp_to_date(timestamp)
    Time.at(timestamp).utc.strftime('%B %d %Y')
  end

  def timestamp_to_week(timestamp)
    Time.at(timestamp).utc.strftime('%G-W%V-%u')
  end

  def timestamp_to_month(timestamp)
    Time.at(timestamp).utc.strftime('%Y-%m')
  end

  def timestamp_to_year(timestamp)
    Time.at(timestamp).utc.strftime('%Y')
  end

  def readable_group_by_csv_labels(detailed_metric, group_by_period)
    detailed_metric.map do |element|
      case group_by_period
      when 'day'
        timestamp_to_date(element[:timestamp])
      when 'week'
        timestamp_to_week(element[:timestamp])
      when 'month'
        timestamp_to_month(element[:timestamp])
      when 'year'
        timestamp_to_year(element[:timestamp])
      end
    end
  end
end
