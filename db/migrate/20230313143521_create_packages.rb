class CreatePackages < ActiveRecord::Migration[7.0]
  def change
    create_table :packages do |t|
      t.string :name
      t.datetime :last_synced_at
      t.integer :versions_count
      t.datetime :latest_release_published_at
      t.string :latest_release_number

      t.timestamps
    end
  end
end
