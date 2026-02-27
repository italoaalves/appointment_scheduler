# frozen_string_literal: true

class AddPendingPlanIdToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :pending_plan_id, :string
  end
end
