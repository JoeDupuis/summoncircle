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

  def markdown(text)
    return "" if text.blank?

    options = {
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      space_after_headers: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: true,
      fenced_code_blocks: true,
      strikethrough: true,
      tables: true,
      underline: true,
      highlight: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown_processor = Redcarpet::Markdown.new(renderer, extensions)

    markdown_processor.render(text).html_safe
  end

  def git_apply_command(diff_content)
    cleaned_diff = diff_content.lines.map(&:rstrip).join("\n")
    <<~COMMAND.strip
      (cd "$(git rev-parse --show-toplevel)" && git apply --3way <<'EOF'
      #{cleaned_diff}
      EOF
      )
    COMMAND
  end
end
