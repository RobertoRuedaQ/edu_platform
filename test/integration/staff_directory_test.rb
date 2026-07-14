require "test_helper"

# StaffManagement::StaffScope (#4 slice 1) — "Personal" is the OTHER roster
# CHECKPOINT E (v1.12.0) left model-ready but stub-backed. Same canonical
# scope pattern as teacher_management: an institution-wide grant sees
# everyone, a department-scoped grant sees only its own department, and a
# staff member with a NULL department_id (non-academic, D1) must be visible
# institution-wide without ever "leaking" into a narrower department scope.
class StaffDirectoryTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_department!(institution, name:, code:, kind:)
    StaffManagement::Department.create!(institution: institution, name: name, code: code, kind: kind)
  end

  def build_staff_member!(institution, name:, employee_number:, category:, department: nil)
    user = Core::User.create!(email: "#{employee_number.downcase}@correo.test", name: name)
    iu = institution.memberships.create!(user: user)
    StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
      employee_number: employee_number, staff_category: category, employment_type: "full_time",
      department: department)
  end

  setup do
    @user, @institution = sign_in_as_member

    @matematicas = within_tenant(@institution) { build_department!(@institution, name: "Matemáticas", code: "MAT", kind: "academic") }
    @cafeteria_dept = within_tenant(@institution) { build_department!(@institution, name: "Cafetería", code: "CAF", kind: "operational") }

    @math_teacher = within_tenant(@institution) do
      build_staff_member!(@institution, name: "Carlos Peña", employee_number: "EMP-T1", category: "teaching",
        department: @matematicas)
    end
    @cook = within_tenant(@institution) do
      build_staff_member!(@institution, name: "Rosa Cocina", employee_number: "EMP-K1", category: "kitchen",
        department: @cafeteria_dept)
    end
    # No department at all — the non-academic, no-department case (E3): must
    # never be "lost", only invisible to a NARROWER-than-institution scope.
    @unassigned_staff = within_tenant(@institution) do
      build_staff_member!(@institution, name: "Sin Depto", employee_number: "EMP-U1", category: "other", department: nil)
    end
  end

  def as_admin(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "institution_admin", permission_keys: %w[staff.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_area_lead(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "area_lead", permission_keys: %w[staff.read],
                                     scope_type: :department, scope_id: @matematicas.id),
      &block
    )
  end

  test "an institution-wide grant sees every staff member, teaching and non-teaching, including unassigned" do
    as_admin do
      get "/staff_management/staff"
      assert_response :success
      assert_match(/Carlos Peña/, response.body)
      assert_match(/Rosa Cocina/, response.body)
      assert_match(/Sin Depto/, response.body)
      assert_select ".table tbody tr", count: 3
    end
  end

  test "a department-scoped grant sees only that department's staff — never the cafeteria, never the unassigned" do
    as_area_lead do
      get "/staff_management/staff"
      assert_response :success
      assert_match(/Carlos Peña/, response.body)
      assert_no_match(/Rosa Cocina/, response.body)
      assert_no_match(/Sin Depto/, response.body)
      assert_select ".table tbody tr", count: 1
    end
  end

  test "403 without staff.read" do
    with_grants do
      get "/staff_management/staff"
      assert_response :forbidden
    end
  end

  test "cross-tenant: staff seeded in a different institution never leaks into this one's directory" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "staff-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(other_institution) do
      build_staff_member!(other_institution, name: "Fantasma Ajeno", employee_number: "EMP-X1", category: "admin")
    end

    as_admin do
      get "/staff_management/staff"
      assert_response :success
      assert_no_match(/Fantasma Ajeno/, response.body)
      assert_select ".table tbody tr", count: 3
    end
  end
end
