require "test_helper"

class ControlPlane::StudentHeadcountSnapshotTest < ActiveSupport::TestCase
  def build_institution
    slug = "hc-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "one snapshot per institution+as_of_date" do
    institution = build_institution
    ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: Date.current, headcount: 10)

    duplicate = ControlPlane::StudentHeadcountSnapshot.new(institution: institution, as_of_date: Date.current, headcount: 20)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:as_of_date].join, "ya"
  end

  test "headcount cannot be negative" do
    institution = build_institution
    snapshot = ControlPlane::StudentHeadcountSnapshot.new(institution: institution, as_of_date: Date.current, headcount: -1)
    assert_not snapshot.valid?
  end

  test "the DB CHECK backstops non-negative headcount" do
    institution = build_institution
    snapshot = ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: Date.current, headcount: 5)
    assert_raises(ActiveRecord::StatementInvalid) { snapshot.update_column(:headcount, -1) }
  end

  test "latest_for returns the most recent snapshot" do
    institution = build_institution
    ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: 2.days.ago.to_date, headcount: 8)
    latest = ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: Date.current, headcount: 12)

    assert_equal latest.id, ControlPlane::StudentHeadcountSnapshot.latest_for(institution).id
  end

  test "re-running for the same date updates rather than duplicates" do
    institution = build_institution
    snapshot = ControlPlane::StudentHeadcountSnapshot.create!(institution: institution, as_of_date: Date.current, headcount: 5)

    updated = ControlPlane::StudentHeadcountSnapshot.find_or_initialize_by(institution_id: institution.id, as_of_date: Date.current)
    updated.headcount = 6
    updated.save!

    assert_equal snapshot.id, updated.id
    assert_equal 1, ControlPlane::StudentHeadcountSnapshot.for_institution(institution).count
    assert_equal 6, snapshot.reload.headcount
  end
end
