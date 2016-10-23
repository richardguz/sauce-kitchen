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


  get "/pages/channel" => "basic_pages#show"

  get '/playlists/json/:id', to: 'playlists#poll', as: 'playlist_json'
  get '/playlists/:id/next_song/json', to: 'playlists#next_song', as: 'next_song_json'
  get '/playlists/:id/reset_play_history', to: 'playlists#reset_play_history'
  get '/playlists/:id/upvote/:songid', to: 'playlists#upvote'
  get '/playlists/:pid/add_song/:sid/:title', to: 'playlists#add_song'

end
