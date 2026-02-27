Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, controllers: { registrations: "users/registrations" }
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

  scope module: "spaces" do
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
    resources :users, path: "team"
  end

  get "onboarding", to: "onboarding/wizard#show", as: :onboarding

  scope path: "settings", module: "spaces", as: "settings" do
    resource :space, only: [ :edit, :update ], controller: "space" do
      resource :availability, only: [ :edit, :update ], controller: "space/availabilities"
      resource :policies, only: [ :edit, :update ], controller: "space/policies"
    end
    resource :billing, only: [ :show, :edit, :update ], controller: "billing" do
      member do
        patch :cancel
        patch :resubscribe
        get   :checkout
        post  :subscribe
      end
    end
    resource :credits, only: [ :show, :create ], controller: "credits"
  end

  namespace :billing do
    resources :webhooks, only: [ :create ]
  end

  namespace :platform do
    root to: "dashboard#index", as: :root

    post "impersonation/stop", to: "impersonations#stop", as: :stop_impersonation

    resources :billing, only: [ :index ], controller: "billing"
    resources :spaces do
      resources :appointments, only: [ :index, :show ], controller: "space_appointments"
      resources :customers, only: [ :index, :show ], controller: "space_customers"
      resources :scheduling_links, only: [ :index, :show ], controller: "space_scheduling_links"
      resource :subscription_override, only: [ :edit, :update ], controller: "space_subscription_overrides"
    end
    resources :users do
      member do
        post :impersonate
      end
    end
  end
end
