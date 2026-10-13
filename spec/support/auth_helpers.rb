module AuthHelpers
  # The same header your Flutter app's ApiClient sends
  def auth_headers(user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: user.id)}" }
  end
end