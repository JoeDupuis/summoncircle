require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "markdown renders basic text as paragraph" do
    result = markdown("Hello world")
    assert_includes result, "<p>Hello world</p>"
  end

  test "markdown renders headers correctly" do
    result = markdown("# Header 1\n## Header 2")
    assert_includes result, "<h1>Header 1</h1>"
    assert_includes result, "<h2>Header 2</h2>"
  end

  test "markdown renders code blocks" do
    result = markdown("```\nrequire 'test'\n```")
    assert_includes result, "<pre><code>"
    assert_includes result, "require &#39;test&#39;"
  end

  test "markdown renders inline code" do
    result = markdown("Use `code` here")
    assert_includes result, "<code>code</code>"
  end

  test "markdown renders lists" do
    result = markdown("- Item 1\n- Item 2")
    assert_includes result, "<ul>"
    assert_includes result, "<li>Item 1</li>"
    assert_includes result, "<li>Item 2</li>"
  end

  test "markdown renders links with security attributes" do
    result = markdown("[Link](https://example.com)")
    assert_includes result, 'rel="nofollow"'
    assert_includes result, 'target="_blank"'
  end

  test "markdown handles empty text" do
    assert_equal "", markdown("")
    assert_equal "", markdown(nil)
  end

  test "markdown filters HTML for security" do
    result = markdown("<script>alert('xss')</script>")
    refute_includes result, "<script>"
  end

  test "markdown renders strikethrough" do
    result = markdown("~~strikethrough text~~")
    assert_includes result, "<del>strikethrough text</del>"
  end

  test "markdown renders tables" do
    table_markdown = "| Col 1 | Col 2 |\n|-------|-------|\n| A | B |"
    result = markdown(table_markdown)
    assert_includes result, "<table>"
    assert_includes result, "<th>Col 1</th>"
    assert_includes result, "<td>A</td>"
  end
end
