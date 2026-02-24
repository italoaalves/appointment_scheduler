Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  resource :profile, only: [ :edit, :update ], controller: "profiles"
  resource :preferences, only: [ :edit, :update ], controller: "preferences"

  get "book/s/:slug", to: "booking#show", as: :book_by_slug, slug: /[a-z0-9-]+/
  get "book/s/:slug/thank-you", to: "booking#thank_you", as: :thank_you_book_by_slug, slug: /[a-z0-9-]+/
  get "book/s/:slug/slots", to: "booking#slots", as: :book_slots_by_slug, slug: /[a-z0-9-]+/
  post "book/s/:slug", to: "booking#create", slug: /[a-z0-9-]+/

  get "book/:token", to: "booking#show", as: :book
  get "book/:token/thank-you", to: "booking#thank_you", as: :thank_you_book
  get "book/:token/slots", to: "booking#slots", as: :book_slots
  post "book/:token", to: "booking#create"

  resources :appointments, only: [ :index, :new, :create, :show, :destroy ] do
    member do
      patch :cancel
    end
  end

  namespace :admin do
    resource :space, only: [ :edit, :update ], controller: "space" do
      resource :availability, only: [ :edit, :update ], controller: "space/availabilities"
    end

    resources :appointments do
      collection do
        get :pending
      end
      member do
        patch :confirm
        patch :cancel
        patch :no_show
        get :finish_form
        patch :finish
      end
    end

    resources :customers
    resources :scheduling_links
    resource :personalized_scheduling_link, only: [ :new, :create, :edit, :update, :destroy ], path: "personalized_link"
    resources :users
  end

  namespace :platform do
    resources :spaces do
      resources :appointments, only: [ :index, :show ], controller: "space_appointments"
      resources :customers, only: [ :index, :show ], controller: "space_customers"
      resources :scheduling_links, only: [ :index, :show ], controller: "space_scheduling_links"
    end
    resources :users
  end
end
