class AddIdLikeToDistros < ActiveRecord::Migration[8.0]
  def change
    add_column :distros, :id_like, :string
    add_index :distros, :id_like
  end
end
