RSpec::Matchers.define :have_output_including do |output_name|
  match do |stack|
    if !stack.is_a?(Hash) || !stack[:template_file]
      raise ArgumentError, "You must pass a hash to this expectation with at least the :template_file option"
    end

    stack[:compile_state] ||= {}

    begin
      template_body = CloudFormationRSpec::Sparkle.compile_sparkle_template(stack[:template_file], stack[:compile_state])
    rescue CloudFormationRSpec::Sparkle::InvalidTemplate => error
      @error = error
      return false
    end

    template = JSON.load(template_body)
    if template["Outputs"].nil?
      @error = "No output found in template"
      return false
    end

    output_keys = template["Outputs"].keys
    if !output_keys.include?(output_name)
      @error = %Q(
No output named #{output_name} in the list of outputs:
#{output_keys.join("\n")}
      )
      return false
    end
    true
  end

  failure_message do
    @error
  end
end
