# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/rails"
require "opentelemetry/instrumentation/pg"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/instrumentation/active_job"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/active_record"
require Rails.root.join("lib/observability/pii_span_scrubber")
require Rails.root.join("lib/observability/runtime_context")

OpenTelemetry::SDK.configure do |c|
  c.service_name = Observability::RuntimeContext.service_name
  c.service_version = Observability::RuntimeContext.app_version
  c.resource = OpenTelemetry::SDK::Resources::Resource.create(
    Observability::RuntimeContext.resource_attributes
  )
  c.add_span_processor Observability::PiiSpanScrubber.new

  c.use "OpenTelemetry::Instrumentation::Rails"
  c.use "OpenTelemetry::Instrumentation::PG"
  c.use "OpenTelemetry::Instrumentation::Net::HTTP"
  c.use "OpenTelemetry::Instrumentation::ActiveJob"
  c.use "OpenTelemetry::Instrumentation::ActionPack"
  c.use "OpenTelemetry::Instrumentation::ActiveRecord"

  # OTLP exporter reads OTEL_EXPORTER_OTLP_ENDPOINT env var (default: http://localhost:4318)
  # In production, set OTEL_EXPORTER_OTLP_ENDPOINT to point at the OTel Collector.
end
