require "rails_helper"

RSpec.describe JsonWebToken do
  describe ".encode / .decode" do
    it "round-trips the payload" do
      token = described_class.encode(user_id: 42)
      expect(described_class.decode(token)[:user_id]).to eq(42)
    end

    it "returns nil for an expired token" do
      token = described_class.encode({ user_id: 42 }, 1.minute.ago)
      expect(described_class.decode(token)).to be_nil
    end

    it "returns nil for a tampered token" do
      token = described_class.encode(user_id: 42)
      tampered = token[0..-2] + (token[-1] == "a" ? "b" : "a")
      expect(described_class.decode(tampered)).to be_nil
    end

    it "returns nil for garbage" do
      expect(described_class.decode("not.a.token")).to be_nil
    end
  end
end