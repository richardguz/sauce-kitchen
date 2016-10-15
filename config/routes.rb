Rails.application.routes.draw do  
  root 'basic_pages#home'

  get 'sessions/new'

  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  resources :users

  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  get '/show_playlists', to: 'location_playlists#show'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
