require "test_helper"

# CANONICAL REFERENCE unit test for the #4 "business view" query object
# pattern — TeacherManagement::TeacherScope is the first REAL implementation
# (the other six domains copy this shape). Exercises the query object
# directly (no HTTP), same style as Core::Access::StaffRoleAssignmentsScopeTest.
class TeacherManagement::TeacherScopeTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "tms-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_department!(institution, name:, code:)
    StaffManagement::Department.create!(institution: institution, name: name, code: code, kind: "academic")
  end

  def build_teacher!(institution, department:, teacher_code:)
    user = Core::User.create!(email: "#{teacher_code.downcase}@correo.test", name: "Docente #{teacher_code}")
    iu = institution.memberships.create!(user: user)
    staff_member = StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
      employee_number: "EMP-#{teacher_code}", staff_category: "teaching", employment_type: "full_time",
      department: department)
    TeacherManagement::Teacher.create!(institution: institution, staff_member: staff_member,
      first_name: "Docente", last_name: teacher_code, gender: "male", teacher_code: teacher_code)
  end

  # A context that grants only what's given — mirrors Authorization::
  # StubResolver's shape without depending on the retired class directly.
  FakeContext = Struct.new(:grants) do
    def can?(permission_key, resource = nil)
      grants.any? { |a| a.grants?(permission_key) && a.covers?(resource) }
    end
  end

  test "per-row can? filters to the actor's department scope, never the whole institution" do
    institution = build_institution

    within_tenant(institution) do
      math = build_department!(institution, name: "Matemáticas", code: "MAT")
      social = build_department!(institution, name: "Sociales", code: "SOC")
      inside = build_teacher!(institution, department: math, teacher_code: "IN1")
      outside = build_teacher!(institution, department: social, teacher_code: "OUT1")

      context = FakeContext.new([
        Authorization::Assignment.new(role_key: "area_lead", permission_keys: %w[teachers.view],
                                       scope_type: :department, scope_id: math.id)
      ])

      result = TeacherManagement::TeacherScope.new(context: context, institution: institution).resolve

      assert_equal [ inside.id ], result.map(&:id)
      assert_not_includes result.map(&:id), outside.id
    end
  end

  test "an institution-wide grant resolves every teacher" do
    institution = build_institution

    within_tenant(institution) do
      math = build_department!(institution, name: "Matemáticas", code: "MAT")
      social = build_department!(institution, name: "Sociales", code: "SOC")
      build_teacher!(institution, department: math, teacher_code: "A1")
      build_teacher!(institution, department: social, teacher_code: "A2")

      context = FakeContext.new([
        Authorization::Assignment.new(role_key: "secretary", permission_keys: %w[teachers.view],
                                       scope_type: :institution, scope_id: nil)
      ])

      result = TeacherManagement::TeacherScope.new(context: context, institution: institution).resolve
      assert_equal 2, result.size
    end
  end

  test "a teacher with no staff_member link (unlinked, D1's additive transition) is never scope-matched" do
    institution = build_institution

    within_tenant(institution) do
      math = build_department!(institution, name: "Matemáticas", code: "MAT")
      unlinked = TeacherManagement::Teacher.create!(institution: institution, staff_member: nil,
        first_name: "Sin", last_name: "Vincular", gender: "male", teacher_code: "UNLINKED")

      context = FakeContext.new([
        Authorization::Assignment.new(role_key: "area_lead", permission_keys: %w[teachers.view],
                                       scope_type: :department, scope_id: math.id)
      ])

      result = TeacherManagement::TeacherScope.new(context: context, institution: institution).resolve
      assert_empty result
      assert_nil unlinked.department_id
    end
  end

  test "never returns a teacher from a DIFFERENT institution" do
    institution_i = build_institution
    institution_j = build_institution

    within_tenant(institution_j) do
      dept = build_department!(institution_j, name: "Matemáticas J", code: "MAT")
      build_teacher!(institution_j, department: dept, teacher_code: "J1")
    end

    within_tenant(institution_i) do
      context = FakeContext.new([
        Authorization::Assignment.new(role_key: "secretary", permission_keys: %w[teachers.view],
                                       scope_type: :institution, scope_id: nil)
      ])
      result = TeacherManagement::TeacherScope.new(context: context, institution: institution_i).resolve
      assert_empty result
    end
  end
end
