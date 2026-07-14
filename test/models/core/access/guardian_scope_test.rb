require "test_helper"

# The security-critical query object (GS2/GS7): must return EXACTLY the
# caller's own active guardian_students links in the active tenant — no
# revoked links, no other tenant's links, no search surface (GS4).
class Core::Access::GuardianScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "gs-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student!(institution, code:)
    GroupManagement::Student.create!(institution: institution, national_id: "NID-#{SecureRandom.hex(4)}",
      first_name: "Est", last_name: code, gender: "male", birthdate: Date.new(2015, 1, 1),
      student_code: code, entry_year: 2026)
  end

  def link!(institution, guardian:, student:, status: "active")
    Core::GuardianStudent.create!(institution: institution, guardian_user_id: guardian.id,
      student_id: student.id, relationship: "madre", status: status)
  end

  test "returns only the caller's ACTIVE links, excluding revoked ones" do
    institution = build_institution

    within_tenant(institution) do
      guardian = Core::User.create!(email: "g@correo.test", name: "G", national_id: "G-1")
      institution.memberships.create!(user: guardian)
      s1 = build_student!(institution, code: "S1")
      s2 = build_student!(institution, code: "S2")
      link!(institution, guardian: guardian, student: s1, status: "active")
      link!(institution, guardian: guardian, student: s2, status: "revoked")

      result = Core::Access::GuardianScope.for(guardian, institution: institution)

      assert_equal [ s1.id ], result.pluck(:id)
    end
  end

  test "never returns another guardian's children" do
    institution = build_institution

    within_tenant(institution) do
      guardian_a = Core::User.create!(email: "a@correo.test", name: "A", national_id: "GA")
      guardian_b = Core::User.create!(email: "b@correo.test", name: "B", national_id: "GB")
      institution.memberships.create!(user: guardian_a)
      institution.memberships.create!(user: guardian_b)
      student_of_b = build_student!(institution, code: "OFB")
      link!(institution, guardian: guardian_b, student: student_of_b)

      result = Core::Access::GuardianScope.for(guardian_a, institution: institution)

      assert_empty result
    end
  end

  test "never returns a link that belongs to a DIFFERENT institution — the same global guardian" do
    institution_i = build_institution
    institution_j = build_institution

    guardian = within_tenant(institution_i) do
      g = Core::User.create!(email: "cross@correo.test", name: "Cross", national_id: "CROSS")
      institution_i.memberships.create!(user: g)
      g
    end
    within_tenant(institution_j) { institution_j.memberships.create!(user: guardian) }

    student_j = within_tenant(institution_j) { build_student!(institution_j, code: "ONLY-J") }
    within_tenant(institution_j) { link!(institution_j, guardian: guardian, student: student_j) }

    within_tenant(institution_i) do
      result = Core::Access::GuardianScope.for(guardian, institution: institution_i)
      assert_empty result, "a link that belongs to institution J leaked while acting in institution I"
    end
  end

  test "returns a composable ActiveRecord::Relation, not an Array" do
    institution = build_institution

    within_tenant(institution) do
      guardian = Core::User.create!(email: "g2@correo.test", name: "G2", national_id: "G-2")
      institution.memberships.create!(user: guardian)

      result = Core::Access::GuardianScope.for(guardian, institution: institution)
      assert_kind_of ActiveRecord::Relation, result
    end
  end

  test "returns an empty relation, not nil or an error, for a nil user or institution" do
    institution = build_institution
    within_tenant(institution) do
      guardian = Core::User.create!(email: "g3@correo.test", name: "G3", national_id: "G-3")
      assert_empty Core::Access::GuardianScope.for(nil, institution: institution)
      assert_empty Core::Access::GuardianScope.for(guardian, institution: nil)
    end
  end

  test "GuardianScope accepts no search term — the interface itself has no such parameter" do
    accepted_keywords = Core::Access::GuardianScope.method(:for).parameters.map(&:last)
    assert_not_includes accepted_keywords, :q
    assert_not_includes accepted_keywords, :term
    assert_not_includes accepted_keywords, :search
  end
end
