class RemoveSbomColumnFromVersions < ActiveRecord::Migration[8.0]
  def change
    remove_column :versions, :sbom, :jsonb
  end
end
