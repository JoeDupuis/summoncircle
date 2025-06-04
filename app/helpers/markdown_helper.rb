require "rouge/plugins/redcarpet"

module MarkdownHelper
  class RougeRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet
  end

  def render_markdown(text)
    return "" if text.blank?

    renderer = RougeRenderer.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      lax_html_blocks: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )

    markdown.render(text).html_safe
  end
end
