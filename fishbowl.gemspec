# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fishbowl/version'
require 'English'

Gem::Specification.new do |spec|
  spec.name        = 'fishbowl'
  spec.version     = Fishbowl::VERSION
  spec.summary     = 'Interface for Fishbowl API'
  spec.description = 'Tested support for Fishbowl older versions 2020.10'
  spec.authors     = ['BistroMD']
  spec.email       = 'andrew.paliyan@bistromd.com'
  spec.files       = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.homepage    = 'https://github.com/bistromd/fishbowl'
  spec.license     = 'MIT'

  spec.add_runtime_dependency 'socketry', '~> 0.5', '>= 0.5.1'

  spec.metadata['rubygems_mfa_required']  = 'true'
  spec.required_ruby_version              = '>= 3.0.3'
end
