# frozen_string_literal: true

require "lead_origin/version"
require "lead_origin/detector"

module LeadOrigin
  def self.detect(url:, referrer: nil)
    Detector.new(url: url, referrer: referrer).detect
  end
end
