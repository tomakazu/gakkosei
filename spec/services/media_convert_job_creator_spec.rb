require "rails_helper"

RSpec.describe MediaConvertJobCreator do
  # AWS SDK's built-in simulator: no network, no credentials, no cost
  let(:client) { Aws::MediaConvert::Client.new(stub_responses: true, region: "ap-south-1") }

  # Attach the file AFTER creating, so the create callback doesn't run the real creator
  let(:video) do
    create(:video).tap do |v|
      v.raw_video.attach(io: StringIO.new("not a real video"), filename: "sample.mp4", content_type: "video/mp4")
    end
  end

  before do
    stub_env(
      "AWS_REGION" => "ap-south-1",
      "S3_BUCKET_NAME" => "test-bucket",
      "MEDIACONVERT_ENDPOINT" => "https://example.mediaconvert.ap-south-1.amazonaws.com",
      "MEDIACONVERT_ROLE_ARN" => "arn:aws:iam::123456789012:role/test-role"
    )
    allow(Aws::MediaConvert::Client).to receive(:new).and_return(client)
    client.stub_responses(:create_job, {
        job: { id: "job-abc", role: "arn:aws:iam::123456789012:role/test-role", settings: {} }
    })
  end

  it "returns the MediaConvert job id" do
    expect(described_class.new(video).call).to eq("job-abc")
  end

  describe "the job it submits" do
    subject(:params) do
      described_class.new(video).call
      client.api_requests.first[:params]
    end

    it "uses the MediaConvert role" do
      expect(params[:role]).to eq("arn:aws:iam::123456789012:role/test-role")
    end

    it "reads the uploaded file from S3" do
      expect(params.dig(:settings, :inputs, 0, :file_input))
        .to eq("s3://test-bucket/#{video.raw_video.key}")
    end

    it "writes HLS output into a folder for this video" do
      group = params.dig(:settings, :output_groups, 0)
      expect(group.dig(:output_group_settings, :hls_group_settings, :destination))
        .to eq("s3://test-bucket/processed/#{video.id}/")
    end

    it "creates 480p and 720p renditions" do
      outputs = params.dig(:settings, :output_groups, 0, :outputs)
      expect(outputs.map { |o| o[:name_modifier] }).to eq(%w[_480p _720p])
    end
  end
end