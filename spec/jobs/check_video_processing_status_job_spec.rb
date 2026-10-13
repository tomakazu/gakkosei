require "rails_helper"

RSpec.describe CheckVideoProcessingStatusJob, type: :job do
  let(:client) { Aws::MediaConvert::Client.new(stub_responses: true, region: "ap-south-1") }
  let(:video) do
    create(:video).tap do |v|
      v.raw_video.attach(io: StringIO.new("not a real video"), filename: "sample.mp4", content_type: "video/mp4")
      v.update_columns(status: :processing, mediaconvert_job_id: "job-123")
    end
  end

  before do
    stub_env(
      "AWS_REGION" => "ap-south-1",
      "S3_BUCKET_NAME" => "test-bucket",
      "MEDIACONVERT_ENDPOINT" => "https://example.mediaconvert.ap-south-1.amazonaws.com",
      "CLOUDFRONT_DOMAIN" => "d123.cloudfront.net"
    )
    allow(Aws::MediaConvert::Client).to receive(:new).and_return(client)
  end

  def mediaconvert_says(status)
    client.stub_responses(:get_job, {
        job: { status: status, role: "arn:aws:iam::123456789012:role/test-role", settings: {} }
    })
    end

  context "when the job is COMPLETE" do
    before { mediaconvert_says("COMPLETE") }

    it "marks the video ready with a manifest URL" do
      described_class.perform_now(video.id)

      video.reload
      expect(video.status).to eq("ready")
      expect(video.manifest_url).to end_with("/processed/#{video.id}/#{video.raw_video.key}.m3u8")
    end
  end

  context "when the job ERRORed" do
    before { mediaconvert_says("ERROR") }

    it "marks the video failed" do
      described_class.perform_now(video.id)
      expect(video.reload.status).to eq("failed")
    end
  end

  context "when the job is still PROGRESSING" do
    before { mediaconvert_says("PROGRESSING") }

    it "checks again later" do
      described_class.perform_now(video.id, 1)

      expect(video.reload.status).to eq("processing")
      expect(described_class).to have_been_enqueued.with(video.id, 2)
    end

    it "gives up after the maximum number of attempts" do
      described_class.perform_now(video.id, described_class::MAX_ATTEMPTS)

      expect(video.reload.status).to eq("failed")
      expect(described_class).not_to have_been_enqueued.with(video.id, described_class::MAX_ATTEMPTS + 1)
    end
  end

  it "does nothing for a video that no longer exists" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end