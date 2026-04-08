Rails.application.routes.draw do
  # Health checks — liveness (lightweight) and readiness (deep dependency check)
  get "up" => "health#show", as: :rails_health_check
  get "up/ready" => "health#ready", as: :health_ready

  devise_for :users, controllers: { registrations: "users/registrations" }
  get "privacy-policy", to: "legal#privacy_policy", as: :privacy_policy
  get "terms-of-service", to: "legal#terms_of_service", as: :terms_of_service
  root "landing#index"
  get "dashboard", to: "dashboard#index", as: :dashboard

  patch "dashboard/dismiss_welcome", to: "dashboard#dismiss_welcome", as: :dismiss_dashboard_welcome

  resource :profile, only: [ :edit, :update ], controller: "profiles" do
    post :request_data_export
    post :request_deletion
    delete :cancel_deletion_request
  end
  resource :preferences, only: [ :edit, :update ], controller: "preferences"

  get "booking/calendar/:token", to: "booking#calendar_ics", as: :booking_calendar_ics

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

    resources :notifications, only: [ :index ] do
      member do
        patch :mark_as_read
        patch :dismiss
      end
      collection do
        patch :mark_all_as_read
      end
    end
  end

  get "onboarding", to: redirect("/onboarding/wizard"), as: :onboarding

  namespace :onboarding do
    resource :wizard, only: [ :show ], controller: "wizard" do
      patch :update_step1
      patch :update_step2
      patch :update_step3
      post  :skip
    end
  end

  scope module: "spaces", as: "spaces" do
    resources :inbox, only: [ :index, :show, :update ], controller: "conversations" do
      member do
        post :reply
        post :reopen_with_template
        patch :assign
        patch :resolve
        patch :reopen
      end
    end
  end

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
    resource :credits, only: [ :show, :create ], controller: "credits" do
      get :checkout, on: :collection
      get :payment,  on: :collection
      get :status,   on: :collection
    end
    resource :whatsapp, only: [ :show ], controller: "whatsapp_settings" do
      post :connect, on: :member
      delete :disconnect, on: :member
    end
  end

  namespace :billing do
    resources :webhooks, only: [ :create ]
  end

  get  "whatsapp/webhooks", to: "whatsapp/webhooks#verify"
  post "whatsapp/webhooks", to: "whatsapp/webhooks#receive"

  namespace :platform do
    root to: "dashboard#index", as: :root

    post "impersonation/stop", to: "impersonations#stop", as: :stop_impersonation

    resources :billing, only: [ :index ], controller: "billing"
    resources :audit_logs, only: [ :index ]
    resources :plans, except: :destroy
    resources :credit_bundles, except: :destroy
    resources :integrations, only: :index do
      post :whatsapp_check, on: :collection
      post :whatsapp_test, on: :collection
    end
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
