Rails.application.routes.draw do
  devise_for :users
  
  root "appointments#index"

  resources :appointments, only: [:index, :new, :create, :show]

  namespace :admin do
    resources :appointments, only: [:index, :update]
  end

  resources :notifications, only: [:index, :update]
end
