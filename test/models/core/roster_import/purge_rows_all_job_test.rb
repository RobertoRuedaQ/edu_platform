require "test_helper"

# Recurring fan-out (config/recurring.yml), molde IdentityAccess::
# Invitations::ExpireAllJob — roster_import_rows is tenant-scoped/RLS, so the
# job manages its own per-institution loop + GUC (RowPurger.call is cheap
# enough not to need its own queued job per institution).
class Core::RosterImport::PurgeRowsAllJobTest < ActiveSupport::TestCase
  def build_batch_with_old_committed_rows(row_count: 2)
    slug = "prj-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    batch = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students",
        status: "committed", committed_at: Core::RosterImport::RowPurger::RETENTION.ago - 1.day)
      row_count.times do |i|
        Core::RosterImportRow.create!(institution: institution, roster_import_batch: batch,
          line_number: i + 1, raw: { "national_id" => "enc-#{i}" }, status: "valid")
      end
    end

    [ institution, batch ]
  end

  test "sweeps every institution's old committed rows under its own GUC" do
    institution_a, batch_a = build_batch_with_old_committed_rows
    institution_b, batch_b = build_batch_with_old_committed_rows

    Core::RosterImport::PurgeRowsAllJob.perform_now

    # Check the leak FIRST, with no intervening GUC-setting code of our own —
    # same gotcha CommitJobTest exists to catch (a savepoint's SET LOCAL isn't
    # cleared on release).
    visible = ActiveRecord::Base.uncached { Core::RosterImportRow.count }
    assert_equal 0, visible, "the job's GUC leaked past its own loop"

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution_a.id)
      assert_equal 0, batch_a.roster_import_rows.count
    end
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution_b.id)
      assert_equal 0, batch_b.roster_import_rows.count
    end
  end

  test "leaves recent committed rows and non-committed rows alone" do
    institution, _old_batch = build_batch_with_old_committed_rows

    recent_batch = nil
    abandoned_batch = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      term = Core::AcademicTerm.find_by!(institution: institution)
      recent_batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term,
        kind: "students", status: "committed", committed_at: 1.day.ago)
      Core::RosterImportRow.create!(institution: institution, roster_import_batch: recent_batch,
        line_number: 1, raw: { "national_id" => "enc-recent" }, status: "valid")

      abandoned_batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term,
        kind: "students", status: "previewed")
      Core::RosterImportRow.create!(institution: institution, roster_import_batch: abandoned_batch,
        line_number: 1, raw: { "national_id" => "enc-abandoned" }, status: "valid")
    end

    Core::RosterImport::PurgeRowsAllJob.perform_now

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      assert_equal 1, recent_batch.roster_import_rows.count
      assert_equal 1, abandoned_batch.roster_import_rows.count
    end
  end
end
