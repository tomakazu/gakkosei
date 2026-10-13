require "rails_helper"

RSpec.describe "Auth API", type: :request do
  describe "POST /api/v1/signup" do
    let(:params) { { email: "new@example.com", username: "newbie", password: "password123" } }

    it "creates a user and returns a token" do
      expect {
        post "/api/v1/signup", params: params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["token"]).to be_present
      expect(response.parsed_body.dig("user", "username")).to eq("newbie")
    end

    it "rejects a duplicate email" do
      create(:user, email: "new@example.com")

      post "/api/v1/signup", params: params, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to include("Email has already been taken")
    end

    it "rejects a short password" do
      post "/api/v1/signup", params: params.merge(password: "short"), as: :json
      expect(response).to have_http_status(422)
    end
  end

  describe "POST /api/v1/login" do
    let!(:user) { create(:user, email: "rishabh@example.com", password: "password123") }

    it "returns a token for the right password" do
      post "/api/v1/login", params: { email: "rishabh@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["token"]).to be_present
    end

    it "rejects the wrong password" do
      post "/api/v1/login", params: { email: "rishabh@example.com", password: "wrong-pass" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("Invalid email or password")
    end

    it "rejects an unknown email" do
      post "/api/v1/login", params: { email: "nobody@example.com", password: "password123" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/me" do
    let(:user) { create(:user) }

    it "returns the current user for a valid token" do
      get "/api/v1/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("user", "id")).to eq(user.id)
    end

    it "rejects a request with no token" do
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      expired = JsonWebToken.encode({ user_id: user.id }, 1.minute.ago)
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{expired}" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end