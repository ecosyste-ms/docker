class CreateDistros < ActiveRecord::Migration[8.0]
  def change
    create_table :distros do |t|
      t.string :id_field
      t.string :name
      t.string :version_id
      t.string :pretty_name
      t.string :version_codename
      t.string :variant
      t.string :variant_id
      t.string :home_url
      t.string :support_url
      t.string :bug_report_url
      t.string :documentation_url
      t.string :logo
      t.string :ansi_color
      t.string :cpe_name
      t.string :build_id
      t.string :image_id
      t.string :image_version
      t.text :raw_content
      t.string :slug
      t.integer :versions_count, default: 0

      t.timestamps
    end
    add_index :distros, :slug, unique: true
    add_index :distros, :pretty_name
    add_index :distros, :id_field
    add_index :distros, :versions_count
  end
end
