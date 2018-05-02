require 'json'
require 'yaml'

module CloudFormationRSpec::Matchers::Output

  def validate_sparkleformation_template_has_output(stack, output_name)
    if !stack[:template_file]
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

    validate_template_has_output(template, output_name)
  end

  def validate_template_has_output(template, output_name)
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
end

RSpec::Matchers.define :have_output_including do |output_name|
  include CloudFormationRSpec::Matchers::Output
  match do |stack|
    if stack.is_a?(Hash) && stack[:compiler] == :sparkleformation
      return validate_sparkleformation_template_has_output(stack, output_name)
    end

    if !stack.is_a?(String)
      raise ArgumentError, "You must pass a hash for SparkleFormation templates, or a string for YAML/JSON templates"
    end

    begin
      template = JSON.load(stack)
      return validate_template_has_output(template, output_name)
    rescue JSON::ParserError => error
      json_error = error
    end

    begin
      template = YAML.load(stack)
      return validate_template_has_output(template, output_name)
    rescue Psych::SyntaxError => error
      yaml_error = error
    end

    raise ArgumentError, "Unable to parse template as either YAML or JSON. Errors are:\nJson #{json_error}\nYaml #{yaml_error}"
  end

  failure_message do
    @error
  end
end
