require 'json'
require 'yaml'

RSpec::Matchers.define :have_output_including do |output_name|
  define_method :sparkle_template_outputs do |stack|
    stack[:compile_state] ||= {}
  
    begin
      template_body = CloudFormationRSpec::Sparkle.compile_sparkle_template(stack[:template_file], stack[:compile_state])
    rescue CloudFormationRSpec::Sparkle::InvalidTemplate => error
      @error = error
      return false
    end

    template = JSON.load(template_body)

    template["Outputs"].nil? ? [] : template["Outputs"].keys
  end

  define_method :json_template_outputs do |template|
    template = JSON.load(template)
    template["Outputs"].nil? ? [] : template["Outputs"].keys
  end

  define_method :yaml_template_outputs do |template|
    template = YAML.load(template)
    template["Outputs"].nil? ? [] : template["Outputs"].keys
  end

  match do |stack|
    if stack.is_a?(Hash) && stack[:compiler] == :sparkleformation
      if !stack[:template_file]
        raise ArgumentError, "You must pass a hash to this expectation with at least the :template_file option"
      end
      outputs = sparkle_template_outputs(stack)
    elsif !stack.is_a?(String)
      raise ArgumentError, "You must pass a hash for SparkleFormation templates, or a string for YAML/JSON templates"
    else
      begin
        outputs = json_template_outputs(stack)
      rescue JSON::ParserError => error
        json_error = error
      end
  
      begin
        outputs = yaml_template_outputs(stack)
      rescue Psych::SyntaxError => error
        yaml_error = error
      end  
    end

    if outputs.nil?
      raise ArgumentError, "Unable to parse template as either YAML or JSON. Errors are:\nJson #{json_error}\nYaml #{yaml_error}"
    end
    @actual = outputs
    outputs.include?(output_name)
  end

  diffable

  failure_message do
    @error
  end
end
