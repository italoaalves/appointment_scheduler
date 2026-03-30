# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Keep original Rails logger for non-request logs
  config.lograge.keep_original_rails_log = false

  # Append request metadata for debugging and tenant tracing
  config.lograge.custom_payload do |controller|
    payload = {
      request_id: controller.request.request_id,
      ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent
    }

    if controller.respond_to?(:current_user, true) && controller.send(:current_user)
      user = controller.send(:current_user)
      payload[:user_id] = user.id
      payload[:space_id] = user.space_id if user.respond_to?(:space_id)
    end

    if controller.respond_to?(:real_current_user, true)
      real_user = controller.send(:real_current_user)
      payload[:impersonated_by] = real_user.id if real_user != controller.send(:current_user)
    end

    payload
  end

  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format]
    {
      params: event.payload[:params]&.except(*exceptions),
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception_object]&.message
    }.compact
  end

  # Silence health checks
  config.lograge.ignore_actions = [ "Rails::HealthController#show" ]
end
