class AddDependenciesCountToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :dependencies_count, :integer
  end
end
