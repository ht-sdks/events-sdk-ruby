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

  # logger left the default gem set in Ruby 4.0
  spec.add_dependency 'logger'

  # Used in the executable testing script
  spec.add_development_dependency 'commander', '~> 4.4'

  # Used in specs
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  # Specs only: TimeWithZone. Use a patched release (7.2.3.1+); skip on
  # older Rubies rather than installing EOL 5.2.
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1')
    spec.add_development_dependency 'activesupport', '>= 7.2.3.1'
    spec.add_development_dependency 'tzinfo', '~> 2.0'
  end
  # Latest Oj (3.17.6) patches multiple memory-safety CVEs and requires MRI >= 2.7.
  if RUBY_PLATFORM != 'java' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7')
    spec.add_development_dependency 'oj', '~> 3.17.6'
  end
  spec.add_development_dependency 'rubocop', '~> 1.0'
end
