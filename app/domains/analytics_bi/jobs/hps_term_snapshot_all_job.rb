module AnalyticsBi
  # Fan-out wrapper (guardrail v1.32.0 mold, Core::Headcount::SnapshotAllJob):
  # HpsTermSnapshotJob is per-institution (needs institution_id set before
  # ApplicationJob's GUC machinery runs), so a single caller (a rake trigger, or
  # a future config/recurring.yml entry if a term-close cadence is ever settled)
  # cannot point at it directly. This iterates institutions and enqueues ONE
  # HpsTermSnapshotJob each, letting each carry its own institution_id and
  # resolve its own active term independently.
  #
  # Runs with NO GUC of its own (institutions is GLOBAL) — never reads a tenant
  # table here.
  class HpsTermSnapshotAllJob < ApplicationJob
    def perform
      Core::Institution.find_each { |institution| HpsTermSnapshotJob.enqueue_for(institution) }
    end
  end
end
