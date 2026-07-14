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

  # Same GUC contract, exercised via the OTHER kind (guardians) — the job
  # itself is kind-agnostic (Committer dispatches to Strategy.for(batch.kind)),
  # so this is really testing that nothing about Core::User/GuardianStudent
  # writes needs different GUC handling than GroupManagement::Student did.
  GUARDIAN_HEADER = "guardian_national_id,guardian_first_name,guardian_last_name,guardian_email,relationship,student_national_id\n"

  def build_validated_guardians_batch
    slug = "cjg-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    batch = nil
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      GroupManagement::Student.create!(institution: institution, national_id: "CJG-S",
        first_name: "Est", last_name: "Prueba", gender: "male", birthdate: Date.new(2014, 1, 1),
        student_code: "CJG-CODE", entry_year: 2026)
      batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "guardians")

      content = GUARDIAN_HEADER + "CJG-G,Marta,Gómez,marta@correo.test,madre,CJG-S\n"
      Core::RosterImport::Parser.call(batch: batch, content: content)
      Core::RosterImport::Validator.call(batch: batch)
    end

    [ institution, batch ]
  end

  test "run_now_for commits a guardians batch and does not leak the GUC afterward" do
    institution, batch = build_validated_guardians_batch

    Core::RosterImport::CommitJob.run_now_for(batch)

    # Check the leak FIRST, with no intervening GUC-setting code of our own —
    # wrapping a verification block in ITS OWN `Tenant::Guc.set_local` before
    # this point would itself leak (a savepoint's SET LOCAL isn't cleared on
    # release, same gotcha this suite exists to catch in the job), producing
    # a false "leak" that's actually the test's own fault, not the job's.
    visible = ActiveRecord::Base.uncached { Core::GuardianStudent.count }
    assert_equal 0, visible, "the job's GUC leaked past its own transaction"

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      assert_equal "committed", batch.reload.status
      assert_equal 1, Core::GuardianStudent.count
    end
  end
end
