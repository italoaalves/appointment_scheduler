class AddBillingPlanReferencesToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_reference :subscriptions, :billing_plan,
                  foreign_key: { to_table: :billing_plans }, null: true
    add_reference :subscriptions, :pending_billing_plan,
                  foreign_key: { to_table: :billing_plans }, null: true
  end
end
