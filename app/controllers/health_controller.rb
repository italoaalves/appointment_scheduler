# frozen_string_literal: true

class HealthController < ActionController::API
  # Lightweight liveness probe — confirms the process is up.
  # GET /up
  def show
    head :ok
  end

  # Deep readiness probe — confirms all dependencies are reachable.
  # GET /up/ready
  def ready
    checks = {
      database: check_database,
      cache: check_cache,
      queue: check_queue
    }

    status = checks.values.all? { |c| c[:status] == "ok" } ? :ok : :service_unavailable

    render json: { status: status == :ok ? "ok" : "degraded", checks: checks }, status: status
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue StandardError => e
    { status: "error", message: e.message }
  end

  def check_cache
    Rails.cache.write("health_check", "ok", expires_in: 10.seconds)
    value = Rails.cache.read("health_check")
    value == "ok" ? { status: "ok" } : { status: "error", message: "cache read mismatch" }
  rescue StandardError => e
    { status: "error", message: e.message }
  end

  def check_queue
    # Verify the queue DB connection is alive (Solid Queue uses a separate database)
    SolidQueue::Job.connection.execute("SELECT 1")
    { status: "ok" }
  rescue StandardError => e
    { status: "error", message: e.message }
  end
end
