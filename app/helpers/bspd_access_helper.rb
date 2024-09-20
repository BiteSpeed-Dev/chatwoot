module BspdAccessHelper
  def billing_status(active_account_id)
    # api call to bitespeed to check billing status
    # get api call to localhost:3001/csdb/auth/verify with accountId as query param
    # if api call is successful, return true
    # else return false

    response = HTTParty.get("http://localhost:3003/prod/csdb/auth/verify?accountId=#{active_account_id}")
    Rails.logger.info "BSPD Access Helper: Billing status response - #{response}"
    response.success?
  rescue StandardError => e
    Rails.logger.error "BSPD Access Helper: Error checking billing status - #{e.message}"
    false
  end
end
