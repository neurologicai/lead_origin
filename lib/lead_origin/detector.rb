# frozen_string_literal: true

require "uri"
require "cgi"
require "active_support/core_ext/object/blank"

module LeadOrigin
  class Detector
    CLICK_ID_CHANNELS = {
      "fbclid" => :facebook,
      "gclid" => :google,
      "li_fat_id" => :linkedin,
    }.freeze

    UTM_SOURCE_PATTERNS = {
      /facebook|fb/i => :facebook,
      /google/i => :google,
      /linkedin/i => :linkedin,
    }.freeze

    def initialize(url:, referrer: nil)
      @params   = parse_params(url)
      @referrer = referrer
    end

    def detect
      return nil if @params.nil?

      detect_from_click_id ||
        detect_from_utm ||
        detect_from_referrer
    end

    private

    def parse_params(url)
      return nil if url.blank?

      query = URI.parse(url).query
      query ? CGI.parse(query).transform_values(&:first) : {}
    rescue URI::InvalidURIError
      nil
    end

    def detect_from_click_id
      CLICK_ID_CHANNELS.each do |param, channel|
        return channel if @params.key?(param)
      end
      nil
    end

    def detect_from_utm
      source = @params["utm_source"]
      return nil if source.blank?

      UTM_SOURCE_PATTERNS.each do |pattern, channel|
        return channel if source.match?(pattern)
      end

      nil
    end

    def detect_from_referrer
      return nil if @referrer.blank? || @referrer.strip.empty?
      :organic
    end
  end
end
