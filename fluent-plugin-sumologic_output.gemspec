# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-sumologic_output"
  gem.version       = "1.9.0"
  gem.authors       = ["Steven Adams", "Frank Reno"]
  gem.email         = ["stevezau@gmail.com", "frank.reno@me.com"]
  gem.description   = %q{Output plugin to SumoLogic HTTP Endpoint}
  gem.summary       = %q{Output plugin to SumoLogic HTTP Endpoint}
  gem.homepage      = "https://github.com/SumoLogic/fluentd-output-sumologic"
  gem.license       = "Apache-2.0"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "bundler"
  gem.add_development_dependency "rake"
  gem.add_development_dependency 'test-unit'
  gem.add_development_dependency "codecov"
  gem.add_runtime_dependency "fluentd"
  gem.add_runtime_dependency 'httpclient'
end
