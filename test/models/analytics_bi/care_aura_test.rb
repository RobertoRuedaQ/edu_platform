require "test_helper"

# Slice 3 (BI_DOCUMENT.md §5.7): "Auras de Cuidado" — the clinical-isolation-
# preserving projection. Model/service-level coverage of the projection itself,
# the append-only Projector, the concurrency invariant, AND the clinical
# isolation invariant proven at the MODEL level (not just HTTP): the teacher
# read path never touches any counseling table, and the model has no path to
# one. Exercised directly under the tenant GUC.
class AnalyticsBi::CareAuraTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  setup do
    @institution = Core::Institution.create!(name: "Colegio ca", slug: "ca-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "CA-ANA", entry_year: 2023,
        status: "active", section: @section)
      user = Core::User.create!(email: "counselor-#{SecureRandom.hex(4)}@test", name: "Oriente", password: "password-123456")
      @counselor = @institution.memberships.create!(user: user)
    end
  end

  def publish(kind:, guidance: "Trato con calma.", **kwargs)
    AnalyticsBi::Aura::Projector.call(student: @student, academic_term: @term, aura_kind: kind,
      guidance_text: guidance, authored_by: @counselor, institution: @institution, **kwargs)
  end

  test "the Projector publishes an aura carrying only the abstract projection" do
    within_tenant(@institution) do
      result = publish(kind: "extra_time", guidance: "Dale unos minutos extra.")

      aura = result.aura
      assert aura.persisted?
      assert_equal "extra_time", aura.aura_kind
      assert_equal "Dale unos minutos extra.", aura.guidance_text
      assert_equal @student.id, aura.student_id
      assert_equal @term.id, aura.academic_term_id
      assert_equal @counselor.id, aura.authored_by_counselor_id
      assert aura.active?
      assert_nil result.previous
    end
  end

  test "aura_kind is a closed set (model validation + DB CHECK)" do
    within_tenant(@institution) do
      aura = AnalyticsBi::CareAura.new(institution: @institution, student: @student, academic_term: @term,
        authored_by_counselor: @counselor, aura_kind: "diagnosis_leak", guidance_text: "x", effective_from: Date.current)
      refute aura.valid?
      assert_includes aura.errors[:aura_kind], "is not included in the list"
    end
  end

  test "a student may hold multiple concurrent auras of DIFFERENT kinds" do
    within_tenant(@institution) do
      publish(kind: "extra_time")
      publish(kind: "quiet_space")

      active = AnalyticsBi::CareAura.where(institution_id: @institution.id, student_id: @student.id).active
      assert_equal %w[extra_time quiet_space].sort, active.pluck(:aura_kind).sort
    end
  end

  test "two ACTIVE auras of the SAME kind are forbidden at the DB (partial unique index)" do
    within_tenant(@institution) do
      publish(kind: "extra_time")
      assert_raises(ActiveRecord::RecordNotUnique) do
        # Bypass the Projector (which would close+reopen) to hit the raw index.
        AnalyticsBi::CareAura.create!(institution: @institution, student: @student, academic_term: @term,
          authored_by_counselor: @counselor, aura_kind: "extra_time", guidance_text: "dup", effective_from: Date.current)
      end
    end
  end

  test "republishing a kind is append-only: closes the old, opens the new" do
    within_tenant(@institution) do
      first = publish(kind: "extra_time", guidance: "v1").aura
      result = publish(kind: "extra_time", guidance: "v2")

      first.reload
      refute first.active?, "the old projection is closed"
      assert_equal Date.current, first.effective_until
      assert_equal first.id, result.previous.id
      assert result.aura.active?
      assert_equal "v2", result.aura.guidance_text

      active = AnalyticsBi::CareAura.where(institution_id: @institution.id, student_id: @student.id,
        aura_kind: "extra_time").active
      assert_equal 1, active.count
    end
  end

  test "retire closes an active aura and is idempotent" do
    within_tenant(@institution) do
      aura = publish(kind: "quiet_space").aura
      AnalyticsBi::Aura::Projector.retire(aura: aura)
      assert_equal Date.current, aura.reload.effective_until

      # Idempotent: retiring an already-closed aura does not move the date.
      AnalyticsBi::Aura::Projector.retire(aura: aura)
      assert_equal Date.current, aura.reload.effective_until
    end
  end

  test "group_id delegates to the student's section so a :group grant covers the aura" do
    within_tenant(@institution) do
      aura = publish(kind: "extra_time").aura
      assert_equal @section.id, aura.group_id
    end
  end

  # --- CLINICAL ISOLATION (the crux, proven at the MODEL level) --------------

  test "CareAura has NO association reaching any counseling model" do
    counseling_targets = AnalyticsBi::CareAura.reflect_on_all_associations.map { |a| a.class_name.to_s }
    assert counseling_targets.none? { |name| name.start_with?("Counseling::") },
      "care_aura must not associate to counseling: #{counseling_targets.inspect}"
  end

  test "the teacher read path never queries any counseling table (Case/SessionNote/Referral)" do
    within_tenant(@institution) do
      layout = GroupManagement::ClassroomReconfigurer.call(section: @section, academic_term: @term,
        rows: 2, cols: 2, institution: @institution).layout
      GroupManagement::SeatAssigner.call(layout: layout, student: @student, row: 0, col: 0, institution: @institution)
      publish(kind: "extra_time", guidance: "Guía visible al docente.")

      queries = capture_sql do
        classroom = AnalyticsBi::Lens::SpatialClassroom.for(section: @section, institution: @institution, with_auras: true)
        # Force full materialization the way the SVG helper would.
        classroom.seats.each { |seat| seat.auras.each { |aura| [ aura.kind, aura.guidance ] } }
      end

      offenders = queries.select { |sql| sql.match?(/counseling_cases|session_notes|referrals/) }
      assert offenders.empty?, "teacher read touched counseling tables: #{offenders.inspect}"
      # Sanity: it DID read the projection table, so the tap is actually working.
      assert queries.any? { |sql| sql.include?("care_auras") }, "expected the care_auras projection to be read"
    end
  end

  test "the teacher-side AuraScope returns ONLY the 4-field projection, never the AR model" do
    within_tenant(@institution) do
      publish(kind: "extra_time", guidance: "Solo esto.")
      by_student = AnalyticsBi::Lens::AuraScope.new(student_ids: [ @student.id ], institution: @institution).by_student

      aura = by_student.fetch(@student.id).first
      assert_instance_of AnalyticsBi::Lens::AuraScope::Aura, aura
      assert_equal %i[kind guidance effective_from effective_until].sort, aura.to_h.keys.sort
      assert_equal "extra_time", aura.kind
      assert_equal "Solo esto.", aura.guidance
    end
  end

  private

  def capture_sql
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].start_with?("BEGIN", "COMMIT", "SAVEPOINT", "RELEASE")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
