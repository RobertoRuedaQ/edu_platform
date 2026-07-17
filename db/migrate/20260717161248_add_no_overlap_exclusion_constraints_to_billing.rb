class AddNoOverlapExclusionConstraintsToBilling < ActiveRecord::Migration[8.1]
  def up
    # GiST exclusion constraints need operator classes for plain equality
    # (uuid here) — btree_gist supplies those. Postgres 18 native, no app
    # dependency.
    enable_extension "btree_gist"

    # The existing partial unique indexes (index_subscriptions_one_active_per_institution,
    # index_entitlements_one_active_per_institution_addon) already prevent TWO
    # concurrently ACTIVE rows — but say nothing about a new row's date range
    # overlapping a PAST (ended/revoked) row's range for the same institution,
    # which today the app never checks either. These constraints close that:
    # NO two rows for the same institution (institution+addon for
    # entitlements) may ever claim overlapping calendar time, active or not.
    # ends_on/valid_until NULL (open-ended) becomes 'infinity' so an
    # open-ended row still excludes anything starting after it.
    execute <<~SQL
      ALTER TABLE subscriptions
        ADD CONSTRAINT subscriptions_no_overlapping_periods
        EXCLUDE USING gist (
          institution_id WITH =,
          daterange(starts_on, COALESCE(ends_on, 'infinity'::date), '[)') WITH &&
        );
    SQL

    execute <<~SQL
      ALTER TABLE institution_entitlements
        ADD CONSTRAINT institution_entitlements_no_overlapping_periods
        EXCLUDE USING gist (
          institution_id WITH =,
          addon_id WITH =,
          daterange(valid_from, COALESCE(valid_until, 'infinity'::date), '[)') WITH &&
        );
    SQL
  end

  def down
    execute "ALTER TABLE institution_entitlements DROP CONSTRAINT institution_entitlements_no_overlapping_periods;"
    execute "ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_no_overlapping_periods;"
    disable_extension "btree_gist"
  end
end
