class CreateExtracurriculars < ActiveRecord::Migration[8.1]
  # extracurriculars (net-new addon domain, v1.27.0, MVP item #8): actividades
  # (deporte/arte/refuerzo), inscripción con cupo, instructor por-fila
  # (ownership, NO scope de rol), portal del acudiente (inscribir/desinscribir),
  # y actividad paga = un Finance::Charge (nunca un cobro propio de este
  # dominio). Dos tablas, ambas tenant-scoped + RLS ENABLE+FORCE.
  def change
    # --- activities -------------------------------------------------------
    # El catálogo. instructor_staff_member_id es NULLABLE + nullify (misma
    # razón que attendance.recorded_by / assignments.created_by): una actividad
    # existe ANTES de asignarle instructor, y sobrevive si el StaffMember se
    # retira. academic_term_id es NOT NULL + cascade: una actividad SIEMPRE
    # pertenece a un término (cierra parte de B2 — el FK real que schedules
    # aún no tiene en todas partes); los términos no se destruyen en esta app,
    # pero si un tenant se elimina, sus términos y actividades caen juntos.
    create_table :activities, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :academic_term, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :academic_terms, on_delete: :cascade }
      t.references :instructor_staff_member, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :staff_members, on_delete: :nullify }
      t.string  :kind, null: false
      t.string  :name, null: false
      # Cupo finito: la regla de negocio central del dominio es rechazar sobre
      # capacidad. "Ilimitado" (columna nullable) queda diferido a propósito —
      # no se inventa un estado que hoy no gana su lugar.
      t.integer :capacity, null: false
      # Dinero NUEVO -> *_cents bigint (F6), NO decimal como finance (que es
      # legacy grandfathered). null/0 == gratuita. El puente a Finance::Charge
      # (decimal) es explícito y de una sola vez en EnrollmentCreator.
      t.bigint  :fee_cents, null: true
      # Horario/lugar PROPIOS y simples (texto) — este dominio NO depende de
      # schedules (cuya mitad de timetable/rooms no tiene tablas reales).
      t.string  :location, null: true
      t.string  :schedule_info, null: true
      # Ciclo de vida idéntico a assignments (draft->published->archived): el
      # portal del acudiente es superficie de ESCRITURA, así que draft oculta
      # una actividad a medio configurar de la inscripción, published la abre,
      # archived cierra la inscripción preservando el roster (disciplina de
      # append, nunca destruir).
      t.string  :status, null: false, default: "draft"

      t.timestamps
    end

    # CORE: el índice de supervisión y el portal ("published del término
    # activo") filtran por (institution, term, status) en cada render.
    add_index :activities, %i[institution_id academic_term_id status],
      name: "idx_activities_on_institution_term_status"
    # CORE: Extracurriculars::ActivityScope filtra las actividades PROPIAS de
    # un instructor por este FK en cada render del panel del instructor.
    add_index :activities, %i[institution_id instructor_staff_member_id],
      name: "idx_activities_on_institution_instructor"

    add_check_constraint :activities, "kind IN ('sport','art','tutoring')",
      name: "activities_kind_check"
    add_check_constraint :activities, "status IN ('draft','published','archived')",
      name: "activities_status_check"
    add_check_constraint :activities, "capacity > 0",
      name: "activities_capacity_positive_check"
    add_check_constraint :activities, "fee_cents IS NULL OR fee_cents >= 0",
      name: "activities_fee_cents_nonneg_check"

    enable_rls :activities

    # --- activity_enrollments --------------------------------------------
    # Estudiante <-> actividad. Soft: NUNCA se destruye — status active/withdrawn
    # + timestamps (misma disciplina append que announcements/attendance/
    # submissions). enrolled_via responde "inscribió el acudiente vs el colegio"
    # directamente y barato; enrolled_by_user_id es el humano que actuó (Core::
    # User, sirve para staff Y acudiente — atribución, nunca frontera de
    # escritura, misma lógica que submissions.submitted_by_user_id). La
    # atribución de la BAJA queda diferida (solo status + withdrawn_at).
    create_table :activity_enrollments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :institution, type: :uuid, null: false, index: false,
        foreign_key: { on_delete: :cascade }
      t.references :activity, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :activities, on_delete: :cascade }
      t.references :student, type: :uuid, null: false, index: false,
        foreign_key: { to_table: :students, on_delete: :cascade }
      t.string   :status, null: false, default: "active"
      t.datetime :enrolled_at, null: false
      t.datetime :withdrawn_at, null: true
      t.string   :enrolled_via, null: false
      t.references :enrolled_by_user, type: :uuid, null: true, index: false,
        foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    # CORE + INTEGRIDAD: garantiza <=1 inscripción ACTIVA por (actividad,
    # estudiante) incluso bajo concurrencia — el índice no corre carreras como
    # sí lo haría `validates uniqueness`. Parcial WHERE status='active' (literal
    # inmutable): permite el historial de re-inscripción (varias filas withdrawn
    # + una active), coherente con "append, nunca destruir". Es el respaldo de
    # BD del chequeo transaccional con lock en EnrollmentCreator (el cupo en sí
    # es un invariante agregado, NO expresable barato como constraint declarativo
    # sin un trigger — y este repo no usa triggers).
    add_index :activity_enrollments, %i[institution_id activity_id student_id],
      unique: true, where: "status = 'active'",
      name: "idx_activity_enrollments_active_unique"
    # CORE: el roster por actividad y el COUNT de activos para el chequeo de
    # cupo filtran por (institution, activity).
    add_index :activity_enrollments, %i[institution_id activity_id],
      name: "idx_activity_enrollments_on_institution_activity"
    # CORE: el portal ("las actividades de mi hijo/mías") filtra por
    # (institution, student).
    add_index :activity_enrollments, %i[institution_id student_id],
      name: "idx_activity_enrollments_on_institution_student"

    add_check_constraint :activity_enrollments, "status IN ('active','withdrawn')",
      name: "activity_enrollments_status_check"
    add_check_constraint :activity_enrollments, "enrolled_via IN ('staff','guardian')",
      name: "activity_enrollments_enrolled_via_check"

    enable_rls :activity_enrollments
  end
end
