namespace :packages do
  desc "Sync popular packages"
  task sync_popular: :environment do
    Package.sync_popular
  end
end