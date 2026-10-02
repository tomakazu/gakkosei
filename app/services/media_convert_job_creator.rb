class MediaConvertJobCreator
  def initialize(video)
    @video = video
  end

  def call
    client.create_job(job_params).job.id
  end

  private

  attr_reader :video

  def client
    @client ||= Aws::MediaConvert::Client.new(
      region: ENV["AWS_REGION"],
      endpoint: ENV["MEDIACONVERT_ENDPOINT"]
    )
  end

  def input_s3_path
    "s3://#{ENV['S3_BUCKET_NAME']}/#{video.raw_video.key}"
  end

  def output_s3_destination
    "s3://#{ENV['S3_BUCKET_NAME']}/processed/#{video.id}/"
  end

  def job_params
    {
      role: ENV["MEDIACONVERT_ROLE_ARN"],
      settings: {
        inputs: [
          { file_input: input_s3_path }
        ],
        output_groups: [
          {
            name: "Apple HLS",
            output_group_settings: {
              type: "HLS_GROUP_SETTINGS",
              hls_group_settings: {
                destination: output_s3_destination,
                segment_length: 6,
                min_segment_length: 0
              }
            },
            outputs: [
              rendition_output("480p", 854, 480, 1_500_000),
              rendition_output("720p", 1280, 720, 3_000_000)
            ]
          }
        ]
      }
    }
  end

  def rendition_output(name_modifier, width, height, max_bitrate)
    {
      name_modifier: "_#{name_modifier}",
      video_description: {
        width: width,
        height: height,
        codec_settings: {
          codec: "H_264",
          h264_settings: {
            max_bitrate: max_bitrate,
            rate_control_mode: "QVBR"
          }
        }
      },
      container_settings: { container: "M3U8" }
    }
  end
end