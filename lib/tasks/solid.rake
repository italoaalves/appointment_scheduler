# frozen_string_literal: true

namespace :solid do
  desc "Ensure Solid Cache/Queue/Cable tables exist (for single-database deployments)"
  task prepare: :environment do
    connection = ActiveRecord::Base.connection

    # Each entry maps a sentinel table to its schema file.
    # If the sentinel table is missing, the full schema file is loaded —
    # this creates all tables that gem requires in one shot.
    {
      solid_cache_entries: "db/cache_schema.rb",
      solid_queue_jobs:    "db/queue_schema.rb",
      solid_cable_messages: "db/cable_schema.rb"
    }.each do |sentinel_table, schema_file|
      path = Rails.root.join(schema_file)

      unless path.exist?
        puts "  [solid:prepare] #{schema_file} not found, skipping."
        next
      end

      if connection.table_exists?(sentinel_table)
        puts "  [solid:prepare] #{sentinel_table} exists, skipping."
      else
        puts "  [solid:prepare] Creating tables from #{schema_file}..."
        load path
      end
    end
  end
end
