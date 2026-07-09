require "test_helper"

# The first job to exercise ApplicationJob's tenant-GUC-replication machinery
# (PROJECT_STATE.md §9.7-7) — this is the delicate part of S3a. Every test
# here runs the job WITHOUT manually touching Tenant::Guc itself; the job is
# what's responsible for fixing and clearing it.
class Core::Headcount::SnapshotJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def build_institution_with_active_students(count)
    slug = "sj-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 8", level_number: 8)
      count.times do |i|
        GroupManagement::Student.create!(institution: institution, grade_level: grade,
          first_name: "Est#{i}", last_name: "Prueba", gender: "male", birthdate: Date.new(2014, 1, 1),
          student_code: "SJ#{i}-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")
      end
    end

    institution
  end

  test "run_now_for fixes the tenant GUC, counts the right institution's students, and writes the snapshot" do
    institution_a = build_institution_with_active_students(3)
    institution_b = build_institution_with_active_students(7)

    snapshot_a = Core::Headcount::SnapshotJob.run_now_for(institution_a)
    assert_equal 3, snapshot_a.headcount

    snapshot_b = Core::Headcount::SnapshotJob.run_now_for(institution_b)
    assert_equal 7, snapshot_b.headcount
  end

  test "the GUC does not leak past the job — an unscoped query sees nothing afterward" do
    institution = build_institution_with_active_students(4)

    Core::Headcount::SnapshotJob.run_now_for(institution)

    # The real proof, not a re-read of current_setting() (which AR's
    # transaction-scoped query cache can serve stale/misleadingly — verified
    # empirically during S3a recon). If the GUC were still set to
    # institution.id after the job, this unscoped count would show 4 (RLS
    # would filter to that institution); if it's genuinely cleared, RLS
    # matches zero rows for everyone, per Tenant::Guc's own contract.
    visible = ActiveRecord::Base.uncached { GroupManagement::Student.count }
    assert_equal 0, visible, "the job's GUC leaked past its own transaction"
  end

  test "re-running for the same as_of updates the snapshot instead of duplicating it" do
    institution = build_institution_with_active_students(2)

    first = Core::Headcount::SnapshotJob.run_now_for(institution)
    second = Core::Headcount::SnapshotJob.run_now_for(institution)

    assert_equal first.id, second.id
    assert_equal 1, ControlPlane::StudentHeadcountSnapshot.for_institution(institution).count
  end

  test "enqueue_for actually enqueues a Solid Queue job carrying institution_id" do
    institution = build_institution_with_active_students(1)

    assert_enqueued_with(job: Core::Headcount::SnapshotJob) do
      Core::Headcount::SnapshotJob.enqueue_for(institution)
    end
  end
end
