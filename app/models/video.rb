class Video < ApplicationRecord
  belongs_to :user

  has_one_attached :raw_video

  after_commit :trigger_transcoding, on: :create, if: -> { raw_video.attached? }

  enum :status, { pending_upload: 0, processing: 1, ready: 2, failed: 3 }, default: :pending_upload
  enum :visibility, { public_video: 0, unlisted: 1, private_video: 2 }, default: :private_video

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 5000 }

  # Basic guard: don't let a video go "ready" without an actual file attached
  validate :raw_video_present_if_ready

  private

  def raw_video_present_if_ready
    if ready? && !raw_video.attached?
      errors.add(:raw_video, "must be attached before marking as ready")
    end
  end

  def trigger_transcoding
    job_id = MediaConvertJobCreator.new(self).call
    update_columns(mediaconvert_job_id: job_id, status: :processing)
    CheckVideoProcessingStatusJob.perform_later(id)
  rescue => e
    update_columns(status: :failed)
    Rails.logger.error("MediaConvert job submission failed for video #{id}: #{e.message}")
  end
end