module AnalyticsBi
  # Lens 6 — "Alertas Tempranas" (BI_DOCUMENT.md §5.8 amendment, guidelines/
  # CLOSURE_PLAN.md §3.2/Fase C). SUPERVISION (molde #4): authorize!
  # ("hps.early_warning.view") — INSTITUTION-WIDE ONLY, no smaller scope, same
  # criterion as FamilyCoresController. Read-only triage queue; index only —
  # there is no per-row "open" beyond linking to the EXISTING surfaces
  # (Lens 1/2, disciplinary logs, family core) where the underlying detail
  # already lives, and to the EXISTING communication compose flow — this
  # controller never sends anything itself, a human always decides to act.
  class EarlyWarningsController < ApplicationController
    def index
      authorize!("hps.early_warning.view")
      @flags = AnalyticsBi::Lens::EarlyWarningScope.new(context: authorization_context).resolve
        .sort_by { |flag| [ -flag.signal_labels.size, flag.student.last_name.to_s ] }
    end
  end
end
