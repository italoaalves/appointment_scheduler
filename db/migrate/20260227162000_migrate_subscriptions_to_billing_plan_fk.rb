class MigrateSubscriptionsToBillingPlanFk < ActiveRecord::Migration[8.0]
  def up
    # Populate billing_plan_id from plan_id string.
    # "starter" was renamed to "essential" in the new plan structure — handle both slugs.
    execute <<~SQL
      UPDATE subscriptions
      SET billing_plan_id = bp.id
      FROM billing_plans bp
      WHERE subscriptions.plan_id = bp.slug
         OR (subscriptions.plan_id = 'starter' AND bp.slug = 'essential')
    SQL

    # Populate pending_billing_plan_id where set
    execute <<~SQL
      UPDATE subscriptions
      SET pending_billing_plan_id = bp.id
      FROM billing_plans bp
      WHERE subscriptions.pending_plan_id IS NOT NULL
        AND (subscriptions.pending_plan_id = bp.slug
          OR (subscriptions.pending_plan_id = 'starter' AND bp.slug = 'essential'))
    SQL

    change_column_null :subscriptions, :billing_plan_id, false

    remove_column :subscriptions, :plan_id,         :string
    remove_column :subscriptions, :pending_plan_id, :string
  end

  def down
    add_column :subscriptions, :plan_id,         :string
    add_column :subscriptions, :pending_plan_id, :string

    execute <<~SQL
      UPDATE subscriptions s
      SET plan_id = bp.slug
      FROM billing_plans bp
      WHERE s.billing_plan_id = bp.id
    SQL

    execute <<~SQL
      UPDATE subscriptions s
      SET pending_plan_id = bp.slug
      FROM billing_plans bp
      WHERE s.pending_billing_plan_id = bp.id
    SQL

    change_column_null :subscriptions, :billing_plan_id, true
  end
end
