# frozen_string_literal: true

module Legal
  class DocumentCatalog
    Document = Struct.new(:key, :version, :published_at, keyword_init: true)

    DOCUMENTS = {
      privacy_policy: Document.new(
        key: :privacy_policy,
        version: "1.0",
        published_at: Time.zone.parse("2026-04-07 00:00:00")
      ),
      terms_of_service: Document.new(
        key: :terms_of_service,
        version: "1.0",
        published_at: Time.zone.parse("2026-04-07 00:00:00")
      )
    }.freeze

    def self.fetch(key)
      DOCUMENTS.fetch(key.to_sym)
    end
  end
end
