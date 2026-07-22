require "test_helper"

# guidelines/CLOSURE_PLAN.md §4.2: the first staff-facing surface for
# Core::AcademicTerm. ONE unified permission (academic_terms.manage) gates
# create/edit/activate/close. "Cerrar término" is ALSO the manual trigger for
# AnalyticsBi::HpsTermSnapshotJob — the owner's confirmed choice over a
# scheduled/cron trigger.
class CoreAcademicTermsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user, @institution = sign_in_as_member # default grant does NOT include academic_terms.manage
  end

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def as_manager(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "term_manager",
        permission_keys: %w[academic_terms.manage], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def build_term(status: "upcoming")
    within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "CAT-#{SecureRandom.hex(4)}", name: "2026-1",
        status: status, starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30))
    end
  end

  test "the default persona (no academic_terms.manage) is denied every action (403)" do
    term = build_term
    get core_academic_terms_path
    assert_response :forbidden

    get new_core_academic_term_path
    assert_response :forbidden

    post core_academic_terms_path, params: { academic_term: { code: "X", name: "X", starts_on: "2026-01-01", ends_on: "2026-06-30" } }
    assert_response :forbidden

    post activate_core_academic_term_path(term)
    assert_response :forbidden

    post close_core_academic_term_path(term)
    assert_response :forbidden
  end

  test "a manager creates a term as upcoming" do
    as_manager do
      assert_difference -> { Core::AcademicTerm.count }, 1 do
        post core_academic_terms_path, params: {
          academic_term: { code: "CAT-NEW", name: "2026-2", starts_on: "2026-07-01", ends_on: "2026-12-15" }
        }
      end
      assert_response :redirect

      term = within_tenant(@institution) { Core::AcademicTerm.find_by(code: "CAT-NEW") }
      assert_equal "upcoming", term.status
    end
  end

  test "an invalid date range is rejected with a friendly error, never a 500" do
    as_manager do
      assert_no_difference -> { Core::AcademicTerm.count } do
        post core_academic_terms_path, params: {
          academic_term: { code: "CAT-BAD", name: "Bad", starts_on: "2026-06-01", ends_on: "2026-01-01" }
        }
      end
      assert_response :unprocessable_entity
    end
  end

  test "activating an upcoming term works when no other term is active" do
    term = build_term(status: "upcoming")
    as_manager do
      post activate_core_academic_term_path(term)
      assert_response :redirect
      assert_equal "active", within_tenant(@institution) { term.reload.status }
    end
  end

  test "activating a second term while one is already active is rejected cleanly (DB backstop), never a 500" do
    build_term(status: "active")
    upcoming = build_term(status: "upcoming")

    as_manager do
      post activate_core_academic_term_path(upcoming)
      assert_response :redirect
      follow_redirect!
      assert_match(/ya hay un término activo/i, flash[:alert].to_s)
      assert_equal "upcoming", within_tenant(@institution) { upcoming.reload.status }
    end
  end

  test "closing an active term flips it to closed AND enqueues the HPS snapshot job for that exact term" do
    term = build_term(status: "active")

    as_manager do
      assert_enqueued_with(job: AnalyticsBi::HpsTermSnapshotJob) do
        post close_core_academic_term_path(term)
      end
      assert_response :redirect
      assert_equal "closed", within_tenant(@institution) { term.reload.status }
    end
  end

  test "a foreign institution's term id 404s, never leaks cross-tenant" do
    other_institution = Core::Institution.create!(name: "Otro", slug: "cat-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    other_term = within_tenant(other_institution) do
      Core::AcademicTerm.create!(institution: other_institution, code: "OTHER-1", name: "Otro término",
        status: "upcoming", starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30))
    end

    as_manager do
      get edit_core_academic_term_path(other_term)
      assert_response :not_found
    end
  end
end
