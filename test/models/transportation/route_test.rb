require "test_helper"

# guidelines/CLOSURE_PLAN.md Fase D (third increment, v1.49.0): Transportation::
# Route/RouteRider/BoardingEvent, the real replacement for RouteRoster/
# RiderRoster (100% Data.define stubs). Exercised directly under the tenant
# GUC (RLS FORCE) — same molde as StudentSupport::DisciplinaryLogTest.
class Transportation::RouteTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "tr-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_student(institution)
    section = GroupManagement::Section.create!(institution: institution, name: "9A", academic_year: 2026)
    GroupManagement::Student.create!(institution: institution, section: section, first_name: "Ana", last_name: "P",
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "TR-ANA", entry_year: 2023)
  end

  def build_driver(institution)
    user = Core::User.create!(email: "driver-#{SecureRandom.hex(4)}@test", name: "Pedro Sánchez",
      password: "password-123456")
    iu = institution.memberships.create!(user: user)
    StaffManagement::StaffMember.create!(institution: institution, institution_user: iu, employee_number: "T-1",
      staff_category: "transport", employment_type: "full_time", status: "active")
  end

  test "route_id aliases id — the SCOPE_READERS[:route] descriptor a :route-scoped grant reads" do
    institution = build_institution
    within_tenant(institution) do
      route = Transportation::Route.create!(institution: institution, name: "Ruta 1")
      assert_equal route.id, route.route_id
    end
  end

  test "driver_name delegates to the real StaffMember, nil when unassigned" do
    institution = build_institution
    within_tenant(institution) do
      driver = build_driver(institution)
      route = Transportation::Route.create!(institution: institution, name: "Ruta 1", driver_staff_member: driver)
      assert_equal "Pedro Sánchez", route.driver_name

      unassigned = Transportation::Route.create!(institution: institution, name: "Ruta 2")
      assert_nil unassigned.driver_name
    end
  end

  test "a closed shift is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      route = Transportation::Route.create!(institution: institution, name: "Ruta 1")
      student = build_student(institution)
      rider = Transportation::RouteRider.new(institution: institution, route: route, student: student, shift: "midday")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { rider.save!(validate: false) }
      end
    end
  end

  test "a student can ride different routes across shifts, but not two routes in the same shift" do
    institution = build_institution
    within_tenant(institution) do
      route1 = Transportation::Route.create!(institution: institution, name: "Ruta 1")
      route3 = Transportation::Route.create!(institution: institution, name: "Ruta 3")
      student = build_student(institution)

      Transportation::RouteRider.create!(institution: institution, route: route1, student: student, shift: "am")
      Transportation::RouteRider.create!(institution: institution, route: route3, student: student, shift: "pm")
      assert_equal 2, Transportation::RouteRider.where(student_id: student.id).count

      duplicate = Transportation::RouteRider.new(institution: institution, route: route3, student: student, shift: "am")
      assert_not duplicate.valid?
    end
  end

  test "a closed event_type is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      route = Transportation::Route.create!(institution: institution, name: "Ruta 1")
      student = build_student(institution)
      driver = build_driver(institution)
      event = Transportation::BoardingEvent.new(institution: institution, route: route, student: student,
        recorded_by: driver.institution_user, event_type: "teleported")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { event.save!(validate: false) }
      end
    end
  end
end
