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
      @url      = url
      @params   = parse_params(url)
      @referrer = referrer
    end

    def detect
      if @params.nil?
        return @referrer.present? ? detect_from_referrer : nil
      end

      detect_from_click_id ||
        detect_from_utm ||
        detect_from_referrer ||
        detect_from_location_and_referrer
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
      return nil if @referrer.blank?
      return nil if same_url?(@url, @referrer)

      referrer_params = parse_params(@referrer)
      return nil if referrer_params && has_tracking_params?(referrer_params)

      :organic
    end

    def detect_from_location_and_referrer
      return nil unless !has_tracking_params?(@params) && @referrer.present? && same_domain?(@url, @referrer)

      referrer_params = parse_params(@referrer)
      detect_click_id_from_params(referrer_params) if referrer_params
    end

    def has_tracking_params?(params)
      return false if params.blank?

      params.keys.any? { |k| k.start_with?("utm_") } ||
        params.key?("gclid") || params.key?("fbclid") || params.key?("li_fat_id")
    end

    def detect_click_id_from_params(params)
      CLICK_ID_CHANNELS.each do |param, channel|
        return channel if params.key?(param)
      end
      nil
    end

    def same_url?(url1, url2)
      return false if url1.blank? || url2.blank?

      url1.strip == url2.strip
    end

    def same_domain?(url1, url2)
      return false if url1.blank? || url2.blank?

      begin
        uri1 = URI.parse(url1)
        uri2 = URI.parse(url2)

        domain1 = extract_main_domain(uri1.host)
        domain2 = extract_main_domain(uri2.host)

        domain1.present? && domain2.present? && domain1 == domain2
      rescue URI::InvalidURIError, ArgumentError
        false
      end
    end

    def extract_main_domain(host)
      return nil if host.blank?

      host = host.sub(/^www\./, "")

      parts = host.split(".")
      return host if parts.length <= 2

      if parts[-1].length == 2 && parts[-2].length <= 3
        parts[-3..-1].join(".")
      else
        parts[-2..-1].join(".")
      end
    end

    def match_organic_url?(url)
      regex = %r{^https?:\/\/(www\.)?(google|bing|br\.yahoo|duckduckgo|searchencrypt|msn|ask|terra)\.com(\.br)?(\/|$)}
      url&.match?(regex) || false
    end
  end
end
