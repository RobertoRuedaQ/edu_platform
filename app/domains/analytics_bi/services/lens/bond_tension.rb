module AnalyticsBi
  module Lens
    # Guardian engagement, computed LIVE (§7 default — decision A6: "vivas al
    # inicio; snapshot por término si pesa"), never persisted (BI_DOCUMENT.md
    # §5.6). Reuses EXISTING T1 signals only — no new column, no new table:
    #   last login    -> Core::Session (sessions.created_at, most recent)
    #   message reads -> Communication::ConversationParticipant.last_read_at
    #
    # "Apertura del portal" / "acuse de consentimientos" (also mentioned in
    # §5.6) have NO dedicated tracking anywhere in this codebase today
    # (grep-confirmed no portal-visit or consent-acknowledgement table exists
    # outside analytics_bi's own character_program_consents, which is a
    # different program entirely) — honestly excluded rather than guessed at;
    # documented gap, not silently ignored.
    #
    # engagement = mean of the AVAILABLE 0..1 recency signals (higher = more
    # engaged), nil if none — same convention as SpatialHeatmap/Hps::Snapshotter.
    # tension = 1 - engagement (higher = more concern), same heat-from-wellbeing
    # mold. Recency is bucketed (not a continuous decay curve) — "aburrido
    # sobre ingenioso": <=7 days -> 1.0, <=30 -> 0.6, <=90 -> 0.3, older/never -> 0.0.
    module BondTension
      module_function

      RECENCY_BUCKETS = [ [ 7, 1.0 ], [ 30, 0.6 ], [ 90, 0.3 ] ].freeze

      # engagement: Float 0..1 or nil. tension: Float 0..1 or nil (1 - engagement).
      Result = Data.define(:engagement, :tension) do
        def label
          return "Sin datos suficientes" if engagement.nil?

          case engagement
          when 0.7.. then "Comprometido"
          when 0.3...0.7 then "Seguimiento moderado"
          else "Necesita seguimiento"
          end
        end
      end

      def for(guardian_user_id:, institution: Current.institution, as_of: Date.current)
        signals = [
          recency_score(last_login_at(guardian_user_id), as_of),
          recency_score(last_message_read_at(guardian_user_id, institution), as_of)
        ].compact
        return Result.new(engagement: nil, tension: nil) if signals.empty?

        engagement = (signals.sum / signals.size).round(3)
        Result.new(engagement: engagement, tension: (1.0 - engagement).round(3))
      end

      def last_login_at(guardian_user_id)
        Core::Session.where(user_id: guardian_user_id).maximum(:created_at)
      end

      def last_message_read_at(guardian_user_id, institution)
        Communication::ConversationParticipant
          .where(institution_id: institution.id, guardian_user_id: guardian_user_id)
          .maximum(:last_read_at)
      end

      def recency_score(timestamp, as_of)
        return nil if timestamp.nil?

        days_ago = (as_of - timestamp.to_date).to_i
        bucket = RECENCY_BUCKETS.find { |max_days, _| days_ago <= max_days }
        bucket&.last || 0.0
      end
    end
  end
end
