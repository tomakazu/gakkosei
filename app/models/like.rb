class Like < ApplicationRecord
  belongs_to :user
  belongs_to :video, counter_cache: true

  validates :user_id, uniqueness: { scope: :video_id, message: "has already liked this video" }
end