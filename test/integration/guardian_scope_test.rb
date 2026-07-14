require "test_helper"

# The security acceptance case (§5): a guardian must see EXACTLY their own
# active acudidos in the active tenant — never a revoked link, never another
# tenant's link, never reachable by guessing a URL, and never via a search
# field that doesn't exist. If this breaks, it's a data leak on minors.
class GuardianScopeTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "gst-#{SecureRandom.hex(4)}"
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

  test "acceptance: guardian sees exactly [S1, S2] — not revoked S3, not other-tenant S4, no search, direct URLs blocked" do
    institution_i = build_institution
    institution_j = build_institution

    guardian = Core::User.create!(email: "g@correo.test", name: "Guardiana G", password: "password-123456")

    s1 = within_tenant(institution_i) do
      institution_i.memberships.create!(user: guardian)
      build_student!(institution_i, code: "S1")
    end
    s2, s3 = within_tenant(institution_i) do
      [ build_student!(institution_i, code: "S2"), build_student!(institution_i, code: "S3") ]
    end
    within_tenant(institution_i) do
      link!(institution_i, guardian: guardian, student: s1, status: "active")
      link!(institution_i, guardian: guardian, student: s2, status: "active")
      link!(institution_i, guardian: guardian, student: s3, status: "revoked")
    end

    s4 = within_tenant(institution_j) do
      institution_j.memberships.create!(user: guardian)
      student = build_student!(institution_j, code: "S4")
      link!(institution_j, guardian: guardian, student: student)
      student
    end

    sign_in_as(guardian, institution: institution_i, password: "password-123456")

    get "/portal/guardian"
    assert_response :success
    assert_match(/S1/, response.body)
    assert_match(/S2/, response.body)
    assert_no_match(/S3/, response.body)
    assert_no_match(/S4/, response.body)

    # No search field anywhere on the page — Habeas Data invariant (GS4).
    assert_select "input[type=search]", count: 0
    assert_select "input[name=q]", count: 0
    assert_select "form[action*=search]", count: 0

    # S1/S2 are reachable read-only summaries.
    get "/portal/guardian/students/#{s1.id}"
    assert_response :success
    assert_match(/S1/, response.body)

    get "/portal/guardian/students/#{s2.id}"
    assert_response :success

    # S3 (revoked, same tenant) is NOT reachable by direct URL.
    get "/portal/guardian/students/#{s3.id}"
    assert_response :not_found

    # S4 (active, but a DIFFERENT tenant) is NOT reachable while acting in I.
    get "/portal/guardian/students/#{s4.id}"
    assert_response :not_found
  end

  test "a guardian with zero active links sees the empty state, never an error" do
    institution = build_institution
    guardian = Core::User.create!(email: "empty@correo.test", name: "Sin Vinculos", password: "password-123456")
    within_tenant(institution) { institution.memberships.create!(user: guardian) }

    sign_in_as(guardian, institution: institution, password: "password-123456")

    get "/portal/guardian"
    assert_response :success
    assert_select ".empty-state__title"
  end

  test "student self-scope: a student sees only their own record; there is no route to another student's" do
    institution = build_institution
    student_user = Core::User.create!(email: "student@correo.test", name: "Estudiante Propio", password: "password-123456")

    within_tenant(institution) do
      institution.memberships.create!(user: student_user)
      GroupManagement::Student.create!(institution: institution, national_id: "SELF-1",
        first_name: "Yo", last_name: "Mismo", gender: "male", birthdate: Date.new(2015, 1, 1),
        student_code: "SELF-CODE", entry_year: 2026, user: student_user)
    end

    sign_in_as(student_user, institution: institution, password: "password-123456")

    get "/portal/student"
    assert_response :success
    assert_match(/SELF-CODE/, response.body)
    assert_select "input[type=search]", count: 0

    # Structural guarantee, not just behavioral: the route is a singular
    # resource with no :id segment at all — there is no URL shape to even
    # attempt "someone else's" student portal. Unmatched routes 404 rather
    # than raise here (config.action_dispatch.show_exceptions = :rescuable
    # in test), same as any other RecordNotFound-driven 404 in this app.
    get "/portal/student/#{SecureRandom.uuid}"
    assert_response :not_found
  end

  test "a student with no linked record sees the empty state, never an error" do
    institution = build_institution
    user = Core::User.create!(email: "nolink@correo.test", name: "Sin Registro", password: "password-123456")
    within_tenant(institution) { institution.memberships.create!(user: user) }

    sign_in_as(user, institution: institution, password: "password-123456")

    get "/portal/student"
    assert_response :success
    assert_select ".empty-state__title"
  end
end
