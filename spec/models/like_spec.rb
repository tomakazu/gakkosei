require "rails_helper"

RSpec.describe Like, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:video).counter_cache(true) }
  end

  describe "validations" do
    subject { create(:like) }

    it do
      should validate_uniqueness_of(:user_id)
        .scoped_to(:video_id)
        .with_message("has already liked this video")
    end
  end

  describe "database unique index" do
    it "blocks a duplicate even when validations are skipped" do
      like = create(:like)
      duplicate = build(:like, user: like.user, video: like.video)

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "counter cache" do
    let(:video) { create(:video) }

    it "adds 1 to likes_count when a like is created" do
      expect { create(:like, video: video) }
        .to change { video.reload.likes_count }.from(0).to(1)
    end

    it "takes 1 away from likes_count when a like is destroyed" do
      like = create(:like, video: video)

      expect { like.destroy }
        .to change { video.reload.likes_count }.from(1).to(0)
    end
  end
end