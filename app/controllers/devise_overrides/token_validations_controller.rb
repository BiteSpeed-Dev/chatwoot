class DeviseOverrides::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  def validate_token
    # @resource will have been set by set_user_by_token concern
    if @resource
      render 'devise/token', formats: [:json]
    else
      render_validate_token_error
    end
    # Rails.logger.info("Token validated for user #{@resource.inspect}")
    # # get all the user's accounts
    # accounts = @resource.accounts
    # Rails.logger.info("User's accounts: #{accounts.inspect}")

    # # get all user account ids
    # account_ids = accounts.pluck(:id)

    # # make a request to 'localhost:3001/csdb/auth/verify?accountId=123 and ifs successful, render the token or else invalidate the token
    # account_ids.each do |account_id|
    #   response = HTTParty.get("http://localhost:3003/prod/csdb/auth/verify?accountId=#{account_id}")
    #   if response.success?
    # render 'devise/token', formats: [:json]
    #     else
    #       # error out with 401 status
    #       render json: { error: 'Unauthorized' }, status: :unauthorized
    #       return
    #     end
    #   end
    # else
    #   render_validate_token_error
    # end
  end
end
