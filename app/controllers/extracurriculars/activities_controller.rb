module Extracurriculars
  # Catálogo de actividades (molde #4). DOS gates en serie de RBAC dentro del
  # namespace, según la capacidad:
  #   - acceso a la superficie (index/show): activity.instruct — el PISO que
  #     ambos roles tienen (activity_coordinator se siembra con manage +
  #     instruct); Extracurriculars::ActivityScope decide qué filas ve cada uno
  #     (coordinador todas por manage, instructor solo las suyas por FK).
  #   - escritura del catálogo (new/create/edit/update/publish/archive):
  #     activity.manage — solo el coordinador crea/edita actividades; el
  #     instructor nunca. (Gestionar el ROSTER de su propia actividad sí lo
  #     puede el instructor — ver EnrollmentsController.)
  # Gate #1 (entitlement "extracurriculars") corre antes que todo esto, inferido
  # del namespace por Entitlement::Controller.
  class ActivitiesController < ApplicationController
    def index
      authorize!("activity.instruct")
      @activities = activity_scope.resolve.to_a
      # Un solo GROUP BY para los "inscritos/cupo" del listado — nunca un
      # count por-fila (evita el N+1 que un @activities.each { a.active... }
      # dispararía).
      @active_counts = Extracurriculars::Enrollment.active
        .where(institution_id: Current.institution_id, activity_id: @activities.map(&:id))
        .group(:activity_id).count
    end

    def show
      authorize!("activity.instruct")
      @activity = activity_scope.resolve.find(params[:id])
      @enrollments = @activity.active_enrollments.includes(:student).to_a
      @eligible_students = eligible_students_for(@activity)
      @idempotency_key = SecureRandom.uuid
    end

    def new
      authorize!("activity.manage")
      @activity = Extracurriculars::Activity.new(status: "draft")
      load_form_collections
    end

    def create
      authorize!("activity.manage")
      @activity = Extracurriculars::Activity.new(institution: Current.institution, status: "draft")
      assign_activity_attributes(@activity)

      if @activity.save
        redirect_to extracurriculars_activity_path(@activity), notice: "Actividad creada."
      else
        load_form_collections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("activity.manage")
      @activity = find_activity
      load_form_collections
    end

    def update
      authorize!("activity.manage")
      @activity = find_activity
      assign_activity_attributes(@activity)

      if @activity.save
        redirect_to extracurriculars_activity_path(@activity), notice: "Actividad actualizada."
      else
        load_form_collections
        render :edit, status: :unprocessable_entity
      end
    end

    def publish
      authorize!("activity.manage")
      find_activity.publish!
      redirect_to extracurriculars_activity_path(params[:id]), notice: "Actividad publicada."
    end

    def archive
      authorize!("activity.manage")
      find_activity.archive!
      redirect_to extracurriculars_activity_path(params[:id]), notice: "Actividad archivada."
    end

    private

    # manage ve/edita cualquiera de la institución; el gate ya garantizó manage
    # aquí, así que basta el scope de tenant (no el de propiedad de instructor).
    def find_activity
      activity = Extracurriculars::Activity.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if activity.nil?

      activity
    end

    def activity_scope
      Extracurriculars::ActivityScope.new(context: authorization_context, actor_staff_member: actor_staff_member)
    end

    # El StaffMember del actor — la ancla de "mis actividades" del instructor.
    # Misma resolución que Attendance::RecordsController.
    def actor_staff_member
      @actor_staff_member ||= StaffManagement::StaffMember.find_by(
        institution_id: Current.institution_id, institution_user_id: Current.institution_user_id
      )
    end

    # Los estudiantes inscribibles desde supervisión: matriculados en el término
    # activo (Schedules::ActiveTermEnrollmentScope, nunca re-derivado) menos los
    # ya inscritos activos en ESTA actividad.
    def eligible_students_for(activity)
      already = activity.active_enrollments.pluck(:student_id)
      Schedules::ActiveTermEnrollmentScope.resolve(institution: Current.institution)
        .where.not(id: already)
        .order(:last_name, :first_name)
    end

    def load_form_collections
      @terms = Core::AcademicTerm.where(institution_id: Current.institution_id).order(starts_on: :desc)
      @staff = StaffManagement::StaffMember.where(institution_id: Current.institution_id).includes(institution_user: :user)
    end

    # Resolvemos term/instructor por lookup tenant-scoped (nunca mass-assign de
    # un id de params): el FK de Postgres valida contra TODAS las filas
    # ignorando RLS, así que un id cross-tenant pasaría el FK — el find_by con
    # institution_id es la barrera real. term nil hace fallar la validación
    # belongs_to (mensaje amable), no un 500.
    def assign_activity_attributes(activity)
      activity.name = params.dig(:activity, :name)
      activity.kind = params.dig(:activity, :kind)
      activity.capacity = params.dig(:activity, :capacity)
      activity.location = params.dig(:activity, :location).presence
      activity.schedule_info = params.dig(:activity, :schedule_info).presence
      activity.fee_cents = parse_fee_cents(params.dig(:activity, :fee))
      activity.academic_term = Core::AcademicTerm.find_by(
        institution_id: Current.institution_id, id: params.dig(:activity, :academic_term_id)
      )
      instructor_id = params.dig(:activity, :instructor_staff_member_id).presence
      activity.instructor_staff_member = instructor_id && StaffManagement::StaffMember.find_by(
        institution_id: Current.institution_id, id: instructor_id
      )
    end

    # COP en pesos -> centavos, BigDecimal exacto (NUNCA Float). Vacío = gratis.
    def parse_fee_cents(value)
      return nil if value.blank?

      (BigDecimal(value.to_s) * 100).to_i
    rescue ArgumentError
      nil
    end
  end
end
