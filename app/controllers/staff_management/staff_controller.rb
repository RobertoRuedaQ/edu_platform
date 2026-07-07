module StaffManagement
  # Closes the "Personal" nav Fase 0 pre-wired (permission staff.read) — not
  # one of the 9 domains in this prompt's list, but the dangling link is the
  # same class of orphan as "Calificaciones"/"Orientación" were. No role/scope
  # spec exists for it anywhere, so this is a minimal directory: blanket
  # authorize!, no per-row Query object (nothing specified to scope by).
  class StaffController < ApplicationController
    def index
      authorize!("staff.read")
      @staff = StaffManagement::StaffRoster.all
    end
  end
end
