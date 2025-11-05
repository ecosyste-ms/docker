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

ActiveRecord::Schema[8.0].define(version: 2025_11_05_125715) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "dependencies", force: :cascade do |t|
    t.integer "package_id"
    t.integer "version_id"
    t.string "ecosystem"
    t.string "package_name"
    t.string "requirements"
    t.string "purl"
    t.index ["ecosystem", "package_name"], name: "index_dependencies_on_ecosystem_and_package_name"
    t.index ["package_id"], name: "index_dependencies_on_package_id"
    t.index ["package_name"], name: "index_dependencies_on_package_name"
    t.index ["version_id"], name: "index_dependencies_on_version_id"
  end

  create_table "distros", force: :cascade do |t|
    t.string "id_field"
    t.string "name"
    t.string "version_id"
    t.string "pretty_name"
    t.string "version_codename"
    t.string "variant"
    t.string "variant_id"
    t.string "home_url"
    t.string "support_url"
    t.string "bug_report_url"
    t.string "documentation_url"
    t.string "logo"
    t.string "ansi_color"
    t.string "cpe_name"
    t.string "build_id"
    t.string "image_id"
    t.string "image_version"
    t.text "raw_content"
    t.string "slug"
    t.integer "versions_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "id_like"
    t.bigint "total_downloads"
    t.index ["id_field"], name: "index_distros_on_id_field"
    t.index ["id_like"], name: "index_distros_on_id_like"
    t.index ["pretty_name"], name: "index_distros_on_pretty_name"
    t.index ["slug"], name: "index_distros_on_slug", unique: true
    t.index ["versions_count"], name: "index_distros_on_versions_count"
  end

  create_table "ecosystems", force: :cascade do |t|
    t.string "name"
    t.integer "packages_count"
    t.bigint "total_downloads"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_ecosystems_on_name", unique: true
  end

  create_table "exports", force: :cascade do |t|
    t.string "date"
    t.string "bucket_name"
    t.integer "images_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "status"
    t.index ["name"], name: "index_packages_on_name", unique: true
  end

  create_table "sboms", force: :cascade do |t|
    t.bigint "version_id", null: false
    t.json "data", null: false
    t.string "distro_name"
    t.string "syft_version"
    t.integer "artifacts_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sboms_on_created_at"
    t.index ["syft_version"], name: "index_sboms_on_syft_version"
    t.index ["version_id"], name: "index_sboms_on_version_id", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.integer "package_id"
    t.string "number"
    t.datetime "published_at"
    t.datetime "last_synced_at"
    t.json "sbom"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "distro_name"
    t.string "syft_version"
    t.integer "artifacts_count", default: 0
    t.index ["distro_name"], name: "index_versions_on_distro_name"
    t.index ["package_id"], name: "index_versions_on_package_id"
    t.index ["syft_version"], name: "index_versions_on_syft_version"
  end

  add_foreign_key "sboms", "versions"
end
