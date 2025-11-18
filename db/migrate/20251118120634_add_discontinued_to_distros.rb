class AddDiscontinuedToDistros < ActiveRecord::Migration[8.1]
  def change
    add_column :distros, :discontinued, :boolean, default: false, null: false
  end
end
