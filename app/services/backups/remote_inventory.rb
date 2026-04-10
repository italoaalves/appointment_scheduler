# frozen_string_literal: true

require "json"
require "open3"
require "shellwords"

module Backups
  class RemoteInventory
    class Error < StandardError; end
    class ConfigurationError < Error; end

    Entry = Struct.new(:key, :size, :last_modified, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(configuration: Configuration.resolved, runner: Open3, prefix: nil)
      @configuration = configuration
      @runner = runner
      @prefix = prefix.presence || configuration.object_prefix
    end

    def call
      ensure_configuration!

      stdout, stderr, status = @runner.capture3(
        @configuration.aws_environment,
        @configuration.aws_cli_bin,
        "s3api",
        "list-objects-v2",
        "--bucket",
        @configuration.r2_bucket,
        "--prefix",
        @prefix,
        "--endpoint-url",
        @configuration.r2_endpoint,
        "--output",
        "json"
      )

      raise Error, "Command failed: #{stderr.presence || stdout.presence}" unless status.success?

      payload = JSON.parse(stdout.presence || "{}")
      Array(payload["Contents"]).map do |item|
        Entry.new(
          key: item["Key"],
          size: item["Size"],
          last_modified: item["LastModified"]
        )
      end.sort_by(&:key).reverse
    rescue Errno::ENOENT => e
      raise Error, "Command failed: #{e.message}"
    end

    private

    def ensure_configuration!
      return if @configuration.ready_for_remote_storage?

      raise ConfigurationError, "Missing backup configuration: #{@configuration.missing_remote_storage_keys.join(', ')}"
    end
  end
end
