# frozen_string_literal: true

require "test_helper"
require "zip"

module DataExports
  class PackageBuilderTest < ActiveSupport::TestCase
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @manager.create_user_preference!(locale: "pt-BR") unless @manager.user_preference
    end

    test "builds a zip package with account and tenant csvs for manager" do
      package = PackageBuilder.call(user: @manager)
      entries = zip_entries(package.data)

      assert_equal "application/zip", package.content_type
      assert_includes package.filename, "lgpd-export"
      assert_includes entries.keys, "user.csv"
      assert_includes entries.keys, "customers.csv"
      assert_includes entries.keys, "appointments.csv"

      assert_includes entries.fetch("customers.csv"), customers(:one).email
      refute_includes entries.fetch("customers.csv"), customers(:other_space_customer).name
    end

    test "omits tenant-wide csvs for user without manage_space permission" do
      package = PackageBuilder.call(user: @secretary)
      entries = zip_entries(package.data)

      assert_includes entries.keys, "user.csv"
      assert_includes entries.keys, "messages.csv"
      refute_includes entries.keys, "customers.csv"
      refute_includes entries.keys, "payments.csv"
    end

    private

    def zip_entries(body)
      Zip::File.open_buffer(StringIO.new(body)).each_with_object({}) do |entry, entries|
        entries[entry.name] = entry.get_input_stream.read
      end
    end
  end
end
