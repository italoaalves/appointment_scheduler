# frozen_string_literal: true

module Auth
  class RecoveryCodesDisplaySession
    KEY = "auth.recovery_codes_display"

    class << self
      def store(session:, user:, codes:)
        session[KEY] = {
          "user_id" => user.id,
          "codes" => Array(codes)
        }
      end

      def codes(session:, user:)
        payload = session[KEY]
        return if payload.blank?
        return clear(session:) if payload["user_id"].to_i != user.id

        Array(payload["codes"]).presence
      end

      def clear(session:)
        session.delete(KEY)
        nil
      end
    end
  end
end
