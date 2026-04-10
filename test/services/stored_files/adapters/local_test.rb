# frozen_string_literal: true

require "test_helper"

module StoredFiles
  module Adapters
    class LocalTest < ActiveSupport::TestCase
      test "stores downloads and deletes files by key" do
        Dir.mktmpdir do |dir|
          adapter = Local.new(root: Pathname.new(dir))
          io = StringIO.new("hello world")

          adapter.store(key: "profile_pictures/user/1/avatar.txt", io:)

          assert_equal "hello world", adapter.download(key: "profile_pictures/user/1/avatar.txt")
          assert adapter.exist?(key: "profile_pictures/user/1/avatar.txt")

          adapter.delete(key: "profile_pictures/user/1/avatar.txt")

          assert_not adapter.exist?(key: "profile_pictures/user/1/avatar.txt")
          assert_nil adapter.download(key: "profile_pictures/user/1/avatar.txt")
        end
      end
    end
  end
end
