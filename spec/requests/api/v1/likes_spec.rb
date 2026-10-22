require "rails_helper"

RSpec.describe "Api::V1::Likes", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:video)   { create(:video, user: other) }
  let(:headers) { auth_headers(user) }

  def json
    JSON.parse(response.body)
  end

  describe "POST /api/v1/videos/:video_id/like" do
    it "likes the video" do
      post "/api/v1/videos/#{video.id}/like", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to eq("liked" => true, "likes_count" => 1)
    end

    it "is idempotent: liking twice still means one like" do
      post "/api/v1/videos/#{video.id}/like", headers: headers

      expect {
        post "/api/v1/videos/#{video.id}/like", headers: headers
      }.not_to change(Like, :count)

      expect(response).to have_http_status(:ok)
      expect(json).to eq("liked" => true, "likes_count" => 1)
    end

    it "returns 404 for someone else's private video, and creates nothing" do
      secret = create(:video, :private, user: other)

      expect {
        post "/api/v1/videos/#{secret.id}/like", headers: headers
      }.not_to change(Like, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "lets you like your own private video" do
      mine = create(:video, :private, user: user)

      post "/api/v1/videos/#{mine.id}/like", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["liked"]).to eq(true)
    end

    it "returns 404 for a video that doesn't exist" do
      post "/api/v1/videos/999999/like", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      post "/api/v1/videos/#{video.id}/like"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/videos/:video_id/like" do
    it "unlikes a liked video" do
      create(:like, user: user, video: video)

      delete "/api/v1/videos/#{video.id}/like", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to eq("liked" => false, "likes_count" => 0)
    end

    it "is idempotent: unliking a video you never liked is fine" do
      delete "/api/v1/videos/#{video.id}/like", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json).to eq("liked" => false, "likes_count" => 0)
    end

    it "only removes YOUR like, not other people's" do
      create(:like, user: other, video: video)
      create(:like, user: user,  video: video)

      delete "/api/v1/videos/#{video.id}/like", headers: headers

      expect(json).to eq("liked" => false, "likes_count" => 1)
    end
  end
end