Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "signup", to: "auth#signup"
      post "login", to: "auth#login"
      resources :videos, only: [:create, :show, :index, :update] do
        resource :like, only: [:create, :destroy]
      end
    end
  end
  get "me", to: "auth#me"
end