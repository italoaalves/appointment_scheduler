# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/rails"
require "opentelemetry/instrumentation/pg"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/instrumentation/active_job"
require "opentelemetry/instrumentation/action_pack"
require "opentelemetry/instrumentation/active_record"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "appointment-scheduler"
  c.service_version = ENV.fetch("APP_VERSION", "dev")

  c.use "OpenTelemetry::Instrumentation::Rails"
  c.use "OpenTelemetry::Instrumentation::Pg"
  c.use "OpenTelemetry::Instrumentation::Net::HTTP"
  c.use "OpenTelemetry::Instrumentation::ActiveJob"
  c.use "OpenTelemetry::Instrumentation::ActionPack"
  c.use "OpenTelemetry::Instrumentation::ActiveRecord"

  # OTLP exporter reads OTEL_EXPORTER_OTLP_ENDPOINT env var (default: http://localhost:4318)
  # In production, set OTEL_EXPORTER_OTLP_ENDPOINT to point at the OTel Collector.
end
