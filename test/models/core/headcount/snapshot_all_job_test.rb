require "test_helper"

# Recurring fan-out (v1.32.0, config/recurring.yml) — enqueues one real
# SnapshotJob per institution, since a recurring entry can only point at ONE
# job with fixed args and SnapshotJob itself needs a per-institution
# institution_id set before it runs.
class Core::Headcount::SnapshotAllJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def build_institution
    slug = "saj-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  test "enqueues one SnapshotJob per institution" do
    build_institution
    build_institution

    assert_enqueued_jobs 2, only: Core::Headcount::SnapshotJob do
      Core::Headcount::SnapshotAllJob.perform_now
    end
  end

  test "acceptance: running the fan-out then draining the queue snapshots every institution" do
    institution_a = build_institution
    institution_b = build_institution

    perform_enqueued_jobs do
      Core::Headcount::SnapshotAllJob.perform_now
    end

    assert ControlPlane::StudentHeadcountSnapshot.for_institution(institution_a).exists?
    assert ControlPlane::StudentHeadcountSnapshot.for_institution(institution_b).exists?
  end
end
