module Api::V2::Accounts::ReportsHelper # rubocop:disable Metrics/ModuleLength
  def generate_agents_report
    Current.account.users.map do |agent|
      agent_report = generate_report({ type: :agent, id: agent.id })
      [agent.name] + generate_readable_report_metrics(agent_report)
    end
  end

  def generate_detailed_agents_report # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    rows = []
    agent_reports = Current.account.users.each_with_object({}) do |agent, reports| 
      reports[agent.name] = generate_detailed_report({ type: :agent, id: agent.id })
    end
  
    # Assume all agents have the same metrics and timestamps
    sample_agent_report = agent_reports.values.first
  
    sample_agent_report.each_key do |metric|
      # Add metric name as a separate row
      rows << [metric.to_s]
      
      # Prepare header row with dates
      header_row = ['Date/Person']
      header_row.concat(agent_reports.keys)
      rows << header_row
  
      # Prepare data rows for each date
      if sample_agent_report[metric].any?
        group_by_field_labels = readable_group_by_csv_labels(sample_agent_report[metric], params[:group_by])
        group_by_field_labels.each do |group_by_label|
          group_by_row = [group_by_label]
          agent_reports.each do |agent_name, report|
            data_point = report[metric].find { |data| readable_group_by_csv_labels([data], params[:group_by]).first == group_by_label }
            value = data_point ? (metric.to_s.in?(['avg_first_response_time', 'avg_resolution_time', 'reply_time']) ? time_to_minutes(data_point[:value]) : data_point[:value]) : 0
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

  def generate_inboxes_report
    Current.account.inboxes.map do |inbox|
      inbox_report = generate_report({ type: :inbox, id: inbox.id })
      [inbox.name, inbox.channel&.name] + generate_readable_report_metrics(inbox_report)
    end
  end

  def generate_teams_report
    Current.account.teams.map do |team|
      team_report = generate_report({ type: :team, id: team.id })
      [team.name] + generate_readable_report_metrics(team_report)
    end
  end

  def generate_labels_report
    Current.account.labels.map do |label|
      label_report = generate_report({ type: :label, id: label.id })
      [label.title] + generate_readable_report_metrics(label_report)
    end
  end

  def generate_report(report_params)
    V2::ReportBuilder.new(
      Current.account,
      report_params.merge(
        {
          since: params[:since],
          until: params[:until],
          business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
        }
      )
    ).summary
  end

  def generate_detailed_report(report_params)
    V2::ReportBuilder.new(
      Current.account,
      report_params.merge(
        {
          since: params[:since],
          until: params[:until],
          group_by: params[:group_by],
          business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
        }
      )
    ).detailed_report
  end

  private

  def generate_readable_report_metrics(report_metric)
    [
      report_metric[:conversations_count],
      time_to_minutes(report_metric[:avg_first_response_time]),
      time_to_minutes(report_metric[:avg_resolution_time])
    ]
  end

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
