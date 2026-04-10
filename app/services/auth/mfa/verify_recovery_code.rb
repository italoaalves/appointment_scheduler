# frozen_string_literal: true

module Auth
  module Mfa
    class VerifyRecoveryCode
      Result = Struct.new(:success?, :code_record, :error, keyword_init: true)

      def self.call(user:, code:)
        new(user:, code:).call
      end

      def initialize(user:, code:)
        @user = user
        @code = normalize(code)
      end

      def call
        record = @user.user_recovery_codes.active.detect do |recovery_code|
          Devise::Encryptor.compare(User, recovery_code.code_digest, @code)
        end

        return Result.new(success?: false, error: :invalid_code) if record.blank?

        record.update!(used_at: Time.current)
        Result.new(success?: true, code_record: record)
      end

      private

      def normalize(code)
        code.to_s.gsub(/[^A-Za-z0-9]/, "").downcase
      end
    end
  end
end
