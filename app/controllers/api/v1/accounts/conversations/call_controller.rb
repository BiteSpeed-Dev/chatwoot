require 'net/http'
require 'uri'
require 'json'  # Ensure to require json if you're going to parse JSON

class Api::V1::Accounts::Conversations::CallController < Api::V1::Accounts::Conversations::BaseController
  def create
    account = Account.find_by(id: params[:account_id])
    puts "Account here: #{account}"
    
    call_config = account&.custom_attributes['call_config']
    puts "Call config here: #{call_config} | Blank: #{call_config.blank?} | Custom attributes: #{account.custom_attributes}"

    if call_config.blank?
      render json: { success: false, error: 'Call config not found!' }, status: :bad_request
      return
    end

    # Parse the incoming JSON payload
    payload = JSON.parse(request.body.read) rescue {}
    puts "Parsed payload: #{payload}"

    # Validate payload
    unless payload['to'] && payload['from']
      render json: { success: false, error: 'Missing required fields: to or from' }, status: :bad_request
      return
    end

    url = "https://#{call_config['apiKey']}:#{call_config['token']}#{call_config['subDomain']}/v1/Accounts/#{call_config['sid']}/Calls/connect"
    puts "URL here: #{url}"
    
    uri = URI.parse(url)
    puts "URI here: #{uri.host} #{uri.port}"
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    puts "http here: #{http.keys}"
    request = Net::HTTP::Post.new(uri.path)
    
    # Build form data correctly
    form_data = [
      ['To', payload['to']], 
      ['From', payload['from']], 
      ['CallerId', call_config['callerId']], 
      ['StatusCallback', payload['statusCallback']],
      ['StatusCallbackEvents[0]', 'terminal'],
      ['StatusCallbackEvents[1]', 'answered']
    ]
    
    request.set_form form_data, 'multipart/form-data'
    puts "request here: #{request}"
    
    response = http.request(request)
    puts "Response here: #{response.body}"

    render json: { success: true, response: response.body }
  end
end
