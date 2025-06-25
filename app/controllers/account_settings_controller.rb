class AccountSettingsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    # Filter out password fields if they're blank
    filtered_params = account_params
    if filtered_params[:password].blank?
      filtered_params.delete(:password)
      filtered_params.delete(:password_confirmation)
    end

    if @user.update(filtered_params)
      redirect_to user_settings_path, notice: "Account settings updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
