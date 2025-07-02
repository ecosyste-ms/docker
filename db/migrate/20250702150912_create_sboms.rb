class CreateSboms < ActiveRecord::Migration[8.0]
  def change
    create_table :sboms do |t|
      t.references :version, null: false, foreign_key: true, index: { unique: true }
      t.json :data, null: false
      t.string :distro_name
      t.string :syft_version
      t.integer :artifacts_count, default: 0
      
      t.timestamps
    end
    
    add_index :sboms, :syft_version
    add_index :sboms, :created_at
  end
end
