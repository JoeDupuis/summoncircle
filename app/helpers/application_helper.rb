module ApplicationHelper
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
end
