require "test_helper"

# Recurring fan-out (v1.32.0, config/recurring.yml) — cuts the PREVIOUS full
# calendar month for every institution with an active subscription right
# now; skips (never enqueues, never a logged rejection) an institution with
# none, since that's the expected common case, not a failure.
class ControlPlane::Billing::PeriodCutAllJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def build_institution
    slug = "pcaj-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_plan
    ControlPlane::Plan.create!(key: "plan-#{SecureRandom.hex(4)}", name: "Plan de prueba",
      base_price_per_student_cents: 300_000, currency: "COP")
  end

  test "enqueues a PeriodCutJob only for institutions with an active subscription, for the previous calendar month" do
    subscribed = build_institution
    ControlPlane::Subscription.sign!(institution: subscribed, plan: build_plan, starts_on: Date.new(2026, 1, 1))
    unsubscribed = build_institution

    as_of = Date.new(2026, 7, 15)
    assert_enqueued_jobs 1, only: ControlPlane::Billing::PeriodCutJob do
      ControlPlane::Billing::PeriodCutAllJob.perform_now(as_of: as_of)
    end

    job_args = enqueued_jobs.find { |j| j["job_class"] == "ControlPlane::Billing::PeriodCutJob" }["arguments"].first
    assert_equal subscribed.id, job_args["institution_id"]

    period = ControlPlane::BillingPeriod.find(job_args["billing_period_id"])
    assert_equal subscribed.id, period.institution_id
    assert_equal Date.new(2026, 6, 1), period.starts_on
    assert_equal Date.new(2026, 6, 30), period.ends_on
  end

  test "acceptance: draining the queue produces a draft invoice for June when run in July" do
    institution = build_institution
    ControlPlane::Subscription.sign!(institution: institution, plan: build_plan, starts_on: Date.new(2026, 1, 1))

    perform_enqueued_jobs do
      ControlPlane::Billing::PeriodCutAllJob.perform_now(as_of: Date.new(2026, 7, 1))
    end

    invoice = ControlPlane::Invoice.for_institution(institution).sole
    assert_equal Date.new(2026, 6, 1), invoice.period_start
    assert_equal Date.new(2026, 6, 30), invoice.period_end
    assert_equal "draft", invoice.status
  end

  test "running the same month twice never creates a second BillingPeriod" do
    institution = build_institution
    ControlPlane::Subscription.sign!(institution: institution, plan: build_plan, starts_on: Date.new(2026, 1, 1))

    perform_enqueued_jobs { ControlPlane::Billing::PeriodCutAllJob.perform_now(as_of: Date.new(2026, 7, 1)) }
    perform_enqueued_jobs { ControlPlane::Billing::PeriodCutAllJob.perform_now(as_of: Date.new(2026, 7, 20)) }

    assert_equal 1, ControlPlane::BillingPeriod.where(institution_id: institution.id).count
  end
end
