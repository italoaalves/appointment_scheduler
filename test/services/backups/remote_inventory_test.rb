# frozen_string_literal: true

require "test_helper"

module Backups
  class RemoteInventoryTest < ActiveSupport::TestCase
    class FakeStatus
      def initialize(success)
        @success = success
      end

      def success?
        @success
      end
    end

    class FakeRunner
      attr_reader :commands

      def initialize(stdout:)
        @stdout = stdout
        @commands = []
      end

      def capture3(env, *command)
        @commands << { env:, command: }
        [ @stdout, "", FakeStatus.new(true) ]
      end
    end

    test "lists remote backup objects from r2" do
      runner = FakeRunner.new(
        stdout: {
          "Contents" => [
            { "Key" => "postgres/daily/2026/04/10/two.dump.age", "Size" => 456, "LastModified" => "2026-04-10T03:00:00Z" },
            { "Key" => "postgres/daily/2026/04/09/one.dump.age", "Size" => 123, "LastModified" => "2026-04-09T03:00:00Z" }
          ]
        }.to_json
      )

      entries = RemoteInventory.call(
        configuration: Configuration.new(
          settings: {
            r2_bucket: "anella-db-backups",
            r2_access_key_id: "key",
            r2_secret_access_key: "secret",
            r2_endpoint: "https://example.r2.cloudflarestorage.com",
            aws_cli_bin: "aws",
            object_prefix: "postgres/daily"
          }
        ),
        runner:
      )

      assert_equal 2, entries.length
      assert_equal "postgres/daily/2026/04/10/two.dump.age", entries.first.key
      assert_equal "aws", runner.commands.first[:command].first
    end
  end
end
