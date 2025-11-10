class AddLastSyncedErrorToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :last_synced_error, :text
  end
end
