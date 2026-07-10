require "test_helper"

# The SECOND job to exercise ApplicationJob's tenant-GUC-replication machinery
# (first was Core::Headcount::SnapshotJob, S3a). Every test here runs the job
# WITHOUT manually touching Tenant::Guc itself — the job is responsible for
# fixing and clearing it, same contract as SnapshotJob.
class Core::RosterImport::CommitJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  def build_validated_batch(row_count)
    slug = "cj-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    batch = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students")

      content = CSV_HEADER + row_count.times.map { |i|
        "CJ#{i}#{SecureRandom.hex(3)},Est#{i},Prueba,male,2014-01-01,CJ-CODE-#{i}-#{SecureRandom.hex(2)},2026,,,\n"
      }.join
      Core::RosterImport::Parser.call(batch: batch, content: content)
      Core::RosterImport::Validator.call(batch: batch)
    end

    [ institution, batch ]
  end

  test "run_now_for fixes the tenant GUC and commits the right institution's batch" do
    institution, batch = build_validated_batch(3)

    Core::RosterImport::CommitJob.run_now_for(batch)

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      assert_equal "committed", batch.reload.status
      assert_equal 3, GroupManagement::Student.count
    end
  end

  test "the GUC does not leak past the job — an unscoped query sees nothing afterward" do
    _institution, batch = build_validated_batch(2)

    Core::RosterImport::CommitJob.run_now_for(batch)

    # The real proof, not a re-read of current_setting() — see
    # Core::Headcount::SnapshotJobTest for why that reads as a false
    # positive/negative under AR's query cache.
    visible = ActiveRecord::Base.uncached { GroupManagement::Student.count }
    assert_equal 0, visible, "the job's GUC leaked past its own transaction"
  end

  test "re-running the job for the same batch does not duplicate students" do
    _institution, batch = build_validated_batch(2)

    Core::RosterImport::CommitJob.run_now_for(batch)
    Core::RosterImport::CommitJob.run_now_for(batch)

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(_institution.id)
      assert_equal 2, GroupManagement::Student.count
    end
  end

  test "enqueue_for actually enqueues a Solid Queue job carrying institution_id" do
    institution, batch = build_validated_batch(1)

    assert_enqueued_with(job: Core::RosterImport::CommitJob) do
      Core::RosterImport::CommitJob.enqueue_for(batch)
    end
  end
end
