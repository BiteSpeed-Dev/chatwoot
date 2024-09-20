class DeviseOverrides::TokenValidationsController < DeviseTokenAuth::TokenValidationsController
  include BspdAccessHelper

  def validate_token
    # @resource will have been set by set_user_by_token concern
    if @resource
      Rails.logger.info "Active Account ID: #{@resource.account_id}"
      render_validate_token_error unless billing_status(@resource.account_id)

      render 'devise/token', formats: [:json]
    else
      render_validate_token_error
    end
  end
end
