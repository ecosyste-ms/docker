class ParseSbomWorker
  include Sidekiq::Worker

  def perform(version_id)
    Version.find_by_id(version_id).try(:parse_sbom)
  end
end