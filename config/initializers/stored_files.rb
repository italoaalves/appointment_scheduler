# frozen_string_literal: true

require Rails.root.join("app/services/stored_files")
require Rails.root.join("app/services/stored_files/adapters/local")

stored_files_root = if Rails.env.test?
  Rails.root.join("tmp/stored_files")
else
  Rails.root.join("storage/stored_files")
end

StoredFiles.configure(
  default_adapter: :local,
  adapters: {
    local: StoredFiles::Adapters::Local.new(root: stored_files_root)
  },
  scopes: {
    profile_picture: {
      name: :profile_picture,
      adapter: :local,
      allowed_content_types: %w[image/jpeg image/png image/webp],
      max_bytes: 5.megabytes
    },
    space_banner: {
      name: :space_banner,
      adapter: :local,
      allowed_content_types: %w[image/jpeg image/png image/webp],
      max_bytes: 8.megabytes
    }
  }
)
