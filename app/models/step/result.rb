class Step::Result < Step
  def error?
    parsed_response.is_a?(Hash) && parsed_response["is_error"] == true
  end
end
