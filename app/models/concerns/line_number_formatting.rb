module LineNumberFormatting
  extend ActiveSupport::Concern

  def format_code_with_line_numbers(text)
    return "" if text.nil?

    lines = text.lines
    numbered_lines = []

    lines.each_with_index do |line, index|
      # Check if line already has line numbers (format: "   123→content")
      if line =~ /^\s*(\d+)→(.*)$/
        numbered_lines << { number: $1.to_i, content: $2 }
      else
        numbered_lines << { number: index + 1, content: line }
      end
    end

    numbered_lines
  end

  def strip_line_numbers(text)
    return "" if text.nil?

    text.lines.map do |line|
      if line =~ /^\s*\d+→(.*)$/
        $1
      else
        line
      end
    end.join
  end
end
