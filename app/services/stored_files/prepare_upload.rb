# frozen_string_literal: true

require "digest"

module StoredFiles
  class PrepareUpload
    Result = Struct.new(:success?, :prepared_upload, :error, keyword_init: true)

    def self.call(scope:, upload:, record: nil, scope_config: StoredFiles.scope_config(scope))
      new(scope:, upload:, record:, scope_config:).call
    end

    def initialize(scope:, upload:, record:, scope_config:)
      @scope = scope_config.name
      @upload = upload
      @record = record
      @scope_config = scope_config
    end

    def call
      return Result.new(success?: true) if @upload.blank?

      content_type = detected_content_type
      unless @scope_config.allowed_content_types.include?(content_type)
        add_error(:invalid_content_type)
        return Result.new(success?: false, error: :invalid_content_type)
      end

      if byte_size > @scope_config.max_bytes
        add_error(:too_large)
        return Result.new(success?: false, error: :too_large)
      end

      Result.new(
        success?: true,
        prepared_upload: PreparedUpload.new(
          original_filename: original_filename,
          content_type:,
          byte_size:,
          checksum:,
          extension: extension_for(content_type),
          io:
        )
      )
    end

    private

    def add_error(type)
      return unless @record

      @record.errors.add(:base, I18n.t("stored_files.errors.#{type}", **error_options))
    end

    def error_options
      options = { label: I18n.t("stored_files.scopes.#{@scope}") }
      options[:max_size] = ActiveSupport::NumberHelper.number_to_human_size(@scope_config.max_bytes) if @scope_config.max_bytes.positive?
      options
    end

    def io
      @io ||= begin
        source = if @upload.respond_to?(:tempfile)
          @upload.tempfile
        elsif @upload.respond_to?(:to_io)
          @upload.to_io
        else
          @upload
        end

        source.rewind if source.respond_to?(:rewind)
        source
      end
    end

    def original_filename
      @upload.original_filename.to_s.presence || "upload#{extension_for(detected_content_type)}"
    end

    def detected_content_type
      @detected_content_type ||= begin
        io.rewind if io.respond_to?(:rewind)
        Marcel::MimeType.for(io, name: @upload.original_filename, declared_type: @upload.content_type.to_s)
      ensure
        io.rewind if io.respond_to?(:rewind)
      end
    end

    def byte_size
      @byte_size ||= if @upload.respond_to?(:size)
        @upload.size.to_i
      else
        io.size
      end
    end

    def checksum
      @checksum ||= begin
        io.rewind if io.respond_to?(:rewind)
        Digest::SHA256.hexdigest(io.read)
      ensure
        io.rewind if io.respond_to?(:rewind)
      end
    end

    def extension_for(content_type)
      case content_type
      when "image/jpeg" then ".jpg"
      when "image/png" then ".png"
      when "image/webp" then ".webp"
      else ""
      end
    end
  end
end
