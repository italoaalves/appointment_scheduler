# frozen_string_literal: true

class AppointmentEvent < ApplicationRecord
  include SpaceScoped

  belongs_to :space
  belongs_to :appointment
  belongs_to :actor, polymorphic: true, optional: true

  validates :event_type, :idempotency_key, :actor_type, presence: true

  def readonly? = persisted?
end
