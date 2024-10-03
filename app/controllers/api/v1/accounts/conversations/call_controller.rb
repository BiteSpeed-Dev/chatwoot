require 'httparty'
require 'json'

class Api::V1::Accounts::Conversations::CallController < Api::V1::Accounts::Conversations::BaseController
  def create
    account = Account.find_by(id: params[:account_id])
    puts "Account here: #{account}"

    call_config = account&.custom_attributes&.[]('call_config')
    puts "Call config here: #{call_config} | Blank: #{call_config.blank?} | Custom attributes: #{account.custom_attributes}"

    if call_config.blank?
      render json: { success: false, error: 'Call config not found!' }, status: :bad_request
      return
    end

    payload = begin
      JSON.parse(request.body.read)
    rescue StandardError
      {}
    end
    puts "Parsed payload: #{payload}"

    unless payload['to'] && payload['from']
      render json: { success: false, error: 'Missing required fields: to or from' }, status: :bad_request
      return
    end

    url = "https://#{call_config['apiKey']}:#{call_config['token']}#{call_config['subDomain']}/v1/Accounts/#{call_config['sid']}/Calls/connect"
    puts "URL here: #{url}"

    form_data = {
      To: payload['to'],
      From: payload['from'],
      CallerId: call_config['callerId'],
      StatusCallback: payload['statusCallback'],
      'StatusCallbackEvents[0]': 'terminal',
      'StatusCallbackEvents[1]': 'answered',
      StatusCallbackContentType: 'application/json'
    }

    response = HTTParty.post(
      url,
      basic_auth: { username: call_config['apiKey'], password: call_config['token'] },
      body: form_data
    )

    puts "Response here: #{response.code} #{response.message}"

    render json: { success: true, response: response.body }
  end
end
