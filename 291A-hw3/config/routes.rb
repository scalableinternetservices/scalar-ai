Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # Health check endpoint (no authentication)
  get "/health", to: "health#index"

  # Authentication endpoints (session-based)
  post "/auth/register", to: "auth#register"
  post "/auth/login", to: "auth#login"
  post "/auth/logout", to: "auth#logout"
  post "/auth/refresh", to: "auth#refresh"
  get "/auth/me", to: "auth#me"

  # Conversations endpoints (JWT authentication)
  resources :conversations, only: [ :index, :show, :create ] do
    # Messages nested under conversations for GET
    resources :messages, only: [ :index ]
  end

  # Messages endpoints (JWT authentication)
  resources :messages, only: [ :create ] do
    member do
      put :read, to: "messages#mark_read"
    end
  end

  # Expert endpoints (JWT authentication)
  get "/expert/queue", to: "expert#queue"
  post "/expert/conversations/:conversation_id/claim", to: "expert#claim"
  post "/expert/conversations/:conversation_id/unclaim", to: "expert#unclaim"
  get "/expert/profile", to: "expert#profile"
  put "/expert/profile", to: "expert#update_profile"
  get "/expert/assignments/history", to: "expert#assignment_history"

  # Updates/Polling endpoints (JWT authentication)
  get "/api/conversations/updates", to: "updates#conversations_updates"
  get "/api/messages/updates", to: "updates#messages_updates"
  get "/api/expert-queue/updates", to: "updates#expert_queue_updates"
end
