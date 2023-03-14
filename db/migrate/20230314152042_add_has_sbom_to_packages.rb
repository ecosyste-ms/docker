class AddHasSbomToPackages < ActiveRecord::Migration[7.0]
  def change
    add_column :packages, :has_sbom, :boolean, default: false
  end
end
