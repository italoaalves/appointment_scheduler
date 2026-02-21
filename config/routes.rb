Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  resources :appointments, only: [:index, :new, :create, :show, :destroy]

  namespace :admin do
    resources :appointments do
      member do
        patch :approve
        patch :deny
      end
    end

    resources :users
  end
end