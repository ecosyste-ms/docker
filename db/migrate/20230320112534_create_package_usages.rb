class CreatePackageUsages < ActiveRecord::Migration[7.0]
  def change
    create_table :package_usages do |t|
      t.string :ecosystem
      t.string :name
      t.bigint :dependents_count
      t.bigint :downloads_count
      t.json :package
      t.datetime :package_last_synced_at

      t.timestamps
    end

    add_index :package_usages, [:ecosystem, :name], unique: true
  end
end
