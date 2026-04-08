# frozen_string_literal: true

require Rails.root.join("lib/security/active_record_encryption_config")

Security::ActiveRecordEncryptionConfig.configure!
