module AnalyticsBi
  module Lens
    # Lens 6 — "Alertas Tempranas" (capstone synthesis, guidelines/
    # CLOSURE_PLAN.md §3.2 / BI_DOCUMENT.md §5.8 amendment). Reads signals that
    # ALREADY exist across domains and synthesizes a single "needs attention"
    # flag per student — it computes and reads, it OWNS nothing and persists
    # nothing (§7 default, same "vivas al inicio" posture as
    # BondTension/SiblingBondAlert).
    #
    # NO BUSINESS RULE WAS EVER CONFIRMED for thresholds/audience/frequency
    # (BI_DOCUMENT.md §3.2 says explicitly: "sin regla de negocio real
    # confirmada... no se modela"). This ships anyway on the owner's explicit
    # instruction to proceed with a documented, conservative default — same
    # posture as SiblingBondAlert's placeholder heuristic. TRIGGER_MIN_SIGNALS
    # and the recent-incident window are PLACEHOLDERS, not a confirmed policy;
    # revisit the moment a real threshold is defined.
    #
    # PER-SIGNAL PERMISSION GATING (critical, same pattern as
    # StudentSupport::SupportDashboardController's own documented rule:
    # "holding [the umbrella permission] alone never leaks a section the actor
    # lacks the specific permission for"): hps.early_warning.view only grants
    # the RIGHT TO SEE THE SYNTHESIS SURFACE. Each underlying signal is
    # independently re-checked against the SAME permission that already gates
    # it elsewhere (hps.aura.view for auras, disciplinary_logs.manage for
    # disciplinary logs, hps.family.view for the sibling alert) — a viewer
    # missing one of those simply never sees that particular signal, the row
    # is never suppressed entirely just because one signal is hidden.
    class EarlyWarningScope
      HEAT_RISK_THRESHOLD = 0.6
      RECENT_DISCIPLINARY_WINDOW_DAYS = 30
      TRIGGER_MIN_SIGNALS = 1 # any ONE real signal (heat/disciplinary/sibling) is enough to flag

      Flag = Data.define(:student, :heat_risk, :disciplinary_recent, :sibling_alert, :care_aura_present) do
        def triggered? = heat_risk || disciplinary_recent || sibling_alert

        def signal_labels
          [
            ("Riesgo académico/asistencia" if heat_risk),
            ("Incidente de convivencia reciente" if disciplinary_recent),
            ("Alerta de lazos fraternales" if sibling_alert)
          ].compact
        end
      end

      def initialize(context:, institution: Current.institution, as_of: Date.current)
        @context = context
        @institution = institution
        @as_of = as_of
      end

      # Only the FLAGGED students (triggered? true) — an honest, non-empty-by-
      # default list. A student with zero real signals never appears; this is
      # a triage queue, never a roster of everyone.
      def resolve
        active_students.filter_map { |student| flag_for(student) }.select(&:triggered?)
      end

      private

      attr_reader :context, :institution, :as_of

      def active_students
        GroupManagement::Student.where(institution_id: institution.id, status: "active")
      end

      def flag_for(student)
        Flag.new(
          student: student,
          heat_risk: heat_risk?(student),
          disciplinary_recent: disciplinary_recent?(student),
          sibling_alert: sibling_alert_student_ids.include?(student.id),
          care_aura_present: care_aura_present?(student)
        )
      end

      def heat_risk?(student)
        snapshot = active_term && hps_term_snapshots[student.id]
        heat = snapshot&.payload && snapshot.payload["heat"]
        !heat.nil? && heat >= HEAT_RISK_THRESHOLD
      end

      def hps_term_snapshots
        return {} if active_term.nil?

        @hps_term_snapshots ||= AnalyticsBi::HpsTermSnapshot
          .where(institution_id: institution.id, academic_term_id: active_term.id)
          .index_by(&:student_id)
      end

      def active_term
        @active_term ||= Core::AcademicTerm.active.find_by(institution_id: institution.id)
      end

      def disciplinary_recent?(student)
        return false unless context.can?("disciplinary_logs.manage", student)

        StudentSupport::DisciplinaryLog
          .where(institution_id: institution.id, student_id: student.id,
            occurred_at: (as_of - RECENT_DISCIPLINARY_WINDOW_DAYS)..as_of)
          .exists?
      end

      def sibling_alert_student_ids
        return @sibling_alert_student_ids if defined?(@sibling_alert_student_ids)
        return @sibling_alert_student_ids = Set.new unless context.can?("hps.family.view")

        @sibling_alert_student_ids = AnalyticsBi::Lens::SiblingBondAlert
          .for(institution: institution, as_of: as_of)
          .flat_map { |alert| alert.students.map(&:id) }.to_set
      end

      def care_aura_present?(student)
        return false unless context.can?("hps.aura.view", student)

        AnalyticsBi::CareAura.active.where(institution_id: institution.id, student_id: student.id).exists?
      end
    end
  end
end
