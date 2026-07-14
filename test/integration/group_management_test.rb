require "test_helper"

# #4 barrido (v1.14.0) — group_management copies the teacher_management
# canonical mold (§6.6). Same shape as TeacherManagementTest: real Section/
# Student rows, real role_assignments, per-row can? scope filtering.
class GroupManagementTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_section!(institution, name:, grade_level: nil)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026, grade_level: grade_level)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section: nil)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2012, 3, 15), student_code: student_code, entry_year: 2023,
      section: section, grade_level: section&.grade_level)
  end

  setup do
    @user, @institution = sign_in_as_member

    @section_9a = within_tenant(@institution) { build_section!(@institution, name: "9°A") }
    @section_10a = within_tenant(@institution) { build_section!(@institution, name: "10°A") }

    @in_group = within_tenant(@institution) do
      build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "COL-E-101", section: @section_9a)
    end
    @also_in_group = within_tenant(@institution) do
      build_student!(@institution, first_name: "Santiago", last_name: "Rojas", student_code: "COL-E-102", section: @section_9a)
    end
    @outside_group = within_tenant(@institution) do
      build_student!(@institution, first_name: "Mateo", last_name: "Cárdenas", student_code: "COL-E-104", section: @section_10a)
    end
  end

  # homeroom teacher of 9°A only.
  def as_homeroom(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom",
                                     permission_keys: %w[students.read groups.view groups.manage],
                                     scope_type: :group, scope_id: @section_9a.id),
      &block
    )
  end

  # secretary: institution-wide read on students/groups, no groups.manage.
  def as_secretary(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "secretary",
                                     permission_keys: %w[students.read groups.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "students index filters to the actor's own group, not the whole institution" do
    as_homeroom do
      get "/group_management/students"
      assert_response :success

      assert_select "a.student-row__person", text: /Valentina Suárez/
      assert_select "a.student-row__person", text: /Santiago Rojas/
      assert_select "a.student-row__person", text: /Mateo Cárdenas/, count: 0
    end
  end

  test "students index for an institution-wide read role sees every student" do
    as_secretary do
      get "/group_management/students"
      assert_response :success
      assert_select ".table tbody tr", count: 3
    end
  end

  test "an actor with no grants is denied the students index (403)" do
    with_grants do
      get "/group_management/students"
      assert_response :forbidden
    end
  end

  test "homeroom can view a student inside their own group but not one outside it" do
    as_homeroom do
      get "/group_management/students/#{@in_group.id}"
      assert_response :success

      get "/group_management/students/#{@outside_group.id}"
      assert_response :forbidden
    end
  end

  test "groups index and show are scoped the same way" do
    as_homeroom do
      get "/group_management/groups"
      assert_response :success
      assert_select "a", text: "9°A"
      assert_select "a", text: "10°A", count: 0

      get "/group_management/groups/#{@section_9a.id}"
      assert_response :success

      get "/group_management/groups/#{@section_10a.id}"
      assert_response :forbidden
    end
  end

  test "can? shows 'Editar matrícula' only for a role holding groups.manage" do
    as_homeroom do
      get "/group_management/groups/#{@section_9a.id}"
      assert_select "a.btn", text: "Editar matrícula"
    end

    as_secretary do
      get "/group_management/groups/#{@section_9a.id}"
      assert_response :success
      assert_select "a.btn", text: "Editar matrícula", count: 0
    end
  end

  test "authorize! denies the membership edit form for a role without groups.manage, matching can?" do
    as_secretary do
      get "/group_management/groups/#{@section_9a.id}/membership/edit"
      assert_response :forbidden
    end
  end

  test "homeroom can open the membership edit form for their own group" do
    as_homeroom do
      get "/group_management/groups/#{@section_9a.id}/membership/edit"
      assert_response :success
      assert_select "input[type=checkbox][name='student_ids[]']", minimum: 1
    end
  end

  # #4 barrido: unlike teacher.evaluate, students.section_id IS a real column
  # — so the membership update is a real write, not just a gate.
  test "updating membership really moves students between sections" do
    as_homeroom do
      patch "/group_management/groups/#{@section_9a.id}/membership",
        params: { student_ids: [ @in_group.id, @outside_group.id ] }
      assert_redirected_to group_management_group_path(@section_9a.id)

      assert_equal @section_9a.id, @outside_group.reload.section_id
      assert_equal @section_9a.id, @in_group.reload.section_id
      assert_nil @also_in_group.reload.section_id, "unchecked student should be unassigned, not left in the group"
    end
  end

  test "cross-tenant: a section/student seeded in a different institution never leaks into this one's index" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "gm-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(other_institution) do
      section = build_section!(other_institution, name: "9°A Otro Colegio")
      build_student!(other_institution, first_name: "Fantasma", last_name: "Cruzado", student_code: "GHOST-1", section: section)
    end

    as_secretary do
      get "/group_management/students"
      assert_response :success
      assert_no_match(/Fantasma Cruzado/, response.body)
      assert_select ".table tbody tr", count: 3

      get "/group_management/groups"
      assert_response :success
      assert_no_match(/9°A Otro Colegio/, response.body)
    end
  end
end
