class AddUniqueIndexToVersions < ActiveRecord::Migration[8.0]
  def up
    # Disable statement timeout for this long-running index creation
    execute "SET statement_timeout = 0"
    add_index :versions, [:package_id, :number], unique: true
  end

  def down
    remove_index :versions, [:package_id, :number]
  end
end
