Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  # --- Control plane (super-admin, cross-tenant, above RLS) -----------------
  # Its own namespace, mounted at /control_plane. NOT a tenant domain: no RLS
  # scoping applies. Controllers live in app/control_plane/control_plane/ and
  # resolve to ControlPlane::*Controller. Auth guard + audited BYPASSRLS role
  # are still stubs in this phase (see ControlPlane::BaseController).
  namespace :control_plane do
    root to: "dashboard#show"

    resources :institutions, only: %i[index show]
    resources :addons, only: %i[index]
    resources :entitlements, only: %i[index]   # editor per institution (?institution_id=)
    resources :plans, only: %i[index]
    resource  :usage, only: %i[show], controller: "usage"  # metering (one view)
    resources :invoices, only: %i[index]
    resources :audit_entries, only: %i[index], path: "audit", controller: "audit"
  end
end
