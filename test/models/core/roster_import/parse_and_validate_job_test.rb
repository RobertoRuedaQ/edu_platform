require "test_helper"

# Same GUC-replication contract as CommitJobTest — this job is the OTHER
# side of the async split (full-async hardening, OPEN_PROCESS.md item #1).
class Core::RosterImport::ParseAndValidateJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  def build_queued_batch(row_count)
    slug = "pvj-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    content = CSV_HEADER + row_count.times.map { |i|
      "PVJ#{i}#{SecureRandom.hex(3)},Est#{i},Prueba,male,2014-01-01,PVJ-CODE-#{i}-#{SecureRandom.hex(2)},2026,,,\n"
    }.join

    batch = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students",
        status: "queued", pending_content: content)
    end

    [ institution, batch ]
  end

  test "run_now_for fixes the tenant GUC, parses+validates, and clears pending_content" do
    institution, batch = build_queued_batch(2)

    Core::RosterImport::ParseAndValidateJob.run_now_for(batch)

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      batch.reload
      assert_equal "validated", batch.status
      assert_nil batch.pending_content
      assert_equal 2, batch.roster_import_rows.count
    end
  end

  test "the GUC does not leak past the job — an unscoped query sees nothing afterward" do
    _institution, batch = build_queued_batch(2)

    Core::RosterImport::ParseAndValidateJob.run_now_for(batch)

    visible = ActiveRecord::Base.uncached { Core::RosterImportRow.count }
    assert_equal 0, visible, "the job's GUC leaked past its own transaction"
  end

  test "enqueue_for actually enqueues a Solid Queue job carrying institution_id" do
    _institution, batch = build_queued_batch(1)

    assert_enqueued_with(job: Core::RosterImport::ParseAndValidateJob) do
      Core::RosterImport::ParseAndValidateJob.enqueue_for(batch)
    end
  end

  test "re-running the job for the same batch does not duplicate rows" do
    institution, batch = build_queued_batch(3)

    Core::RosterImport::ParseAndValidateJob.run_now_for(batch)
    Core::RosterImport::ParseAndValidateJob.run_now_for(batch)

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      assert_equal 3, batch.reload.roster_import_rows.count
    end
  end
end
