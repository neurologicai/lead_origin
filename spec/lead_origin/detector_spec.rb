# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeadOrigin::Detector do
  subject(:detect) { described_class.new(url: url, referrer: referrer).detect }

  let(:referrer) { nil }

  context "when detecting click ID (highest priority)" do
    context "with fbclid" do
      let(:url) { "https://example.com?fbclid=abc123" }

      it { is_expected.to eq(:facebook) }
    end

    context "with gclid" do
      let(:url) { "https://example.com?gclid=abc123" }

      it { is_expected.to eq(:google) }
    end

    context "with li_fat_id" do
      let(:url) { "https://example.com?li_fat_id=abc123" }

      it { is_expected.to eq(:linkedin) }
    end

    context "with fbclid and utm_source=google" do
      let(:url) { "https://example.com?fbclid=abc&utm_source=google" }

      it "prefers click ID over UTM" do
        expect(subject).to eq(:facebook)
      end
    end
  end

  context "when detecting UTM source" do
    context "with utm_source=google" do
      let(:url) { "https://example.com?utm_source=google" }

      it { is_expected.to eq(:google) }
    end

    context "with utm_source=facebook" do
      let(:url) { "https://example.com?utm_source=facebook" }

      it { is_expected.to eq(:facebook) }
    end

    context "with utm_source=fb" do
      let(:url) { "https://example.com?utm_source=fb" }

      it { is_expected.to eq(:facebook) }
    end

    context "with utm_source=linkedin" do
      let(:url) { "https://example.com?utm_source=linkedin" }

      it { is_expected.to eq(:linkedin) }
    end

    context "with utm_source=newsletter (unknown source)" do
      let(:url) { "https://example.com?utm_source=newsletter" }

      it { is_expected.to be_nil }
    end

    context "with utm_source and referrer" do
      let(:url)      { "https://example.com?utm_source=google" }
      let(:referrer) { "https://some-site.com" }

      it "prefers UTM over referrer" do
        expect(subject).to eq(:google)
      end
    end
  end

  context "when detecting referrer" do
    let(:url)      { "https://example.com" }
    let(:referrer) { "https://some-site.com" }

    it { is_expected.to eq(:organic) }

    context "with blank referrer" do
      let(:referrer) { "   " }

      it { is_expected.to be_nil }
    end
  end

  # Removed context for direct traffic as it is no longer applicable

  context "with nil or empty URL" do
    let(:url) { nil }

    it { is_expected.to be_nil }

    context "when the string is empty" do
      let(:url) { "" }

      it { is_expected.to be_nil }
    end

    context "when the URL is malformed" do
      let(:url) { "nao_é_uma_url" }

      it { is_expected.to be_nil }
    end
  end
end
