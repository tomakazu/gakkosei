require "rails_helper"

RSpec.describe Video, type: :model do
  subject { build(:video) }

  describe "validations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }

    it "cannot be ready without a video file" do
      video = build(:video, status: :ready)
      expect(video).not_to be_valid
      expect(video.errors[:raw_video]).to include("must be attached before marking as ready")
    end
  end

  describe "enums" do
    it do
      is_expected.to define_enum_for(:status)
        .with_values(pending_upload: 0, processing: 1, ready: 2, failed: 3)
    end

    it do
      is_expected.to define_enum_for(:visibility)
        .with_values(public_video: 0, unlisted: 1, private_video: 2)
    end

    it "starts as pending_upload and private by default" do
      video = Video.new
      expect(video.status).to eq("pending_upload")
      expect(video.visibility).to eq("private_video")
    end
  end

  describe "transcoding after create" do
    let(:creator) { instance_double(MediaConvertJobCreator, call: "job-123") }

    before { allow(MediaConvertJobCreator).to receive(:new).and_return(creator) }

    context "when a file is attached" do
      it "submits a MediaConvert job and marks the video processing" do
        video = create(:video, :with_file)

        expect(video.reload.status).to eq("processing")
        expect(video.mediaconvert_job_id).to eq("job-123")
      end

      it "starts polling for the result" do
        video = create(:video, :with_file)
        expect(CheckVideoProcessingStatusJob).to have_been_enqueued.with(video.id)
      end
    end

    context "when no file is attached" do
      it "does not submit a job" do
        video = create(:video)

        expect(MediaConvertJobCreator).not_to have_received(:new)
        expect(video.reload.status).to eq("pending_upload")
      end
    end

    context "when MediaConvert rejects the job" do
      before { allow(creator).to receive(:call).and_raise(StandardError, "AWS said no") }

      it "marks the video failed instead of crashing" do
        video = create(:video, :with_file)
        expect(video.reload.status).to eq("failed")
      end
    end
  end

  describe "associations" do
    it { should belong_to(:user) }
    it { should have_many(:likes).dependent(:destroy) }
  end
end