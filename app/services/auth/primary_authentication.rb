# frozen_string_literal: true

module Auth
  class PrimaryAuthentication
    Result = Struct.new(:success?, :user, :error, keyword_init: true)

    def self.call(email:, password:)
      new(email:, password:).call
    end

    def initialize(email:, password:)
      @email = email.to_s.downcase.strip
      @password = password.to_s
    end

    def call
      user = User.find_for_database_authentication(email: @email)
      return Result.new(success?: false, error: :invalid) if user.blank?
      return Result.new(success?: false, error: :invalid) unless user.valid_password?(@password)
      return Result.new(success?: false, user:, error: user.inactive_message) unless user.active_for_authentication?

      Result.new(success?: true, user:)
    end
  end
end
