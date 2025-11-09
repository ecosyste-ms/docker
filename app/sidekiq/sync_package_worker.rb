class SyncPackageWorker
  include Sidekiq::Worker
  sidekiq_options lock: :until_executed, lock_expiration: 10.minutes.to_i

  def perform(package_id)
    Package.find_by_id(package_id).try(:sync)
  end
end