module Calendar
  # Staff management of shared calendar events — molde #4 (§6.6). The delicate
  # piece (v1.27.0): the audience the staff member picks decides WHICH resource
  # is passed to authorize!("calendar.manage", ...), so a single permission
  # scopes three ways off the SAME grant mechanism (Authorization::Assignment#
  # covers? + SCOPE_READERS):
  #   - group audience     -> authorize!(..., section)      [:group reader]
  #   - grade audience     -> authorize!(..., grade_level)  [:grade_level reader]
  #   - institution-wide   -> authorize!(..., institution)  [covered ONLY by an
  #                           institution-wide grant — Institution answers to
  #                           none of the scope readers, so a group/grade actor
  #                           fails here for free]
  # The audience resource is resolved (and tenant-checked via find_by!) BEFORE
  # authorize! — cross-tenant is never implicit. #index shows ONLY real events
  # (Calendar::ManageableScope); the assignment-deadline merge is portal-only
  # (Calendar::Timeline).
  class EventsController < ApplicationController
    def index
      authorize!("calendar.manage")
      @events = Calendar::ManageableScope.new(context: authorization_context).resolve
    end

    def new
      authorize!("calendar.manage")
      @event = Calendar::Event.new
      set_audience_options
    end

    def create
      resource, scope_attrs = resolve_audience
      authorize!("calendar.manage", resource)
      @event = build_event(scope_attrs)

      if @event.save
        redirect_to calendar_events_path, notice: "Evento del calendario creado."
      else
        set_audience_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @event = find_event
      authorize!("calendar.manage", audience_resource(@event))
      set_audience_options
    end

    def update
      @event = find_event
      authorize!("calendar.manage", audience_resource(@event))
      resource, scope_attrs = resolve_audience
      authorize!("calendar.manage", resource)

      if @event.update(event_params.merge(scope_attrs))
        redirect_to calendar_events_path, notice: "Evento del calendario actualizado."
      else
        set_audience_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event = find_event
      authorize!("calendar.manage", audience_resource(@event))
      @event.destroy!
      redirect_to calendar_events_path, notice: "Evento del calendario eliminado."
    end

    private

    def build_event(scope_attrs)
      Calendar::Event.new(event_params.merge(scope_attrs)).tap do |event|
        event.institution = Current.institution
        event.created_by_institution_user_id = Current.institution_user_id
      end
    end

    # The audience the form chose, resolved to [resource, scope_attrs]. The
    # grade/section is tenant-checked (find_by! scoped to Current.institution)
    # before it's ever handed to authorize! — a foreign id 404s, never a
    # silent cross-tenant write.
    def resolve_audience
      case params[:audience]
      when "grade_level" then grade_level_audience
      when "group"       then group_audience
      else [ Current.institution, { scope_grade_level_id: nil, scope_group_id: nil } ]
      end
    end

    def grade_level_audience
      grade = GroupManagement::GradeLevel.find_by!(institution_id: Current.institution_id,
        id: params[:scope_grade_level_id])
      [ grade, { scope_grade_level_id: grade.id, scope_group_id: nil } ]
    end

    def group_audience
      group = GroupManagement::Section.find_by!(institution_id: Current.institution_id,
        id: params[:scope_group_id])
      [ group, { scope_group_id: group.id, scope_grade_level_id: nil } ]
    end

    # The resource whose scope id covers?() compares against for an EXISTING
    # event (same resolution as Calendar::ManageableScope).
    def audience_resource(event)
      return event.group if event.scope_group_id
      return event.grade_level if event.scope_grade_level_id

      Current.institution
    end

    def find_event
      event = Calendar::Event.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if event.nil?

      event
    end

    def set_audience_options
      @grade_levels = GroupManagement::GradeLevel.where(institution_id: Current.institution_id).order(:level_number)
      @groups = GroupManagement::Section.where(institution_id: Current.institution_id).order(:name)
    end

    def event_params
      params.require(:event).permit(:title, :description, :starts_at, :ends_at)
    end
  end
end
