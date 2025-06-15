require "securerandom"
require "digest"
require "base64"
require "net/http"
require "json"

class ClaudeOauthController < ApplicationController
  before_action :set_agent

  OAUTH_REFRESH_URL = "https://console.anthropic.com/v1/oauth/token"

  OAUTH_AUTHORIZE_URL = "https://claude.ai/oauth/authorize"
  OAUTH_TOKEN_URL = "https://console.anthropic.com/v1/oauth/token"
  CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
  REDIRECT_URI = "https://console.anthropic.com/oauth/code/callback"

  def login_start
    state = SecureRandom.hex(32)
    code_verifier = SecureRandom.urlsafe_base64(32)
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier)).chomp("=")

    session[:claude_oauth_state] = {
      "agent_id" => @agent.id,
      "state" => state,
      "code_verifier" => code_verifier,
      "timestamp" => Time.now.to_i,
      "expires_at" => Time.now.to_i + 600
    }

    params = {
      "code" => "true",
      "client_id" => CLIENT_ID,
      "response_type" => "code",
      "redirect_uri" => REDIRECT_URI,
      "scope" => "org:create_api_key user:profile user:inference",
      "code_challenge" => code_challenge,
      "code_challenge_method" => "S256",
      "state" => state
    }

    @login_url = "#{OAUTH_AUTHORIZE_URL}?" + URI.encode_www_form(params)
  end

  def login_finish
    authorization_code = params[:code]

    if authorization_code.blank?
      redirect_to @agent, alert: "No authorization code provided"
      return
    end

    unless verify_state
      redirect_to @agent, alert: "Invalid or expired state. Please try again."
      return
    end

    tokens = exchange_code_for_tokens(authorization_code)

    if tokens
      @agent.update(oauth_credentials: tokens.to_json)
      session.delete(:claude_oauth_state)
      redirect_to @agent, notice: "OAuth login successful!"
    else
      redirect_to @agent, alert: "OAuth login failed. Please try again."
    end
  end

  def refresh
    if @agent.oauth_credentials.blank?
      redirect_to @agent, alert: "No OAuth credentials to refresh"
      return
    end

    credentials = JSON.parse(@agent.oauth_credentials)
    refresh_token = credentials.dig("claudeAiOauth", "refreshToken")

    if refresh_token.blank?
      redirect_to @agent, alert: "No refresh token available"
      return
    end

    new_tokens = refresh_oauth_tokens(refresh_token)

    if new_tokens
      @agent.update(oauth_credentials: new_tokens.to_json)
      redirect_to @agent, notice: "OAuth tokens refreshed successfully!"
    else
      redirect_to @agent, alert: "Failed to refresh OAuth tokens. Please login again."
    end
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def verify_state
    state_data = session[:claude_oauth_state]
    return false unless state_data

    current_time = Time.now.to_i
    return false if current_time > state_data["expires_at"]
    return false if state_data["agent_id"] != @agent.id

    true
  end

  def exchange_code_for_tokens(authorization_code)
    state_data = session[:claude_oauth_state]
    code_verifier = state_data["code_verifier"]

    uri = URI(OAUTH_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    request["Accept"] = "application/json, text/plain, */*"
    request["Accept-Language"] = "en-US,en;q=0.9"
    request["Referer"] = "https://claude.ai/"
    request["Origin"] = "https://claude.ai"

    params = {
      "grant_type" => "authorization_code",
      "client_id" => CLIENT_ID,
      "code" => authorization_code.split("#").first.split("&").first,
      "redirect_uri" => REDIRECT_URI,
      "code_verifier" => code_verifier,
      "state" => state_data["state"]
    }

    request.body = JSON.generate(params)

    begin
      response = http.request(request)

      if response.code == "200"
        data = JSON.parse(response.body)

        {
          "claudeAiOauth" => {
            "accessToken" => data["access_token"],
            "refreshToken" => data["refresh_token"],
            "expiresAt" => (Time.now.to_i + data["expires_in"]) * 1000,
            "scopes" => data["scope"] ? data["scope"].split(" ") : [ "user:inference", "user:profile" ],
            "isMax" => true
          }
        }
      else
        Rails.logger.error "OAuth token exchange failed: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "Error making token request: #{e.message}"
      nil
    end
  end

  def refresh_oauth_tokens(refresh_token)
    uri = URI(OAUTH_REFRESH_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    request["Accept"] = "application/json, text/plain, */*"
    request["Accept-Language"] = "en-US,en;q=0.9"
    request["Referer"] = "https://claude.ai/"
    request["Origin"] = "https://claude.ai"

    params = {
      "grant_type" => "refresh_token",
      "client_id" => CLIENT_ID,
      "refresh_token" => refresh_token
    }

    request.body = JSON.generate(params)

    begin
      response = http.request(request)

      if response.code == "200"
        data = JSON.parse(response.body)

        {
          "claudeAiOauth" => {
            "accessToken" => data["access_token"],
            "refreshToken" => data["refresh_token"],
            "expiresAt" => (Time.now.to_i + data["expires_in"]) * 1000,
            "scopes" => data["scope"] ? data["scope"].split(" ") : [ "user:inference", "user:profile" ],
            "isMax" => true
          }
        }
      else
        Rails.logger.error "OAuth token refresh failed: #{response.code} - #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "Error refreshing token: #{e.message}"
      nil
    end
  end
end
