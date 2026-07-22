require "test_helper"

# guidelines/library_prompt.md, Fase D greenfield increment 1 (OPEN_PROCESS.md
# #1 — confirmed explicitly by the owner). First fully net-new domain built
# this session with zero pre-existing stub to convert.
class LibraryTest < ActionDispatch::IntegrationTest
  def within_tenant(&block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(@institution.id)
      block.call
    end
  end

  setup { @user, @institution = sign_in_as_member }

  def as_cataloguer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "library_cataloguer", permission_keys: %w[library.catalog.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_desk_staff(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "library_desk", permission_keys: %w[library.checkout],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def as_loans_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "library_manager", permission_keys: %w[library.loans.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def build_resource_and_copy!(barcode: "LIB-#{SecureRandom.hex(3)}")
    within_tenant do
      resource = Library::Resource.create!(institution: @institution, title: "Cien años de soledad")
      Library::ResourceCopy.create!(institution: @institution, resource: resource, barcode: barcode)
    end
  end

  def build_student!(code: "LIB-S-#{SecureRandom.hex(2)}")
    within_tenant do
      GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, status: "active")
    end
  end

  test "catalog index requires library.catalog.manage" do
    with_grants { get "/library/resources"; assert_response :forbidden }

    as_cataloguer do
      get "/library/resources"
      assert_response :success
    end
  end

  test "cataloguer can create a title and a copy" do
    as_cataloguer do
      assert_difference -> { Library::Resource.count }, 1 do
        post "/library/resources", params: { resource: { title: "Rayuela", author: "Cortázar" } }
      end
      resource = Library::Resource.last
      assert_redirected_to library_resources_path

      assert_difference -> { Library::ResourceCopy.count }, 1 do
        post "/library/resources/#{resource.id}/copies", params: { resource_copy: { barcode: "LIB-NEW-1" } }
      end
    end
  end

  test "the catalog screen never lets a copy be flipped to loaned by hand" do
    copy = build_resource_and_copy!

    as_cataloguer do
      patch "/library/resources/#{copy.resource_id}/copies/#{copy.id}", params: { resource_copy: { status: "loaned" } }
      assert_redirected_to library_resource_copies_path(copy.resource_id)
    end

    within_tenant { assert_equal "available", copy.reload.status }
  end

  test "checkout is denied entirely without library.checkout" do
    with_grants { get "/library/checkouts/new"; assert_response :forbidden }
  end

  test "lends an available copy to a student, and the copy is unavailable for a second lend" do
    copy = build_resource_and_copy!
    student = build_student!

    as_desk_staff do
      assert_difference -> { Library::Loan.count }, 1 do
        post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code,
          idempotency_key: SecureRandom.uuid }
      end
      assert_redirected_to library_checkouts_path

      assert_no_difference -> { Library::Loan.count } do
        post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code,
          idempotency_key: SecureRandom.uuid }
      end
      assert_response :unprocessable_entity
    end
  end

  test "lending to an unknown borrower identifier fails gracefully, never a 500" do
    copy = build_resource_and_copy!

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: "no-such-code",
        idempotency_key: SecureRandom.uuid }
      assert_response :unprocessable_entity
    end
  end

  test "idempotency: resubmitting the same key never lends twice" do
    copy = build_resource_and_copy!
    student = build_student!
    key = SecureRandom.uuid

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code, idempotency_key: key }
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code, idempotency_key: key }
    end

    within_tenant { assert_equal 1, Library::Loan.where(institution_id: @institution.id, idempotency_key: key).count }
  end

  test "returning by barcode frees the copy for a new loan" do
    copy = build_resource_and_copy!
    student = build_student!
    other_student = build_student!

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code,
        idempotency_key: SecureRandom.uuid }
      post "/library/returns", params: { barcode: copy.barcode }
      assert_redirected_to new_library_checkout_path

      assert_difference -> { Library::Loan.count }, 1 do
        post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: other_student.student_code,
          idempotency_key: SecureRandom.uuid }
      end
    end
  end

  test "loans index requires library.loans.manage, not library.checkout" do
    as_desk_staff { get "/library/loans"; assert_response :forbidden }

    as_loans_manager do
      get "/library/loans"
      assert_response :success
    end
  end

  # M1 (guidelines/library_prompt.md — wired for real from day one, unlike
  # cafeteria/transportation which were retrofitted, OPEN_PROCESS.md #5).
  test "M1: a real loan emits one usage event, and resubmitting never duplicates it" do
    ControlPlane::Addon.find_by!(key: "library").update!( # sign_in_as_member already seeded this, unmetered
      metered: true, unit: "préstamos", included_quota: 100, overage_unit_price_cents: 50
    )
    copy = build_resource_and_copy!
    student = build_student!
    key = SecureRandom.uuid

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code, idempotency_key: key }
    end

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 1, events.count
    assert_equal "préstamos", events.sole.unit

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code, idempotency_key: key }
    end

    assert_equal 1, ControlPlane::UsageEvent.where(institution_id: @institution.id).count
  end

  # --- portals: resolved by relation, no RBAC permission needed at all ------

  test "student portal shows own loans and the catalog, with no grants" do
    copy = build_resource_and_copy!
    student = build_student!

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code,
        idempotency_key: SecureRandom.uuid }
    end

    self_user = within_tenant do
      student.update!(user: Core::User.create!(email: "student-#{SecureRandom.hex(4)}@member.test",
        name: "#{student.first_name} #{student.last_name}", password: "password-123456"))
      @institution.memberships.create!(user: student.user)
      student.user
    end

    sign_in_as(self_user, institution: @institution, password: "password-123456")
    get "/portal/student/library"
    assert_response :success
    assert_match(/Cien años de soledad/, response.body)
  end

  test "guardian portal shows only the guardian's own child's loans" do
    copy = build_resource_and_copy!
    student = build_student!

    as_desk_staff do
      post "/library/checkouts", params: { barcode: copy.barcode, borrower_identifier: student.student_code,
        idempotency_key: SecureRandom.uuid }
    end

    guardian_user = within_tenant do
      user = Core::User.create!(email: "guardian-lib-#{SecureRandom.hex(4)}@member.test", name: "Acudiente Bib",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: student,
        relationship: "madre", status: "active")
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/library"
    assert_response :success
    assert_match(/Cien años de soledad/, response.body)
  end
end
