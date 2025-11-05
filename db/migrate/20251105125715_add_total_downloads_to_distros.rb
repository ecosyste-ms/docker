class AddTotalDownloadsToDistros < ActiveRecord::Migration[8.0]
  def change
    add_column :distros, :total_downloads, :bigint
  end
end
