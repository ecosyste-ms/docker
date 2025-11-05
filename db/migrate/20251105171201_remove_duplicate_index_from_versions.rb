class RemoveDuplicateIndexFromVersions < ActiveRecord::Migration[8.0]
  def change
    remove_index :versions, :package_id
  end
end
