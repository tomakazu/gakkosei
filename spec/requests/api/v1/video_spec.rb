require "rails_helper"

RSpec.describe "Videos API", type: :request do

  describe "GET /api/v1/videos (likes in the feed)" do
    let(:user)  { create(:user) }
    let(:other) { create(:user) }

    it "shows likes_count and whether I liked each video" do
      liked_one   = create(:video, title: "Liked",     user: other_user)
      unliked_one = create(:video, title: "Not liked", user: other_user)

      create(:like, user: user,       video: liked_one)
      create(:like, user: other_user, video: liked_one)
      create(:like, user: other_user, video: unliked_one)

      get "/api/v1/videos", headers: auth_headers(user)

      feed = JSON.parse(response.body).index_by { |v| v["title"] }

      expect(feed["Liked"]).to include("likes_count" => 2, "liked_by_me" => true)
      expect(feed["Not liked"]).to include("likes_count" => 1, "liked_by_me" => false)
    end
  end

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /api/v1/videos" do
    it "requires a login" do
      get "/api/v1/videos"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists only public videos" do
      create(:video, user: other_user, title: "Public one")
      create(:video, :private, user: other_user, title: "Someone's private")
      create(:video, :unlisted, user: other_user, title: "Someone's unlisted")
      create(:video, :private, user: user, title: "My private")

      get "/api/v1/videos", headers: auth_headers(user)

      titles = response.parsed_body.map { |v| v["title"] }
      expect(titles).to eq(["Public one"])
    end

    it "returns the fields the Flutter app expects" do
      create(:video, user: other_user)

      get "/api/v1/videos", headers: auth_headers(user)

      expect(response.parsed_body.first.keys).to include(
        "id", "title", "description", "status", "duration_seconds", "manifest_url", "view_count"
      )
    end
  end

  describe "GET /api/v1/videos/:id" do
    it "shows someone else's public video" do
      video = create(:video, user: other_user)
      get "/api/v1/videos/#{video.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(video.id)
    end

    it "shows my own private video" do
      video = create(:video, :private, user: user)
      get "/api/v1/videos/#{video.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
    end

    it "hides someone else's private video behind a 404" do
      video = create(:video, :private, user: other_user)
      get "/api/v1/videos/#{video.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a video that doesn't exist" do
      get "/api/v1/videos/999999", headers: auth_headers(user)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/videos" do
    before do
      creator = instance_double(MediaConvertJobCreator, call: "job-123")
      allow(MediaConvertJobCreator).to receive(:new).and_return(creator)
    end

    it "creates a video owned by the current user" do
      post "/api/v1/videos",
           params: { video: { title: "My upload", visibility: "public_video" } },
           headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:created)
      expect(user.videos.pluck(:title)).to eq(["My upload"])
    end

    it "starts transcoding when a file is uploaded" do
      post "/api/v1/videos",
           params: { video: { title: "With file", raw_video: fixture_file_upload("sample.mp4", "video/mp4") } },
           headers: auth_headers(user)

      expect(response).to have_http_status(:created)
      expect(Video.last.status).to eq("processing")
    end

    it "rejects a video without a title" do
      post "/api/v1/videos",
           params: { video: { title: "" } },
           headers: auth_headers(user), as: :json

      expect(response).to have_http_status(422)
    end
  end

  describe "PATCH /api/v1/videos/:id" do
    it "lets the owner rename their video" do
      video = create(:video, user: user, title: "Old")

      patch "/api/v1/videos/#{video.id}",
            params: { video: { title: "New" } },
            headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(video.reload.title).to eq("New")
    end

    it "does not let anyone else edit it" do
      video = create(:video, user: other_user, title: "Theirs")

      patch "/api/v1/videos/#{video.id}",
            params: { video: { title: "Hacked" } },
            headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:not_found)
      expect(video.reload.title).to eq("Theirs")
    end
  end
end