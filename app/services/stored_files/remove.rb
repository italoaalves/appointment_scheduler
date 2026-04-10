# frozen_string_literal: true

module StoredFiles
  class Remove
    Result = Struct.new(:success?, :stored_file, :error, keyword_init: true)

    def self.call(record:, scope:)
      new(record:, scope:).call
    end

    def initialize(record:, scope:)
      @record = record
      @scope = scope.to_s
    end

    def call
      stored_file = @record.stored_files.find_by(scope: @scope)
      return Result.new(success?: true) unless stored_file

      storage = StoredFiles.storage_by_name(stored_file.storage_adapter)
      path = stored_file.storage_path
      stored_file.destroy!
      storage.delete(key: path)

      Result.new(success?: true, stored_file:)
    rescue StandardError
      @record.errors.add(:base, I18n.t("stored_files.errors.remove_failed", label: I18n.t("stored_files.scopes.#{@scope}")))
      Result.new(success?: false, error: :remove_failed)
    end
  end
end
