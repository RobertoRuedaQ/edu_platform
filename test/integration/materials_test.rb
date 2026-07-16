require "test_helper"

# assignments (v1.25.0, item #6 of the MVP critical path, slice 3b/4:
# materiales del docente). The flip side of v1.24.0's entrega attachments —
# same bridge-table shape (Assignments::Material, RLS ENABLE+FORCE) and the
# same real-content-type/serving discipline (Assignments::AttachmentTypeCheck,
# AttachmentServing), but the owner is the Assignment itself and the write
# gate is RBAC (assignment.manage), never a portal relation. Reading still
# reaches students/guardians through their existing portal scope
# (StudentView.for/GuardianScope) — a draft assignment's materials are
# unreachable for free, since the assignment itself isn't in that scope yet.
class MaterialsTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_grade_level!(institution, name:, level_number:)
    GroupManagement::GradeLevel.create!(institution: institution, name: name, level_number: level_number)
  end

  def build_subject!(institution, grade_level:, name:, code:, term: "2026-1")
    Schedules::Subject.create!(institution: institution, grade_level: grade_level, name: name, code: code, term: term)
  end

  def build_student!(institution, first_name:, last_name:, student_code:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023)
  end

  def enroll!(institution, student:, subject:, active_term:)
    Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: active_term.code, academic_term: active_term, status: "enrolled")
  end

  def link_as_student_user!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    student.update!(user: user)
    user
  end

  def link_as_guardian!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    Core::GuardianStudent.create!(institution: institution, guardian_user_id: user.id, student: student,
      relationship: "madre", status: "active")
    user
  end

  setup do
    @user, @institution = sign_in_as_member # assignments entitled by default

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @grade_level = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado Mat", level_number: 9) }
    @subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Música", code: "MAT-1") }

    @student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Nicolás", last_name: "Ríos", student_code: "MAT-001")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
  end

  def as_teacher(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[assignment.manage],
                                     scope_type: :grade_level, scope_id: @grade_level.id),
      &block
    )
  end

  def create_assignment!(subject: @subject, title: "Guía de estudio", due_date: Date.new(2026, 3, 10), publish: true)
    as_teacher do
      post "/assignments/subjects/#{subject.id}/assignments", params: { assignment: { title: title, due_date: due_date.iso8601 } }
    end
    assignment = Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: subject.id, title: title)
    if publish
      as_teacher { post "/assignments/subjects/#{subject.id}/assignments/#{assignment.id}/publish" }
      assignment.reload
    else
      assignment
    end
  end

  test "acceptance: a teacher attaches docx/pdf/jpg/png to the assignment, and the teacher/student/guardian can all view them" do
    assignment = create_assignment!

    %w[attachment.docx attachment.pdf attachment.jpg attachment.png].each do |fixture|
      as_teacher do
        post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload(fixture) }
      end
      assert_redirected_to assignments_subject_assignment_path(@subject, assignment)
    end
    assignment.reload
    assert_equal 4, assignment.materials.count
    assert assignment.materials.all? { |m| m.attached_by_user_id == @user.id }

    docx = assignment.materials.find { |m| m.file.filename.to_s == "attachment.docx" }
    pdf = assignment.materials.find { |m| m.file.filename.to_s == "attachment.pdf" }

    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/attachment\.pdf/, response.body)

      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials/#{docx.id}"
      assert_response :success
      assert_match(/^attachment/, response.headers["Content-Disposition"], "docx never renders in-browser — download only")

      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials/#{pdf.id}"
      assert_response :success
      assert_match(/^inline/, response.headers["Content-Disposition"])
    end

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student-#{SecureRandom.hex(4)}@member.test", name: "Nicolás")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}"
    assert_response :success
    assert_match(/attachment\.pdf/, response.body)
    get "/portal/student/assignments/#{assignment.id}/materials/#{pdf.id}"
    assert_response :success
    assert_match(/^inline/, response.headers["Content-Disposition"])
  end

  test "a guardian sees a material of their child's assignment through the two chained scopes" do
    assignment = create_assignment!
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
    end
    material = assignment.reload.materials.sole

    guardian_user = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @student, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")

    get "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}"
    assert_response :success
    assert_match(/attachment\.pdf/, response.body)

    get "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/materials/#{material.id}"
    assert_response :success
  end

  test "a draft assignment's materials are unreachable to the student/guardian — no separate check needed, the assignment itself isn't in scope" do
    assignment = create_assignment!(title: "Aún sin publicar", publish: false)
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
    end
    material = assignment.reload.materials.sole

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student2-#{SecureRandom.hex(4)}@member.test", name: "Nicolás")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}/materials/#{material.id}"
    assert_response :not_found

    sign_in_as(@user, institution: @institution, password: "password-123456")
    as_teacher { post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/publish" }

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}/materials/#{material.id}"
    assert_response :success, "once published, the assignment (and its materials) enters StudentView.for(student)"
  end

  test "RBAC: an actor without assignment.manage cannot attach a material (403, not the portal's relation-gated 404)" do
    assignment = create_assignment!
    revoke_all_role_assignments!(@user, institution: @institution)

    post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
    assert_response :forbidden
    assert_equal 0, assignment.reload.materials.count
  end

  test "rejects a file whose REAL content-type is forbidden, even when renamed to look like an allowed one" do
    assignment = create_assignment!
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials",
        params: { file: fixture_file_upload("fake.pdf", "application/pdf") }
    end
    assert_redirected_to assignments_subject_assignment_path(@subject, assignment)
    assert_match(/no permitido/, flash[:alert].to_s)
    assert_equal 0, assignment.reload.materials.count
    assert_equal 0, ActiveStorage::Blob.count, "a rejected upload must never leave an orphaned blob"
  end

  test "caps at 10 materials per assignment — an 11th attempt is rejected" do
    assignment = create_assignment!

    10.times do
      as_teacher do
        post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
      end
    end
    assert_equal 10, assignment.reload.materials.count

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
    end
    assert_redirected_to assignments_subject_assignment_path(@subject, assignment)
    assert_match(/máximo/, flash[:alert].to_s)
    assert_equal 10, assignment.reload.materials.count
  end

  test "caps at 10MB per file" do
    assignment = create_assignment!

    oversized = Tempfile.new(%w[oversized .pdf])
    oversized.binmode
    oversized.write("%PDF-1.4\n")
    oversized.write("0" * 11.megabytes)
    oversized.rewind

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials",
        params: { file: Rack::Test::UploadedFile.new(oversized.path, "application/pdf") }
    end
    assert_redirected_to assignments_subject_assignment_path(@subject, assignment)
    assert_match(/10MB/, flash[:alert].to_s)
    assert_equal 0, assignment.reload.materials.count
  ensure
    oversized&.close!
  end

  test "writing a material is blocked once the assignment is archived" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/archive" }

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials", params: { file: fixture_file_upload("attachment.pdf") }
    end
    assert_redirected_to assignments_subject_assignment_path(@subject, assignment)
    assert_match(/archivada/, flash[:alert].to_s)
    assert_equal 0, assignment.reload.materials.count
  end

  test "cross-tenant: a material seeded in a different institution never leaks into the teacher's or student's view" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "material-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    ghost_material_id = within_tenant(other_institution) do
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-MAT")
      other_assignment = Assignments::Assignment.create!(institution: other_institution, subject: subject,
        title: "Tarea ajena", due_date: Date.new(2026, 4, 1), status: "published", published_at: Time.current)
      ghost_material = other_assignment.materials.create!(institution: other_institution)
      ghost_material.file.attach(io: File.open(Rails.root.join("test/fixtures/files/attachment.pdf")),
        filename: "ajeno.pdf", content_type: "application/pdf")
      ghost_material.id
    end

    assignment = create_assignment!
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/materials/#{ghost_material_id}"
      assert_response :not_found
    end

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student3-#{SecureRandom.hex(4)}@member.test", name: "Nicolás")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}/materials/#{ghost_material_id}"
    assert_response :not_found

    within_tenant(@institution) do
      assert_empty Assignments::Material.where(institution_id: other_institution.id)
    end
  end
end
