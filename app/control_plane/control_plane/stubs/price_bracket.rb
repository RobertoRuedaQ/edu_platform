# frozen_string_literal: true

module ControlPlane
  module Stubs
    # One tier of the per-student base rate. Brackets are volume steps: the
    # more students, the lower the per-student rate. `to == nil` is the
    # open-ended top bracket.
    #
    # TODO: reemplazar por modelo real (ControlPlane::PriceBracket).
    PriceBracket = Data.define(
      :from,          # first student count in this bracket (inclusive)
      :to,            # last student count (inclusive); nil = and up
      :per_student    # rate applied to students within the bracket
    ) do
      def open_ended? = to.nil?
    end
  end
end
