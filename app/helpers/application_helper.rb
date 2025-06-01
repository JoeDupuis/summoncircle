module ApplicationHelper
  def form_errors(instance, **locals)
    locals[:instance] = instance
    render partial: "application/form_errors", locals: locals
  end

  def safe_external_link(text, url)
    return content_tag(:span, text) unless url.present?
    return content_tag(:span, text) unless url.start_with?("http://", "https://")

    begin
      uri = URI.parse(url)
      return content_tag(:span, text) unless %w[http https].include?(uri.scheme)
      link_to text, uri.to_s, target: "_blank", rel: "noopener noreferrer"
    rescue URI::InvalidURIError
      content_tag(:span, text)
    end
  end

  def flash_message(message, type: "secondary")
    return nil if message.blank?

    tag.div(
      class: [ "flash-alert", "-#{type}" ].join(" "),
      'data-controller': "alert",
      'data-target': "alert",
      'data-alert-close-btn-class': "close",
      role: "alert"
    ) do
      message
    end
  end

  def current_git_branch
    return nil unless Rails.env.development?

    begin
      `git rev-parse --abbrev-ref HEAD`.strip
    rescue
      nil
    end
  end
end
