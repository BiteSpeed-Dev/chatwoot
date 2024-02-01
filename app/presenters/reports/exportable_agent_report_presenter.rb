class Reports::ExportableAgentReportPresenter < SimpleDelegator
  attr_accessor :agent_reports, :params
  def initialize(agent_reports, controller_params)
    @agent_reports = agent_reports
    @params = controller_params
  end

  def csv_rows
    time_metrics = %w[avg_first_response_time avg_resolution_time reply_time]
    rows = []
    # Assume all agents have the same metrics and timestamps
    sample_agent_report = agent_reports.values.first
  
    sample_agent_report.each_key do |metric|
      # Add metric name as a separate row
      if time_metrics.include?(metric.to_s)
        rows << [metric.to_s.titleize + ' (in minutes)']
      else
        rows << [metric.to_s.titleize]
      end
      
      # Prepare header row with dates
      header_row = ['Date']
      header_row.concat(agent_reports.keys)
      rows << header_row
  
      # Prepare data rows for each date
      if sample_agent_report[metric].any?
        group_by_field_labels = readable_group_by_csv_labels(sample_agent_report[metric], params[:group_by])
        group_by_field_labels.each do |group_by_label|
          group_by_row = [group_by_label]
          agent_reports.each do |agent_name, report|
            data_point = report[metric].find do |data| 
              readable_group_by_csv_labels([data], params[:group_by]).first == group_by_label 
            end
            value = if data_point
              if time_metrics.include?(metric.to_s)
                time_to_minutes(data_point[:value])
              else
                data_point[:value]
              end
            else
              0
            end
    
            group_by_row << value
          end
          rows << group_by_row
        end
      end

      # Add empty row for separation
      rows << []
    end

    rows
  end

  private
  def time_to_minutes(time_in_seconds)
    (time_in_seconds / 60).to_i
  end
  # change these to the correct timezone later on
  def timestamp_to_date(timestamp)
    Time.at(timestamp).utc.strftime("%B %d %Y")
  end

  def timestamp_to_week(timestamp)
    Time.at(timestamp).utc.strftime("%G-W%V-%u")
  end

  def timestamp_to_month(timestamp)
    Time.at(timestamp).utc.strftime("%Y-%m")
  end

  def timestamp_to_year(timestamp)
    Time.at(timestamp).utc.strftime("%Y")
  end

  def readable_group_by_csv_labels(detailed_metric, group_by_period)
    labels = detailed_metric.map do |element|
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