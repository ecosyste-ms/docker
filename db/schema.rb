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

ActiveRecord::Schema[7.0].define(version: 2023_03_20_112534) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "dependencies", force: :cascade do |t|
    t.integer "package_id"
    t.integer "version_id"
    t.string "ecosystem"
    t.string "package_name"
    t.string "requirements"
    t.string "purl"
    t.index ["package_id"], name: "index_dependencies_on_package_id"
    t.index ["package_name"], name: "index_dependencies_on_package_name"
    t.index ["version_id"], name: "index_dependencies_on_version_id"
  end

  create_table "package_usages", force: :cascade do |t|
    t.string "ecosystem"
    t.string "name"
    t.bigint "dependents_count"
    t.bigint "downloads_count"
    t.json "package"
    t.datetime "package_last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ecosystem", "name"], name: "index_package_usages_on_ecosystem_and_name", unique: true
  end

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
