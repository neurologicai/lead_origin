# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeadOrigin::Detector do
  subject(:detect) { described_class.new(url: url, referrer: referrer).detect }

  let(:referrer) { nil }
  let(:url) { location }

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

    context "when location is nil" do
      let(:url) { nil }
      let(:referrer) { "https://www.google.com/search?q=test" }

      it "falls back to referrer for organic detection" do
        expect(subject).to eq(:organic)
      end
    end

    context "when both location and referrer are nil" do
      let(:url) { nil }
      let(:referrer) { nil }

      it "sets analytic_channel to nil" do
        expect(subject).to be_nil
      end
    end

    context "when referrer matches bing" do
      let(:url) { nil }
      let(:referrer) { "https://www.bing.com/search?q=test" }

      it { is_expected.to eq(:organic) }
    end

    context "when referrer matches br.yahoo" do
      let(:url) { nil }
      let(:referrer) { "https://br.yahoo.com/search?q=test" }

      it { is_expected.to eq(:organic) }
    end

    context "when location has no tracking params and referrer is same domain with fbclid=" do
      let(:url) { "https://example.com/page" }
      let(:referrer) { "https://example.com/?fbclid=abc123" }

      it "uses referrer to detect channel" do
        expect(subject).to eq(:facebook)
      end
    end

    context "when location has utm_ params and referrer is same domain with fbclid=" do
      let(:url) { "https://example.com/?utm_source=email" }
      let(:referrer) { "https://example.com/?fbclid=abc123" }

      it "ignores referrer and uses location" do
        expect(subject).to be_nil
      end
    end

    context "when location has no tracking params and referrer is different domain with fbclid=" do
      let(:url) { "https://example.com/page" }
      let(:referrer) { "https://otherdomain.com/?fbclid=abc123" }

      it "ignores referrer and uses location" do
        expect(subject).to be_nil
      end
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
    let(:url) { "https://example.com" }
    let(:referrer) { "https://some-site.com" }

    context "when url and referrer are the same" do
      let(:referrer) { "https://example.com" }

      it { is_expected.to be_nil }
    end

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
