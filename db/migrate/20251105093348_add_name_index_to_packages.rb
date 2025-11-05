class AddNameIndexToPackages < ActiveRecord::Migration[8.0]
  def change
    add_index :packages, :name, unique: true
  end
end
