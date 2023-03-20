json.extract! version, :number, :published_at, :last_synced_at, :created_at, :updated_at
json.dependencies version.dependencies, partial: 'api/v1/dependencies/dependency', as: :dependency