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
    resource :student, only: :show, controller: "student_portal"
    resource :guardian, only: :show, controller: "guardian_portal"
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

  # --- Control plane (super-admin, cross-tenant, above RLS) -----------------
  # Its own namespace, mounted at /control_plane. NOT a tenant domain: no RLS
  # scoping applies. Controllers live in app/control_plane/control_plane/ and
  # resolve to ControlPlane::*Controller. Auth guard + audited BYPASSRLS role
  # are still stubs in this phase (see ControlPlane::BaseController).
  namespace :control_plane do
    root to: "dashboard#show"

    resources :institutions, only: %i[index show]
    resources :addons, only: %i[index]
    resources :entitlements, only: %i[index]   # editor per institution (?institution_id=)
    resources :plans, only: %i[index]
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
