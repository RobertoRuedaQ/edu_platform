Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Role-aware landing (clic 0) for staff users.
  root to: "dashboard#show"

  # "Mis datos" — staff self-service (v1.10.0). Identity-gated, not in
  # Navigation::Registry on purpose: every registry entry is filtered by
  # can?(item.permission), but this page has no permission gate at all
  # (SS2) — it's reachable by every authenticated staff member regardless
  # of role. Linked directly from the app shell header instead.
  resource :self_service, only: :show, path: "mis_datos", controller: "self_service"

  # --- Authentication (per-subdomain login + mandatory email OTP) -----------
  # Singular resources, matching the institution_switch style below. new/create
  # run pre-session (allow_unauthenticated_access); destroy requires a session.
  resource :session, only: %i[new create destroy]
  resource :email_otp, only: %i[new create]

  # Registro por invitación: token-keyed, not id-keyed — nobody browses these
  # by id. Reachable pre-session (allow_unauthenticated_access); the tenant
  # resolves from the link's subdomain, same as login.
  resources :invitations, only: %i[edit update], param: :token do
    member { post :discrepancy }
  end

  # --- Role-aware shell (Part 2) --------------------------------------------
  # Global search escape hatch (stub results) + institution switcher (stub).
  get "search", to: "search#index", as: :search
  resource :institution_switch, only: :create

  # --- Person portals (Part 4) ----------------------------------------------
  # Separate surfaces from the staff shell above: own minimal layout, no domain
  # nav/search. Resolved by RELATION (students.user_id / guardian_students),
  # never by role_assignments — see Portals::StudentPortalController /
  # Portals::GuardianPortalController.
  scope path: "portal", module: "portals", as: "portal" do
    resource :student, only: :show, controller: "student_portal" do
      resource :cafeteria, only: :show, controller: "student_cafeteria"
      resource :transport, only: :show, controller: "student_transport"
      # report_cards (v1.17.0): published-only, by self-scope — no
      # authorize!, outside Navigation::Registry (§7). Plural: many terms.
      resources :report_cards, only: :index, controller: "student_report_cards"
      # communication (v1.19.0): org-wide, NOT per-self-scope — membership
      # read surface, same shared feed the staff/guardian surfaces use.
      resources :announcements, only: :index, controller: "student_announcements"
      # calendar (v1.27.0): the student's own merged timeline (real events +
      # published-assignment deadlines) — self-scope, no authorize!, outside
      # Navigation::Registry. Singular (one timeline per student), like
      # cafeteria/transport, not plural like assignments.
      resource :calendar, only: :show, controller: "student_calendar"
      # attendance (v1.28.0): the student's own attendance history — self
      # scope, no authorize!, outside Navigation::Registry. Singular (one
      # history per student), like calendar/cafeteria/transport.
      resource :attendance, only: :show, controller: "student_attendance"
      # assignments (v1.21.0, slice 1/4; #show + #submission v1.22.0):
      # published-only, by self-scope, own grade read from the same
      # schedules::Assessment row report_cards reads. No authorize!, outside
      # Navigation::Registry. #submission is the FIRST portal write —
      # StudentSubmissionsController re-derives the same self-scope, never
      # trusts params directly (see that controller's docstring).
      resources :assignments, only: %i[index show], controller: "student_assignments" do
        resource :submission, only: :create, controller: "student_submissions"
        # attachments (v1.24.0, slice 3) — nested under the ASSIGNMENT, not
        # a submission resource (submissions have no route of their own to
        # nest under); the controller resolves student -> assignment ->
        # existing submission -> attachment, same chained-scope discipline
        # as StudentSubmissionsController. #show streams the file through
        # this controller — NEVER Active Storage's own signed routes.
        resources :attachments, only: %i[create show destroy], controller: "student_attachments"
        # materials (v1.25.0, slice 3b) — read-only here: the TEACHER writes
        # these (RBAC, see the assignments:: namespace below), the portal
        # only serves them through the same StudentView.for(student) scope
        # that already gates #show — a draft assignment's materials are
        # unreachable for free, since the assignment itself isn't in scope.
        resources :materials, only: :show, controller: "student_materials"
      end
      # extracurriculars (v1.27.0): solo lectura — "mis actividades" (las
      # inscripciones activas del propio estudiante), por self-scope. La
      # escritura es del acudiente, no del estudiante. Sin authorize!, fuera
      # de Navigation::Registry (§7).
      resources :activities, only: %i[index show], controller: "student_activities"
    end
    resource :guardian, only: :show, controller: "guardian_portal" do
      # Per-child read-only summary (v1.9.0) — resolved through
      # Core::Access::GuardianScope, so a child not in the caller's own
      # active-links scope 404s (find on an already-scoped relation), never
      # renders. Plural on purpose: a guardian has many children; the
      # student/cafeteria/transport sub-resources above stay singular
      # (a student only ever has ONE of each, resolved via self-scope).
      resources :students, only: :show, controller: "guardian_students" do
        # report_cards (v1.17.0): published-only, by relation — nested under
        # the SPECIFIC child (unlike cafeteria/transport, which summarize
        # ALL children on one page) since a term's boletín is inherently
        # per-child. No authorize!, outside Navigation::Registry (§7).
        resources :report_cards, only: :index, controller: "guardian_report_cards"
        # finance (v1.18.0): read-only account statement, by relation — same
        # per-child nesting as report_cards (substantial content per child).
        # No authorize!, outside Navigation::Registry, no write action.
        resource :finance, only: :show, controller: "guardian_finance"
        # assignments (v1.21.0, slice 1/4; #show + #submission v1.22.0):
        # published-only, per-child (a subject's assignments are inherently
        # per-child, unlike org-wide announcements). No authorize!, outside
        # Navigation::Registry. #submission lets a guardian submit ON
        # BEHALF of this specific already-scoped child (B1).
        resources :assignments, only: %i[index show], controller: "guardian_assignments" do
          resource :submission, only: :create, controller: "guardian_submissions"
          # attachments (v1.24.0, slice 3) — on behalf of THIS specific
          # already-scoped child (B1), same discipline as :submission above.
          resources :attachments, only: %i[create show destroy], controller: "guardian_attachments"
          # materials (v1.25.0, slice 3b) — read-only, same chained scope
          # (GuardianScope -> StudentView.for(this child)) as :attachments.
          resources :materials, only: :show, controller: "guardian_materials"
        end
        # calendar (v1.27.0): this child's merged timeline (real events +
        # their published-assignment deadlines) — per-child (like finance/
        # report_cards), resolved through GuardianScope. No authorize!,
        # outside Navigation::Registry.
        resource :calendar, only: :show, controller: "guardian_calendar"
        # attendance (v1.28.0): this child's attendance history — per-child
        # (like finance/report_cards/calendar), resolved through
        # GuardianScope. No authorize!, outside Navigation::Registry.
        resource :attendance, only: :show, controller: "guardian_attendance"
        # extracurriculars (v1.27.0): lectura + ESCRITURA per-child. index/show
        # listan las actividades del hijo + el catálogo inscribible; la
        # inscripción anida bajo la actividad (resource singular: un hijo tiene
        # a lo sumo UNA inscripción activa por actividad, resuelta por relación,
        # sin :id). Inscribir/desinscribir EN NOMBRE de este hijo ya scopeado
        # (B1), misma disciplina que :submission. Sin authorize!, fuera de
        # Navigation::Registry.
        resources :activities, only: %i[index show], controller: "guardian_activities" do
          resource :enrollment, only: %i[create destroy], controller: "guardian_activity_enrollments"
        end
      end
      # communication (v1.19.0): org-wide, NOT per-child — a sibling of
      # :students, not nested under it.
      resources :announcements, only: :index, controller: "guardian_announcements"
      # communication (v1.20.0, subsistema B): reply-only bandeja — no
      # compose, no close/reopen (§0/§4).
      resources :inbox, only: %i[index show], controller: "guardian_inbox" do
        resources :messages, only: :create, controller: "guardian_messages"
      end
      resource :cafeteria, only: :show, controller: "guardian_cafeteria"
      resource :transport, only: :show, controller: "guardian_transport"
    end
  end

  # --- teacher_management (domain views, Prompt Unificado) ------------------
  # Scope is department (area_lead) or institution (coordinator/principal/HR/
  # secretary/institution_admin) — see TeacherManagement::TeacherScope. The
  # nested evaluation is the acceptance case: teacher.evaluate, department-scoped.
  namespace :teacher_management do
    resources :teachers, only: %i[index show] do
      resources :evaluations, only: %i[new create], controller: "teacher_evaluations"
    end
    resources :departments, only: %i[index show]
  end

  # --- group_management (domain views, Prompt Unificado) --------------------
  # Absorbs the students#index/show Apéndice A wrote under "core" — the real
  # owner is group_management (Student/Section/GradeLevel live here; see the
  # config/navigation/group_management.rb pre-wired by Fase 0). groups.manage
  # is a narrower permission than groups.view: viewing a roster and editing
  # who's on it are different capabilities.
  namespace :group_management do
    resources :students, only: %i[index show]
    resources :groups, only: %i[index show] do
      resource :membership, only: %i[edit update], controller: "memberships"
      # Physical classroom geometry (v1.36.0, BI_DOCUMENT.md Slice 2). Owned by
      # group_management (decision A2), gated by groups.manage. classroom_layout
      # is singular (one current version per group); reconfiguring opens the
      # next version. seat_assignments key on student_id for destroy (unassign).
      resource :classroom_layout, only: %i[show create], controller: "classroom_layouts"
      resources :seat_assignments, only: %i[create destroy], controller: "seat_assignments"
    end
  end

  # --- schedules (domain views, Prompt Unificado) ---------------------------
  # Two features under one domain: grades (real Subject/Enrollment/Assessment
  # models; "grades" path fulfills the Fase 0 pre-wired "Calificaciones" nav)
  # and timetable/rooms (Apéndice A; fully stub — no periods/rooms table
  # exists at all). schedule.view is the actor's OWN group's slots;
  # timetable.manage is the institution-wide builder view.
  namespace :schedules do
    resources :subjects, only: %i[index show], path: "grades" do
      resources :grade_entries, only: %i[new create]
    end
    resource :my_schedule, only: :show, controller: "my_schedule"
    resource :timetable, only: :show, controller: "timetables"
    resources :rooms, only: %i[index show]
  end

  # --- counseling (domain views, Prompt Unificado) --------------------------
  # Fulfills the "Orientación" nav Fase 0 pre-wired (permission counseling.read)
  # at the EXACT pre-wired path (path: "" keeps cases#index at /counseling
  # itself, not /counseling/cases). Absorbed from Apéndice A's student_support
  # bullet — the real Case/SessionNote/Referral models live in this separate,
  # more-sensitive domain (see app/domains/counseling/README.md).
  namespace :counseling do
    resources :cases, only: %i[index show], path: ""
  end

  # --- student_support (domain views, Prompt Unificado) ---------------------
  # SENSIBLE. medical_history/accommodations/disciplinary_logs are per-student,
  # nested under students (student_support does not own the Student resource —
  # group_management does — so only the id param is nested here, no
  # students#index/show of its own).
  namespace :student_support do
    get "dashboard", to: "support_dashboard#show", as: "support_dashboard"

    resources :students, only: [] do
      resource :medical_history, only: :show, controller: "medical_history"
      resources :accommodations, only: %i[index edit update]
      resources :disciplinary_logs, only: %i[index create]
    end
  end

  # --- cafeteria (domain views, Prompt Unificado) ---------------------------
  # Only DietaryRestriction is real (seeded); Menu/Purchase/StudentAccount
  # don't exist as models. The checkout block is genuine logic (cross-
  # referencing the student's allergies against the menu item), not cosmetic —
  # _checkout_line only ever REFLECTS the flag this controller computes.
  # balance.view reuses the existing finance.read (treasury already owns
  # "cartera y pagos"); menu has no group/department dimension to scope by.
  namespace :cafeteria do
    get "menu", to: "menu#index", as: "menu"
    resources :checkouts, only: %i[new create]
    resources :balances, only: :index
  end

  # --- attendance (net-new domain, v1.16.0, MVP critical path item #2) ------
  # Daily-by-homeroom only. groups#index lists the actor's OWN groups (scope);
  # records#new/#create take attendance for a (group, date) — no groups#show,
  # a bare group page would have nothing real beyond the link into records#new.
  namespace :attendance do
    resources :groups, only: :index do
      resources :records, only: %i[new create]
    end
  end

  # --- report_cards (net-new domain, v1.17.0, MVP critical path item #3) ---
  # Boletines sobre la mitad de calificaciones ya real de `schedules`.
  # groups#index lists the actor's OWN groups (report_card.view scope);
  # publications#new/#create preview + publish a group's roster for the
  # active term — no groups#show, same rationale as attendance's groups#index.
  namespace :report_cards do
    resources :groups, only: :index do
      resources :publications, only: %i[new create]
    end
  end

  # --- finance (UI de tesorería, v1.18.0, MVP critical path item #4) --------
  # Models (Charge/Payment/PaymentPlan/Installment/StudentAccount) and the
  # entitlement/nav registration all predate this slice (v1.3.0/S2b) — this
  # wires the first real controller. `path: ""` keeps accounts#index at the
  # bare `/finance` the pre-existing nav entry already points to.
  # payments/charges only ever nest under an account — no accounts#new
  # (accounts aren't created via UI this slice) and no plan/installment
  # management (deferred, see HISTORIA.md v1.18.0).
  namespace :finance do
    resources :accounts, path: "", only: %i[index show] do
      resources :payments, only: %i[new create]
      resources :charges, only: %i[new create]
    end
  end

  # --- communication (v1.19.0, MVP critical path item #5) -------------------
  # Subsystem (A) anuncios ONLY — messaging (B) is a future slice with its
  # own fresh model (see HISTORIA.md v1.19.0's spec annex). Two DISTINCT
  # gates on purpose: #announcements is the RBAC publish/manage surface
  # (announcement.publish); #feed below is the membership read surface (no
  # authorize!, outside Navigation::Registry).
  namespace :communication do
    resources :announcements, only: %i[index new create edit update] do
      post :retract, on: :member
    end
    resource :feed, only: :show, controller: "feed"

    # --- subsystem (B): mensajería (v1.20.0) ---------------------------
    # FOUR distinct access paths, FOUR distinct controllers, even though
    # all four touch the same three tables (§ Guardrails, "nunca colapsar"):
    # compose (RBAC) / inbox (participation) / messages (participation
    # reply) / conversation_audits (RBAC, different permission from compose).
    resources :conversations, only: %i[new create]
    resources :inbox, only: %i[index show] do
      resources :messages, only: :create
      post :close, on: :member
      post :reopen, on: :member
    end
    resources :conversation_audits, only: %i[index show]
  end

  # --- assignments (v1.21.0, MVP critical path item #6, slice 1/4) ----------
  # Publish + view + grade directly only — submission/attachments/rubrics are
  # future slices (see HISTORIA.md v1.21.0's roadmap annex). subjects#index
  # lists the actor's OWN subjects (assignment.manage scope); assignments
  # nest under a subject; grading is a member action on the SAME resource,
  # never a separate grades namespace, since the grade always writes to the
  # one gradebook (schedules::Assessment) via Assignments::GradeRecorder.
  namespace :assignments do
    # rúbricas (v1.26.0, slice 4) — the reusable LIBRARY, top-level (never
    # nested under a subject: a docente's rubrics are reusable across every
    # subject/task they teach, not scoped to one). Same assignment.manage
    # gate as the rest of this namespace; author-owned visibility enforced
    # in the controller, not a route concern.
    resources :rubric_templates, only: %i[index new create edit update destroy] do
      resources :rubric_criteria, only: %i[create update destroy], controller: "rubric_criteria"
      resources :rubric_levels, only: %i[create update destroy], controller: "rubric_levels"
      # ONE bulk save for the whole descriptor matrix (criteria × levels) —
      # same "hash of nested params in one POST" shape #grade already uses
      # for scores/group_scores, not a per-cell round trip.
      resource :cell_descriptors, only: :update, controller: "rubric_cell_descriptors"
    end
    resources :subjects, only: :index do
      resources :assignments, only: %i[index new create edit update show destroy] do
        post :publish, on: :member
        post :archive, on: :member
        post :grade, on: :member
        # group work (v1.23.0) — forming a group is scoped to ONE
        # assignment (groups are never reused across tasks, §0), so this
        # nests under :assignments, not a top-level resource.
        resources :submission_groups, only: :create
        # attachments (v1.24.0, slice 3) — teacher-side is READ-ONLY: the
        # teacher never uploads here, only views/downloads what a student/
        # guardian attached (§6). #show streams through
        # Assignments::AttachmentsController, scoped by the SAME
        # assignment.manage authorize! this whole namespace already gates —
        # never Active Storage's own signed routes.
        resources :attachments, only: :show
        # materials (v1.25.0, slice 3b) — the FLIP side of :attachments:
        # here the teacher WRITES (RBAC, same assignment.manage gate as the
        # rest of this namespace), never a portal relation. Allowed while
        # draft/published, blocked once archived — same "archived = frozen"
        # rule as entrega attachments.
        resources :materials, only: %i[create show destroy]
      end
    end
  end

  # --- calendar (net-new domain, v1.27.0, MVP critical path item #7) --------
  # Shared calendar with caregivers. events#index lists real events within the
  # actor's scope (calendar.manage); new/create/edit/update/destroy manage
  # them. The audience picked on the form decides the resource passed to
  # authorize! (see Calendar::EventsController). Portal timelines are wired in
  # the portals block above (relation-gated, no authorize!), NOT here.
  namespace :calendar do
    resources :events, only: %i[index new create edit update destroy]
  end

  # --- extracurriculars (net-new addon domain, v1.27.0, MVP item #8) --------
  # activities#index lista el catálogo dentro del alcance del actor
  # (Extracurriculars::ActivityScope: coordinador todas, instructor solo las
  # suyas por PROPIEDAD de fila — NO un scope de rol nuevo). enrollments anida
  # bajo una actividad: inscribir/desinscribir desde supervisión (la OTRA vía,
  # junto con la del acudiente en el portal). Sin activities#destroy — una
  # actividad se archiva (append), nunca se borra; publish/archive son
  # transiciones de estado en la misma fila (gate activity.manage).
  namespace :extracurriculars do
    resources :activities, except: %i[destroy] do
      member do
        post :publish
        post :archive
      end
      resources :enrollments, only: %i[create destroy]
    end
  end

  # --- transportation (domain views, Prompt Unificado) ----------------------
  # No models/schema at all — the most greenfield domain yet. boarding.manage
  # introduced a new scope dimension (:route) since a bus route is neither a
  # department, grade_level, nor school section — see
  # Authorization::Assignment::SCOPE_READERS. boarding#show is "solo UI; sin
  # persistencia ni broadcast" per Apéndice A.
  namespace :transportation do
    resources :routes, only: %i[index show]
    resource :boarding, only: :show, controller: "boarding"
    resources :boarding_events, only: :create
  end

  # --- analytics_bi (domain views, Prompt Unificado) ------------------------
  # SENSIBLE. cross_tenant_reports is the ONE sanctioned cross-tenant path
  # (edu_bi_reader, BYPASSRLS, audited — see lib/tasks/roles.rake); the normal
  # app connection (edu_app_runtime) NEVER gets that. InstitutionDashboard
  # (v1.34.0) and CrossTenantReportRoster (v1.35.0) are real; spatial_classrooms
  # is HPS Lens 1 (v1.36.0, BI_DOCUMENT.md Slice 2) — a tenant-scoped
  # supervision surface (hps.classroom.view) that only reads the
  # group_management-owned classroom geometry.
  namespace :analytics_bi do
    get "dashboard", to: "institution_dashboard#show", as: "institution_dashboard"
    resources :cross_tenant_reports, only: :index
    resources :spatial_classrooms, only: %i[index show]
  end

  # --- identity_access (domain views, Prompt Unificado) ---------------------
  # SENSIBLE. Admin views ONLY — the authorization gate itself (Fase 0) is
  # untouched. roles.manage (already in the catalog, already pre-wired to
  # "Roles y accesos" -> /identity_access/roles) covers users/roles/
  # assignments alike: super_admin's cross-tenant view would duplicate
  # control_plane's existing surface, so this stays institution_admin-only.
  namespace :identity_access do
    resources :users, only: %i[index show]
    resources :roles, only: %i[index show]
    resources :assignments, only: %i[index new create]

    # Gestión de personas/cuentas: crear (Core::People::Resolver), invitar/
    # reenviar (Issuer), suspender/reactivar (InstitutionUser). people.manage
    # is a DIFFERENT capability from roles.manage above — onboarding a human
    # isn't the same as granting institution_admin.
    resources :people, only: %i[index new create] do
      member do
        post :resend_invitation
        post :suspend
        post :reactivate
      end
    end

    # Batch alta (RosterImport slice, students only) — same people.manage
    # gate as :people above. index/new/create/show only; no update/destroy,
    # a batch is append-only (parse -> validate -> commit).
    resources :roster_imports, only: %i[index new create show] do
      member { post :commit }
    end

    # Audit viewer + discrepancy inbox (onboarding slice 5). audit_events.read
    # gated (RBAC, unlike self-service). Read-only: index/discrepancies only —
    # audit_events is append-only, no action here ever mutates a row.
    resources :audit_events, only: :index do
      collection { get :discrepancies }
    end
  end

  # --- staff_management (closes an orphaned Fase 0 nav entry) ---------------
  # Not one of the 9 domains in the Prompt Unificado list, but "Personal" has
  # sat unfulfilled since Fase 0 — same class of gap as Calificaciones/
  # Orientación were. Minimal directory only; no Apéndice A spec exists for it.
  namespace :staff_management do
    get "staff", to: "staff#index", as: "staff"
  end

  # --- Control plane (super-admin, cross-tenant, above RLS) -----------------
  # Its own namespace, mounted at /control_plane. NOT a tenant domain: no RLS
  # scoping applies. Controllers live in app/control_plane/control_plane/ and
  # resolve to ControlPlane::*Controller. S0 auth (platform_admins + email
  # MFA) is real as of this slice — see ControlPlane::BaseController.
  namespace :control_plane do
    root to: "dashboard#show"

    resource  :session, only: %i[new create destroy]
    resource  :email_otp, only: %i[new create]
    resources :platform_admins, only: %i[index show] do
      member do
        patch :suspend
        patch :reactivate
      end
    end

    # new/create (v1.29.0, MVP item #10): Provisioning::ProvisionInstitution
    # is the ONLY writer — no edit/destroy, see InstitutionsController.
    resources :institutions, only: %i[index show new create] do
      # S2a: subscriptions nested under their institution, same shape as
      # price_tiers nested under plans below. No index/edit — "history" is
      # shown on the institution's own show page; the snapshot is immutable.
      resources :subscriptions, only: %i[new create show] do
        member do
          patch :terminate
        end
      end
      # S4: per-institution invoice workflow. No index here — the flat,
      # cross-institution overview lives at the top-level invoices#index
      # below. No edit — a draft is regenerated (recut), never hand-edited.
      resources :invoices, only: %i[new create show] do
        member do
          patch :finalize
          patch :void
          patch :recut
        end
      end
    end
    resources :addons, except: %i[destroy] do
      member do
        patch :retire
        patch :reactivate
      end
    end
    # Editor per institution (?institution_id= on index/new/create). Real CRUD
    # as of S2a — was index-only stub before.
    resources :entitlements, only: %i[index new create edit update] do
      member do
        patch :revoke
        patch :reactivate
      end
    end
    resources :plans, except: %i[destroy] do
      member do
        patch :retire
        patch :reactivate
      end
      resources :price_tiers, only: %i[create update destroy], controller: "plan_price_tiers"
    end
    resource  :usage, only: %i[show], controller: "usage"  # metering (one view)
    resources :invoices, only: %i[index]
    resources :audit_entries, only: %i[index], path: "audit", controller: "audit"

    # Dev-only component gallery. NOT an app view: a buildless preview of the
    # control-plane components with stub data. Never mounted outside development.
    if Rails.env.development?
      resources :previews, only: %i[index]
    end
  end
end
