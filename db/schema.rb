# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_03_15_150339) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "packages", force: :cascade do |t|
    t.string "name"
    t.datetime "last_synced_at"
    t.integer "versions_count"
    t.datetime "latest_release_published_at"
    t.string "latest_release_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_sbom", default: false
    t.integer "dependencies_count"
    t.string "description"
    t.bigint "downloads"
    t.string "repository_url"
  end

  create_table "versions", force: :cascade do |t|
    t.integer "package_id"
    t.string "number"
    t.datetime "published_at"
    t.datetime "last_synced_at"
    t.json "sbom"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
