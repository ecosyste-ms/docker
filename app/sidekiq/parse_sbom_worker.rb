class ParseSbomWorker
  include Sidekiq::Worker
  sidekiq_options lock: :until_executed, lock_expiration: 20.minutes.to_i

  def perform(version_id)
    Version.find_by_id(version_id).try(:parse_sbom)
  end
end