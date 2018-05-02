require 'json'
require 'yaml'

RSpec::Matchers.define :have_output_including do |output_name|
  def json_template?(template_body)
    template_body =~ /^\s*{/ # ignore leading whitespaces
  end

  def compile_sparkle_template(stack)
    stack[:compile_state] ||= {}

    template = CloudFormationRSpec::Sparkle.compile_sparkle_template(stack[:template_file], stack[:compile_state])
    JSON.load(template)
  end

  match do |input|
    if input.is_a?(Hash) && input[:compiler] == :sparkleformation
      unless input[:template_file]
        raise ArgumentError, "You must pass a hash to this expectation with at least the :template_file option"
      end

      decode_function = lambda { |s| compile_sparkle_template(s) }
    elsif !input.is_a?(String)
      raise ArgumentError, "You must pass a hash for SparkleFormation templates, or a string for YAML/JSON templates"
    elsif json_template?(input)
      decode_function = lambda { |tmpl| JSON.load(tmpl) }
    else
      decode_function = lambda { |tmpl| YAML.safe_load(tmpl) }
    end

    begin
      template = decode_function.call(input)
    rescue JSON::ParserError, Psych::SyntaxError, CloudFormationRSpec::Sparkle::InvalidTemplate => error
      raise SyntaxError, "Unable to parse template: #{error}"
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
