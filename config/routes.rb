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

  get '/dependencies', to: 'dependencies#index', as: 'dependencies'
  get '/dependencies/:ecosystem', to: 'dependencies#ecosystem', as: 'ecosystem_dependencies'
  get '/dependencies/:ecosystem/:id', to: 'dependencies#show', constraints: { id: /.*/ }, as: 'dependency'

  resources :packages, only: [:index, :show], constraints: { id: /.*/ }, :defaults => {:format => :html} do
    resources :versions
  end

  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root to: 'packages#index'
end
