require 'sidekiq/web'
require 'sidekiq-status/web'

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
end if Rails.env.production?

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/docs'
  mount Rswag::Api::Engine => '/docs'
  
  mount Sidekiq::Web => "/sidekiq"
  mount PgHero::Engine, at: "pghero"

  namespace :api, :defaults => {:format => :json} do
    namespace :v1 do
      resources :packages, constraints: { id: /.*/ }, only: [:index, :show] do 
        resources :versions, only: [:index, :show], constraints: { id: /.*/ }
      end

      get '/usage', to: 'package_usages#index', as: 'package_usages'
      get '/usage/:ecosystem', to: 'package_usages#ecosystem', as: 'ecosystem_package_usages'
      get 'usage/:ecosystem/:name/dependencies', to: 'package_usages#dependencies', as: :package_usage_dependencies, constraints: { name: /.*/ }
      get '/usage/:ecosystem/:id', to: 'package_usages#show', constraints: { id: /.*/ }, as: 'package_usage'
      

    end
  end

  get '/usage', to: 'package_usages#index', as: 'package_usages'
  get '/usage/:ecosystem', to: 'package_usages#ecosystem', as: 'ecosystem_package_usages'
  get '/usage/:ecosystem/:id', to: 'package_usages#show', constraints: { id: /.*/ }, as: 'package_usage'

  resources :packages, only: [:index, :show], constraints: { id: /.*/ }, :defaults => {:format => :html} do
    resources :versions, only: [:index, :show]
  end

  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root to: 'packages#index'
end
