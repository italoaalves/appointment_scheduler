# frozen_string_literal: true

module StoredFiles
  PreparedUpload = Struct.new(
    :original_filename,
    :content_type,
    :byte_size,
    :checksum,
    :extension,
    :io,
    keyword_init: true
  )
  ScopeConfig = Struct.new(
    :name,
    :adapter,
    :allowed_content_types,
    :max_bytes,
    keyword_init: true
  )

  class << self
    def configure(default_adapter:, adapters:, scopes:)
      @default_adapter = default_adapter.to_s
      @adapters = adapters.transform_keys(&:to_s).freeze
      @scopes = scopes.transform_keys(&:to_s).transform_values { |config| normalize_scope_config(config) }.freeze
    end

    def scope_config(scope)
      @scopes.fetch(scope.to_s)
    end

    def storage_for(scope_or_config)
      storage_by_name(adapter_name_for(scope_or_config))
    end

    def storage_by_name(name)
      @adapters.fetch(name.to_s)
    end

    def adapter_name_for(scope_or_config)
      config = scope_or_config.is_a?(ScopeConfig) ? scope_or_config : scope_config(scope_or_config)
      config.adapter.presence || @default_adapter
    end

    private

    def normalize_scope_config(config)
      return config if config.is_a?(ScopeConfig)

      ScopeConfig.new(
        name: config.fetch(:name).to_s,
        adapter: config[:adapter].to_s,
        allowed_content_types: Array(config.fetch(:allowed_content_types)).map(&:to_s).freeze,
        max_bytes: config.fetch(:max_bytes).to_i
      )
    end
  end
end
