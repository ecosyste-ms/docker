class CreateDependencies < ActiveRecord::Migration[7.0]
  def change
    create_table :dependencies do |t|
      t.integer :package_id
      t.integer :version_id
      t.string :ecosystem
      t.string :package_name
      t.string :requirements
      t.string :purl
    end

    add_index :dependencies, :package_id
    add_index :dependencies, :version_id
    add_index :dependencies, :package_name
  end
end
