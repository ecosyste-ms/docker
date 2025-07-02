class AddCachedSbomFieldsToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :distro_name, :string
    add_column :versions, :syft_version, :string
    add_column :versions, :artifacts_count, :integer, default: 0
    
    add_index :versions, :syft_version
    add_index :versions, :distro_name
  end
end
