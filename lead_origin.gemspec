# frozen_string_literal: true

require_relative "lib/lead_origin/version"

Gem::Specification.new do |spec|
  spec.name    = "lead_origin"
  spec.version = LeadOrigin::VERSION
  spec.authors = ["Neurologic AI"]
  spec.summary = "Identifies the lead acquisition channel from a URL and its parameters."

  spec.files         = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.6.0"
end
