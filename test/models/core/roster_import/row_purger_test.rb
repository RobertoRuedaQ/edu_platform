require "test_helper"

# guidelines/OPEN_PROCESS.md item #2 (onboarding hardening, gated closed
# 2026-07-22): roster_import_rows carries raw PII (jsonb, encrypted via
# Cipher) with zero purge path before this — Core::RosterImportBatch
# #roster_import_rows is dependent: :destroy, but nothing ever destroys a
# batch. RowPurger is the retention sweep; PurgeRowsAllJob (its own test
# file) is the per-institution fan-out that calls it on a schedule.
class Core::RosterImport::RowPurgerTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "rp-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_term(institution)
    Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
  end

  def build_batch_with_rows(institution, status:, committed_at: nil, row_count: 2)
    batch = Core::RosterImportBatch.create!(institution: institution, academic_term: build_term(institution),
      kind: "students", status: status, committed_at: committed_at)
    row_count.times do |i|
      Core::RosterImportRow.create!(institution: institution, roster_import_batch: batch,
        line_number: i + 1, raw: { "national_id" => "enc-#{i}" }, status: "valid")
    end
    batch
  end

  test "deletes rows of a committed batch past the retention window" do
    institution = build_institution

    within_tenant(institution) do
      old_batch = build_batch_with_rows(institution, status: "committed",
        committed_at: Core::RosterImport::RowPurger::RETENTION.ago - 1.day)

      Core::RosterImport::RowPurger.call(institution: institution)

      assert_equal 0, old_batch.roster_import_rows.count
      assert Core::RosterImportBatch.exists?(old_batch.id), "the batch itself is never purged, only its rows"
    end
  end

  test "never purges a committed batch still inside the retention window" do
    institution = build_institution

    within_tenant(institution) do
      recent_batch = build_batch_with_rows(institution, status: "committed", committed_at: 1.day.ago)

      Core::RosterImport::RowPurger.call(institution: institution)

      assert_equal 2, recent_batch.roster_import_rows.count
    end
  end

  test "never purges a non-committed batch, no matter how old" do
    institution = build_institution

    within_tenant(institution) do
      abandoned_batch = build_batch_with_rows(institution, status: "previewed", committed_at: nil)
      # created_at is set at insert time, not overridable via create! — simulate old by touching directly.
      abandoned_batch.update_columns(created_at: 1.year.ago)

      Core::RosterImport::RowPurger.call(institution: institution)

      assert_equal 2, abandoned_batch.roster_import_rows.count
    end
  end

  test "only purges the given institution's own rows" do
    institution_a = build_institution
    institution_b = build_institution

    batch_a = within_tenant(institution_a) do
      build_batch_with_rows(institution_a, status: "committed", committed_at: 1.year.ago)
    end
    batch_b = within_tenant(institution_b) do
      build_batch_with_rows(institution_b, status: "committed", committed_at: 1.year.ago)
    end

    within_tenant(institution_a) { Core::RosterImport::RowPurger.call(institution: institution_a) }

    within_tenant(institution_a) { assert_equal 0, batch_a.roster_import_rows.count }
    within_tenant(institution_b) { assert_equal 2, batch_b.roster_import_rows.count }
  end
end
