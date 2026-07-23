class AddAcademicTermToRoleAssignments < ActiveRecord::Migration[8.1]
  # OPEN_PROCESS.md decisión B2 — role_assignments.valid_from/until se acopla
  # a academic_terms, OPT-IN por asignación (nunca obligatorio): cuando se
  # setea, Core::AcademicTermsController#close capa valid_until al ends_on
  # del término al cerrarlo. Sin setear, comportamiento sin cambios (fechas
  # de calendario independientes, como hoy).
  #
  # on_delete: :nullify, nunca :cascade — un academic_term nunca se destruye
  # hoy (sin acción de destroy), pero si algún día existiera, la asignación
  # de rol no debe desaparecer con él, solo desacoplarse.
  def change
    add_reference :role_assignments, :academic_term, type: :uuid, null: true, index: false,
      foreign_key: { to_table: :academic_terms, on_delete: :nullify }
    add_index :role_assignments, %i[institution_id academic_term_id]
  end
end
