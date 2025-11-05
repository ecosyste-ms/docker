class CreateEcosystems < ActiveRecord::Migration[8.0]
  def change
    create_table :ecosystems do |t|
      t.string :name
      t.integer :packages_count
      t.bigint :total_downloads

      t.timestamps
    end
    add_index :ecosystems, :name, unique: true
  end
end
