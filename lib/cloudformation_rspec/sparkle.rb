class CloudFormationRSpec::Sparkle
  InvalidSparkleTemplate = Class.new(StandardError)
  InvalidCloudFormationTemplate = Class.new(StandardError)

  def self.compile_sparkle_template(template_file, compile_state)
    begin
      sparkle_template = ::SparkleFormation.compile(template_file, :sparkle)
    rescue RuntimeError, SyntaxError => error
      raise InvalidSparkleTemplate.new("Error compiling template into SparkleTemplate #{error.message}")
    end

    begin
      sparkle_template.compile_state = compile_state
      sparkle_template.to_json
    rescue => error
      raise InvalidCloudFormationTemplate.new("Error compiling template into CloudFormation #{error.message}")
    end
  end
end
