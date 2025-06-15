class ClaudeOauthController < ApplicationController
  before_action :set_agent

  def login_start
    oauth = ClaudeOauth.new(@agent)
    @login_url = oauth.login_start

    if @login_url.blank?
      redirect_to @agent, alert: "Failed to generate OAuth login URL"
    end
  rescue => e
    Rails.logger.error "OAuth login start failed: #{e.message}"
    redirect_to @agent, alert: e.message
  end

  def login_finish
    authorization_code = params[:code]

    if authorization_code.blank?
      redirect_to @agent, alert: "No authorization code provided"
      return
    end

    oauth = ClaudeOauth.new(@agent)

    if oauth.login_finish(authorization_code)
      redirect_to @agent, notice: "OAuth login successful!"
    else
      redirect_to @agent, alert: "OAuth login failed. Please try again."
    end
  rescue => e
    Rails.logger.error "OAuth login finish failed: #{e.message}"
    redirect_to @agent, alert: e.message
  end

  def refresh
    oauth = ClaudeOauth.new(@agent)

    unless oauth.check_credentials_exist
      redirect_to @agent, alert: "No OAuth credentials to refresh"
      return
    end

    if oauth.refresh_token
      redirect_to @agent, notice: "OAuth tokens refreshed successfully!"
    else
      redirect_to @agent, alert: "Failed to refresh OAuth tokens. Please login again."
    end
  rescue => e
    Rails.logger.error "OAuth refresh failed: #{e.message}"
    redirect_to @agent, alert: e.message
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end
end
