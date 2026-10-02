class CheckVideoProcessingStatusJob < ApplicationJob
  queue_as :default

  RETRY_DELAY = 20.seconds
  MAX_ATTEMPTS = 30 # ~10 minutes of polling before giving up

  def perform(video_id, attempt = 1)
    video = Video.find_by(id: video_id)
    return unless video&.mediaconvert_job_id

    job_status = fetch_job_status(video.mediaconvert_job_id)

    case job_status
    when "COMPLETE"
      mark_ready(video)
    when "ERROR", "CANCELED"
      video.update_columns(status: :failed)
      Rails.logger.error("MediaConvert job #{video.mediaconvert_job_id} failed for video #{video.id}")
    else
      # still PROGRESSING or SUBMITTED
      if attempt < MAX_ATTEMPTS
        self.class.set(wait: RETRY_DELAY).perform_later(video_id, attempt + 1)
      else
        video.update_columns(status: :failed)
        Rails.logger.error("MediaConvert job #{video.mediaconvert_job_id} timed out for video #{video.id}")
      end
    end
  end

  private

  def fetch_job_status(job_id)
    client = Aws::MediaConvert::Client.new(
      region: ENV["AWS_REGION"],
      endpoint: ENV["MEDIACONVERT_ENDPOINT"]
    )
    client.get_job(id: job_id).job.status
  end

  def mark_ready(video)
    base_filename = video.raw_video.key
    manifest_url = "https://#{ENV['S3_BUCKET_NAME']}.s3.#{ENV['AWS_REGION']}.amazonaws.com/processed/#{video.id}/#{base_filename}.m3u8"
    video.update_columns(status: :ready, manifest_url: manifest_url)
  end
end