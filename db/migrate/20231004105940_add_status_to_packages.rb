class AddStatusToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :status, :string
  end
end
