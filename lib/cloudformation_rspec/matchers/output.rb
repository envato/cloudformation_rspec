require 'json'
require 'yaml'

RSpec::Matchers.define :have_output_including do |output_name|
  define_method :json_template? do |template_body|
    template_body =~ /^{/x # ignore leading whitespaces
  end

  define_method :sparkle_template do |stack|
    stack[:compile_state] ||= {}

    CloudFormationRSpec::Sparkle.compile_sparkle_template(stack[:template_file], stack[:compile_state])
  end

  match do |stack|
    if stack.is_a?(Hash) && stack[:compiler] == :sparkleformation
      if !stack[:template_file]
        raise ArgumentError, "You must pass a hash to this expectation with at least the :template_file option"
      end

      begin
        template = sparkle_template(stack)
      rescue CloudFormationRSpec::Sparkle::InvalidTemplate => error
        raise SyntaxError, "Unable to parse SparkleFormation template #{error}"
      end
    elsif !stack.is_a?(String)
      raise ArgumentError, "You must pass a hash for SparkleFormation templates, or a string for YAML/JSON templates"
    else
      template = stack
    end
  
    if json_template?(template)
      decode_function = lambda { |tmpl| JSON.load(tmpl) }
    else
      decode_function = lambda { |tmpl| YAML.load(tmpl) }
    end

    begin
      template = decode_function.call(template)
    rescue JSON::ParserError, Psych::SyntaxError => error
      raise SyntaxError, "Unable to parse template as either YAML or JSON. Got #{error}"
    end
    outputs = template["Outputs"].nil? ? [] : template["Outputs"].keys

    @actual = outputs
    outputs.include?(output_name)
  end

  diffable

  failure_message do
    @error
  end
end
