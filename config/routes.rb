Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  post "/locale", to: "locales#update", as: :locale

  resources :appointments, only: [ :index, :new, :create, :show, :destroy ] do
    member do
      patch :cancel
    end
  end

  namespace :admin do
    resources :appointments do
      member do
        patch :approve
        patch :deny
        patch :cancel
      end
    end

    resources :clients
    resources :users
  end
end
