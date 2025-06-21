class UserSettingsController < ApplicationController
  def show
    @user = Current.user
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    user_update_params = user_params

    if user_update_params[:github_token].blank?
      user_update_params.delete(:github_token)
    end

    if user_update_params[:ssh_key].blank?
      user_update_params.delete(:ssh_key)
    end

    if @user.update(user_update_params)
      redirect_to user_settings_path, notice: "Settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:github_token, :ssh_key, :instructions, :git_config, :allow_github_token_access, :shrimp_mode)
  end
end
