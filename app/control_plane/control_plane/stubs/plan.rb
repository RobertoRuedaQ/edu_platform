# frozen_string_literal: true

module ControlPlane
  module Stubs
    # A platform plan: the BASE piece of hybrid billing (base per student, in
    # volume brackets). Addon fees and usage overage are ORTHOGONAL and priced
    # per-addon, not here.
    #
    # TODO: reemplazar por modelo real (ControlPlane::Plan).
    Plan = Data.define(
      :key,
      :name,
      :status,            # "available" | "beta" | "deprecated"
      :currency,
      :brackets           # [PriceBracket], ascending, non-overlapping
    ) do
      def entry_rate = brackets.first&.per_student
    end
  end
end
