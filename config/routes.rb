Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  post "/locale", to: "locales#update", as: :locale

  get "book/:token", to: "booking#show", as: :book
  get "book/:token/slots", to: "booking#slots", as: :book_slots
  post "book/:token", to: "booking#create"

  resources :appointments, only: [ :index, :new, :create, :show, :destroy ] do
    member do
      patch :cancel
    end
  end

  namespace :admin do
    resource :space, only: [ :edit, :update ], controller: "space"

    resources :appointments do
      member do
        patch :confirm
        patch :cancel
      end
    end

    resources :clients
    resources :scheduling_links
    resources :users
  end

  namespace :platform do
    resources :spaces
    resources :users
  end
end
