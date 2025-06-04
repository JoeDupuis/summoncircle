require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "renders basic markdown" do
    markdown = "# Heading\n\nThis is a **bold** text and this is *italic*."
    result = render_markdown(markdown)

    assert_includes result, "<h1>Heading</h1>"
    assert_includes result, "<strong>bold</strong>"
    assert_includes result, "<em>italic</em>"
  end

  test "renders code blocks with syntax highlighting" do
    markdown = "```ruby\ndef hello\n  puts 'world'\nend\n```"
    result = render_markdown(markdown)

    assert_includes result, '<div class="highlight">'
    assert_includes result, "hello"
    assert_includes result, "world"
  end

  test "renders links with security attributes" do
    markdown = "[Example](https://example.com)"
    result = render_markdown(markdown)

    assert_includes result, 'target="_blank"'
    assert_includes result, 'rel="noopener noreferrer"'
    assert_includes result, "https://example.com"
  end

  test "renders tables" do
    markdown = "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |"
    result = render_markdown(markdown)

    assert_includes result, "<table>"
    assert_includes result, "<th>Header 1</th>"
    assert_includes result, "<td>Cell 1</td>"
  end

  test "handles empty or nil content" do
    assert_equal "", render_markdown(nil)
    assert_equal "", render_markdown("")
    assert_equal "", render_markdown("   ")
  end

  test "filters HTML for security" do
    markdown = "<script>alert('xss')</script>\n\nSafe content"
    result = render_markdown(markdown)

    refute_includes result, "<script>"
    assert_includes result, "Safe content"
  end
end
