require "test_helper"

# The acceptance case (§5): a staff person's "mis datos" must show exactly
# their own profile/vigente roles/groups/department — never an expired
# assignment, never another person's data, never another tenant's data —
# and must be reachable with ZERO permissions over anyone else (SS2:
# identity-gated, not RBAC-gated).
class SelfServiceTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "ss-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def grant_full_entitlements(institution)
    Entitlement::Registry.domains.each do |key|
      addon = ControlPlane::Addon.find_or_create_by!(key: key) { |a| a.name = key.humanize; a.currency = "COP" }
      ControlPlane::Entitlement.create!(institution: institution, addon: addon, valid_from: Date.current)
    end
  end

  def create_role_assignment!(institution, institution_user:, role_key:, scope_group_id: nil,
                               scope_department_id: nil, valid_from: Date.current, valid_until: nil)
    role = IdentityAccess::Role.create!(institution: institution, key: "#{role_key}-#{SecureRandom.hex(3)}",
      name: role_key.humanize)
    IdentityAccess::RoleAssignment.create!(institution: institution, institution_user: institution_user, role: role,
      scope_group_id: scope_group_id, scope_department_id: scope_department_id,
      valid_from: valid_from, valid_until: valid_until)
  end

  test "acceptance: my profile/vigente roles/groups/department, never an expired assignment, another person, or another tenant" do
    institution_i = build_institution
    institution_j = build_institution
    grant_full_entitlements(institution_i) # includes schedules

    section_10a = within_tenant(institution_i) do
      GroupManagement::Section.create!(id: GroupManagement::GroupRoster::SECTION_10A_ID,
        institution: institution_i, name: "10°A", academic_year: 2026)
    end
    section_9c = within_tenant(institution_i) do
      GroupManagement::Section.create!(institution: institution_i, name: "9°C", academic_year: 2026)
    end
    department = within_tenant(institution_i) do
      StaffManagement::Department.create!(institution: institution_i, name: "Matemáticas", code: "MAT", kind: "academic")
    end

    teacher = Core::User.create!(email: "teacher@correo.test", name: "Docente T", password: "password-123456")
    iu_teacher = within_tenant(institution_i) { institution_i.memberships.create!(user: teacher) }

    within_tenant(institution_i) do
      # Vigente — must show.
      create_role_assignment!(institution_i, institution_user: iu_teacher, role_key: "teacher",
        scope_group_id: section_10a.id)
      # Expired — must NEVER show.
      create_role_assignment!(institution_i, institution_user: iu_teacher, role_key: "teacher",
        scope_group_id: section_9c.id, valid_from: 60.days.ago.to_date, valid_until: 1.day.ago.to_date)
      # Department scope — must show.
      create_role_assignment!(institution_i, institution_user: iu_teacher, role_key: "area_lead",
        scope_department_id: department.id)
      StaffManagement::StaffMember.create!(institution: institution_i, institution_user: iu_teacher,
        employee_number: "EMP-T", staff_category: "teaching", employment_type: "full_time", department: department)
    end

    # A second teacher U in the SAME institution — must never appear anywhere.
    other_section = within_tenant(institution_i) do
      GroupManagement::Section.create!(institution: institution_i, name: "11°U-Solo", academic_year: 2026)
    end
    within_tenant(institution_i) do
      other_teacher = Core::User.create!(email: "other@correo.test", name: "Docente U")
      iu_other = institution_i.memberships.create!(user: other_teacher)
      create_role_assignment!(institution_i, institution_user: iu_other, role_key: "teacher", scope_group_id: other_section.id)
    end

    # Cross-tenant: the SAME global teacher T also has data in J — must never leak into I.
    within_tenant(institution_j) do
      iu_teacher_j = institution_j.memberships.create!(user: teacher)
      cross_department = StaffManagement::Department.create!(institution: institution_j, name: "Solo-En-J", code: "SEJ", kind: "academic")
      create_role_assignment!(institution_j, institution_user: iu_teacher_j, role_key: "teacher",
        scope_department_id: cross_department.id)
    end

    sign_in_as(teacher, institution: institution_i, password: "password-123456")

    get "/mis_datos"
    assert_response :success

    # Vigente data present.
    assert_match(/10°A/, response.body)
    assert_match(/Matemáticas/, response.body)
    assert_match(/EMP-T/, response.body)

    # Expired assignment's group never shown.
    assert_no_match(/9°C/, response.body)

    # Another teacher's group, in the SAME institution, never shown.
    assert_no_match(/11°U-Solo/, response.body)

    # Cross-tenant department never shown while acting in I.
    assert_no_match(/Solo-En-J/, response.body)

    # "Mi horario" (schedules entitled): filtered by MY OWN group (10°A) —
    # the stub event tagged with the SAME canonical section shows; nothing
    # tagged with a different section does.
    assert_match(/Cálculo/, response.body)
    assert_no_match(/Sociología/, response.body) # tagged 11B in the stub roster, not this actor's group

    # No search surface WITHIN the self-service page's own content (Habeas
    # Data invariant, same as the portals) — scoped to #main to deliberately
    # exclude the staff shell's pre-existing global app search in the
    # header, which is unrelated to this page and out of this slice's scope.
    assert_select "main#main input[type=search]", count: 0
    assert_select "main#main input[name=q]", count: 0

    # Structural guarantee: self_service is a singular resource with no :id
    # segment — there is no URL shape to even attempt "someone else's" data.
    get "/mis_datos/#{SecureRandom.uuid}"
    assert_response :not_found
  end

  test "identity-gating: a person with ZERO role_permissions on anyone still reaches self-service fully" do
    institution = build_institution
    section = within_tenant(institution) { GroupManagement::Section.create!(institution: institution, name: "7°A", academic_year: 2026) }

    teacher = Core::User.create!(email: "solo@correo.test", name: "Solo Yo", password: "password-123456")
    iu = within_tenant(institution) { institution.memberships.create!(user: teacher) }
    within_tenant(institution) do
      create_role_assignment!(institution, institution_user: iu, role_key: "teacher", scope_group_id: section.id)
      # No IdentityAccess::Permission / RolePermission created at all — this
      # actor cannot pass a SINGLE authorize! check on anyone else's data.
      assert_equal 0, IdentityAccess::RolePermission.where(institution_id: institution.id).count
    end

    sign_in_as(teacher, institution: institution, password: "password-123456")

    get "/mis_datos"
    assert_response :success
    assert_match(/7°A/, response.body)
  end

  test "a coordinator with only an institution-wide role and no groups sees empty states, not an error" do
    institution = build_institution

    coordinator = Core::User.create!(email: "coord@correo.test", name: "Coordinadora", password: "password-123456")
    iu = within_tenant(institution) { institution.memberships.create!(user: coordinator) }
    within_tenant(institution) { create_role_assignment!(institution, institution_user: iu, role_key: "coordinator") }

    sign_in_as(coordinator, institution: institution, password: "password-123456")

    get "/mis_datos"
    assert_response :success
    assert_select ".empty-state__title", minimum: 2 # profile (no staff_member) + groups, at least
  end

  test "the horario tile disappears entirely when schedules is not entitled" do
    institution = build_institution # grant_full_entitlements NOT called — nothing entitled

    teacher = Core::User.create!(email: "noschedule@correo.test", name: "Sin Horario", password: "password-123456")
    iu = within_tenant(institution) { institution.memberships.create!(user: teacher) }
    within_tenant(institution) { create_role_assignment!(institution, institution_user: iu, role_key: "teacher") }

    sign_in_as(teacher, institution: institution, password: "password-123456")

    get "/mis_datos"
    assert_response :success
    assert_no_match(/Mi horario/, response.body)
  end
end
