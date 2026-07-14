module Core
  module Headcount
    # Pushes ONE headcount number to the control plane for `institution` as of
    # `as_of` — never a live cross-tenant read the other direction.
    #
    # PRECONDITION (not enforced here, by design — see Core::Headcount::SnapshotJob):
    # must run with the tenant's own GUC already fixed (app.current_institution_id),
    # same as any other tenant-scoped query. This method does not set it itself;
    # it trusts its caller, exactly like every Query object in app/domains/*
    # trusts TenantScoped's around_action in the request path.
    #
    # "Headcount" = GroupManagement::Student rows with status "active" for this
    # institution (confirmed choice: enrollments.term is a free string with no
    # FK to academic_terms, so "matrícula activa en el término activo" is NOT
    # a joinable concept in the current schema — see PROJECT_STATE.md recon for
    # S3a). academic_term_label is looked up SEPARATELY, purely as a
    # descriptive label frozen onto the snapshot — it never filters the count.
    module Snapshotter
      module_function

      def call(institution:, as_of: Date.current)
        students = GroupManagement::Student.where(institution_id: institution.id, status: "active")

        breakdown = students.group(:grade_level_id).count.each_with_object({}) do |(grade_level_id, count), acc|
          label = grade_level_id ? GroupManagement::GradeLevel.find_by(id: grade_level_id)&.name : "sin grado"
          acc[label || "grado desconocido"] = count
        end

        active_term = Core::AcademicTerm.active.find_by(institution_id: institution.id)

        snapshot = ControlPlane::StudentHeadcountSnapshot.find_or_initialize_by(
          institution_id: institution.id, as_of_date: as_of
        )
        snapshot.assign_attributes(
          headcount: students.count,
          academic_term_label: active_term&.name,
          breakdown: breakdown,
          source: "tenant_push"
        )
        snapshot.save!

        ControlPlane::Audit.log(action: "headcount.pushed", target: snapshot,
          metadata: { institution_id: institution.id, as_of_date: as_of.to_s, headcount: snapshot.headcount })

        snapshot
      end
    end
  end
end
