$:.unshift File.expand_path("../lib", __FILE__)

Gem::Specification.new do |gem|
  gem.name    = "cloudformation_rspec"
  gem.version = "0.0.1"

  gem.authors     = ["Patrick Robinson"]
  gem.email       = ["patrick.robinson@envato.com"]
  gem.description = %q{CloudFormation RSpec matchers}
  gem.summary     = %q{Test your CloudFormation templates}
  gem.homepage    = "https://github.com/envato/cloudformation_rspec"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'rspec', '~> 3'
  gem.add_dependency 'sparkle_formation', '~> 3'
  gem.add_dependency 'aws-sdk-cloudformation', '~> 1'
  gem.add_development_dependency 'rake'
end
