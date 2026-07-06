# frozen_string_literal: true

module ControlPlane
  module Stubs
    # A platform-health alert surfaced on the dashboard (quota breaches, past-due
    # invoices, deprecated addons still in use, …).
    #
    # TODO: reemplazar por agregado real de señales de plataforma.
    Alert = Data.define(
      :level,     # "info" | "warning" | "danger"
      :title,
      :detail
    )
  end
end
