Rails.application.routes.draw do  
  resources :playlists

  root 'basic_pages#home'

  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  resources :users

  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  get '/show_playlists', to: 'location_playlists#show'

  get '/user/:id/playlists', to: 'playlists#show_user_playlists', as: 'user_playlists'

  get "/pages/:page" => "basic_pages#show"

  mount ActionCable.server => '/cable'
end
