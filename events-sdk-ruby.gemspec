require File.expand_path('../lib/hightouch/analytics/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name = 'events-sdk-ruby'
  spec.version = Hightouch::Analytics::VERSION
  spec.files = Dir.glob("{lib,bin}/**/*")
  spec.require_paths = ['lib']
  spec.bindir = 'bin'
  spec.executables = ['analytics']
  spec.summary = 'Hightouch Events SDK'
  spec.description = 'Hightouch Events SDK'
  spec.authors = ['HT-SDKS']
  spec.email = 'engineering@hightouch.com'
  spec.homepage = 'https://github.com/ht-sdks/events-sdk-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.0'

  # Used in the executable testing script
  spec.add_development_dependency 'commander', '~> 4.4'

  # Used in specs
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'tzinfo', '~> 1.2'
  spec.add_development_dependency 'activesupport', '~> 5.2.0'
  if RUBY_PLATFORM != 'java'
    spec.add_development_dependency 'oj', '~> 3.6.2'
  end
  spec.add_development_dependency 'rubocop', '~> 1.0'
  spec.add_development_dependency 'codecov', '~> 0.6'
end
