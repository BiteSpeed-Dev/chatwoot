module CallHelper
  def get_call_log_string(callback_payload)
    agent_log = callback_payload['Legs'].first
    user_log = callback_payload['Legs'].last
    agent_call_status = agent_log['Status']
    user_call_status = user_log['Status']
    event_type = callback_payload['EventType']

    case event_type
    when 'terminal'
      return 'Call was connected to agent but they were busy' if agent_call_status == 'busy'
      return "Call was connected to agent but they didn't pick up the call" if agent_call_status == 'no-answer'
      return 'Call was connected to user but they were busy' if user_call_status == 'busy'
      return "Call was connected to user but they didn't pick up the call" if user_call_status == 'no-answer'
      return "Call was completed\nCall Duration: #{user_log['OnCallDuration']}" if callback_payload['Status'] == 'completed'
    when 'answered'
      if agent_call_status == 'in-progress' && user_call_status == 'in-progress'
        'Both user and agent are on the call'
      elsif agent_call_status == 'in-progress'
        'Agent has picked up the call'
      elsif user_call_status == 'in-progress'
        'User has picked up the call'
      end
    end
  end
end
