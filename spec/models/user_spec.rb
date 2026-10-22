require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username) }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
    it { is_expected.to have_secure_password }

    it { is_expected.to allow_value("rishabh@example.com").for(:email) }
    it { is_expected.not_to allow_value("not-an-email").for(:email) }
  end

  describe "associations" do
    it { is_expected.to have_many(:videos).dependent(:destroy) }
    it { should have_many(:likes).dependent(:destroy) }
    it { should have_many(:liked_videos).through(:likes).source(:video) }
  end
end