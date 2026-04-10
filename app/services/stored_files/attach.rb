# frozen_string_literal: true

module StoredFiles
  class Attach
    Result = Struct.new(:success?, :stored_file, :error, keyword_init: true)

    def self.call(record:, scope:, prepared_upload:, storage: StoredFiles.storage_for(scope), scope_config: StoredFiles.scope_config(scope))
      new(record:, scope:, prepared_upload:, storage:, scope_config:).call
    end

    def initialize(record:, scope:, prepared_upload:, storage:, scope_config:)
      @record = record
      @scope = scope_config.name
      @prepared_upload = prepared_upload
      @storage = storage
      @scope_config = scope_config
    end

    def call
      return Result.new(success?: true, stored_file: @record.stored_files.find_by(scope: @scope)) if @prepared_upload.blank?

      key = build_key
      @storage.store(key:, io: @prepared_upload.io)

      stored_file = nil
      previous_path = nil
      previous_adapter = nil

      StoredFile.transaction do
        stored_file = @record.stored_files.find_or_initialize_by(scope: @scope)
        if stored_file.persisted? && stored_file.storage_path != key
          previous_path = stored_file.storage_path
          previous_adapter = stored_file.storage_adapter
        end

        stored_file.assign_attributes(
          storage_adapter: StoredFiles.adapter_name_for(@scope_config),
          storage_path: key,
          original_filename: @prepared_upload.original_filename,
          content_type: @prepared_upload.content_type,
          byte_size: @prepared_upload.byte_size,
          checksum: @prepared_upload.checksum
        )
        stored_file.save!
      end

      purge_previous_file(previous_path, previous_adapter)
      Result.new(success?: true, stored_file:)
    rescue ActiveRecord::RecordInvalid
      cleanup(key)
      Result.new(success?: false, error: :invalid_record)
    rescue StandardError
      cleanup(key)
      @record.errors.add(:base, I18n.t("stored_files.errors.upload_failed", label: I18n.t("stored_files.scopes.#{@scope}")))
      Result.new(success?: false, error: :upload_failed)
    end

    private

    def build_key
      [
        @scope.pluralize,
        @record.class.model_name.singular,
        @record.id,
        "#{SecureRandom.uuid}#{@prepared_upload.extension}"
      ].join("/")
    end

    def purge_previous_file(path, adapter_name)
      return if path.blank?

      StoredFiles.storage_by_name(adapter_name).delete(key: path)
    rescue StandardError => error
      Rails.logger.warn("[StoredFiles::Attach] failed to purge previous file #{path}: #{error.class} #{error.message}")
    end

    def cleanup(key)
      return if key.blank?

      @storage.delete(key:)
    end
  end
end
