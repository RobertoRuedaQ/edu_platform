require "test_helper"

# Slice 4 (BI_DOCUMENT.md §7): the HpsTermSnapshotJob/HpsTermSnapshotAllJob
# fan-out pair (guardrail v1.32.0 mold, mirrors Core::Headcount::SnapshotJob).
# Every test runs the job WITHOUT manually touching Tenant::Guc — the job's own
# ApplicationJob machinery fixes and clears it.
class AnalyticsBi::HpsTermSnapshotJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def build_institution_with_active_students(count, active_term: true)
    slug = "hj-#{SecureRandom.hex(4)}"
    institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      if active_term
        Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1", status: "active",
          starts_on: Date.new(2026, 1, 15), ends_on: Date.new(2026, 12, 15))
      end
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9°A", academic_year: 2026)
      count.times do |i|
        GroupManagement::Student.create!(institution: institution, grade_level: grade, section: section,
          first_name: "Est#{i}", last_name: "Prueba", gender: "male", birthdate: Date.new(2013, 1, 1),
          student_code: "HJ#{i}-#{SecureRandom.hex(2)}", entry_year: 2026, status: "active")
      end
    end

    institution
  end

  test "run_now_for fixes the tenant GUC, resolves the active term, and snapshots the right institution's students" do
    institution_a = build_institution_with_active_students(3)
    institution_b = build_institution_with_active_students(5)

    snapshots_a = AnalyticsBi::HpsTermSnapshotJob.run_now_for(institution_a)
    assert_equal 3, snapshots_a.size
    snapshots_b = AnalyticsBi::HpsTermSnapshotJob.run_now_for(institution_b)
    assert_equal 5, snapshots_b.size
  end

  test "an institution with no active term is a quiet no-op, never an error" do
    institution = build_institution_with_active_students(2, active_term: false)

    assert_equal [], AnalyticsBi::HpsTermSnapshotJob.run_now_for(institution)
  end

  test "the GUC does not leak past the job — an unscoped query sees nothing afterward" do
    institution = build_institution_with_active_students(2)

    AnalyticsBi::HpsTermSnapshotJob.run_now_for(institution)

    visible = ActiveRecord::Base.uncached { AnalyticsBi::HpsTermSnapshot.count }
    assert_equal 0, visible, "the job's GUC leaked past its own transaction"
  end

  test "the fan-out enqueues one HpsTermSnapshotJob per institution" do
    build_institution_with_active_students(1)
    build_institution_with_active_students(1)

    assert_enqueued_jobs 2, only: AnalyticsBi::HpsTermSnapshotJob do
      AnalyticsBi::HpsTermSnapshotAllJob.perform_now
    end
  end
end
