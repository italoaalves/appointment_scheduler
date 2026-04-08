# frozen_string_literal: true

require "test_helper"

class ActiveRecordEncryptionConfigTest < ActiveSupport::TestCase
  test "derives fallback keys in production when dummy secret key base mode is enabled" do
    with_env("SECRET_KEY_BASE_DUMMY" => "1") do
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        Rails.application.credentials.stub(:dig, nil) do
          Rails.application.stub(:secret_key_base, "dummy-secret") do
            keys = Security::ActiveRecordEncryptionConfig.send(:resolved_keys)

            assert_equal(
              {
                primary_key: Security::ActiveRecordEncryptionConfig.send(:derive_value, "dummy-secret", "primary_key"),
                deterministic_key: Security::ActiveRecordEncryptionConfig.send(:derive_value, "dummy-secret", "deterministic_key"),
                key_derivation_salt: Security::ActiveRecordEncryptionConfig.send(:derive_value, "dummy-secret", "key_derivation_salt")
              },
              keys
            )
          end
        end
      end
    end
  end

  test "raises in staging when keys are missing" do
    with_env("SECRET_KEY_BASE_DUMMY" => nil) do
      Rails.stub(:env, ActiveSupport::StringInquirer.new("staging")) do
        Rails.application.credentials.stub(:dig, nil) do
          error = assert_raises(ActiveRecord::Encryption::Errors::Configuration) do
            Security::ActiveRecordEncryptionConfig.send(:resolved_keys)
          end

          assert_equal "Missing Active Record encryption keys for staging", error.message
        end
      end
    end
  end

  test "raises in production when keys are missing and dummy secret key base mode is disabled" do
    with_env("SECRET_KEY_BASE_DUMMY" => nil) do
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        Rails.application.credentials.stub(:dig, nil) do
          error = assert_raises(ActiveRecord::Encryption::Errors::Configuration) do
            Security::ActiveRecordEncryptionConfig.send(:resolved_keys)
          end

          assert_equal "Missing Active Record encryption keys for production", error.message
        end
      end
    end
  end

  private

  def with_env(overrides)
    original_values = overrides.keys.to_h { |key| [ key, ENV[key] ] }

    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
