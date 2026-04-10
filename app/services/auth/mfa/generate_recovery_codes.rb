# frozen_string_literal: true

module Auth
  module Mfa
    class GenerateRecoveryCodes
      CODE_COUNT = 10

      def self.call(user:)
        new(user:).call
      end

      def initialize(user:)
        @user = user
      end

      def call
        codes = Array.new(CODE_COUNT) { formatted_code }

        UserRecoveryCode.transaction do
          @user.user_recovery_codes.delete_all
          codes.each do |code|
            @user.user_recovery_codes.create!(code_digest: digest(code))
          end
        end

        codes
      end

      private

      def formatted_code
        raw = SecureRandom.alphanumeric(10).upcase
        "#{raw[0, 5]}-#{raw[5, 5]}"
      end

      def digest(code)
        Devise::Encryptor.digest(User, normalize(code))
      end

      def normalize(code)
        code.to_s.gsub(/[^A-Za-z0-9]/, "").downcase
      end
    end
  end
end
