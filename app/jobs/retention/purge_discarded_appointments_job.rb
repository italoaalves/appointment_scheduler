# frozen_string_literal: true

module Retention
  class PurgeDiscardedAppointmentsJob < ApplicationJob
    queue_as :default

    def perform
      Retention::DiscardedAppointmentPurger.call
    end
  end
end
