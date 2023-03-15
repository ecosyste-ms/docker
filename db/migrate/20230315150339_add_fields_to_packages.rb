class AddFieldsToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :description, :string
    add_column :packages, :downloads, :bigint
    add_column :packages, :repository_url, :string
  end
end
