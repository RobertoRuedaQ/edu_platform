require "test_helper"

# assignments (v1.24.0, item #6 of the MVP critical path, slice 3/4: file
# attachments on an EXISTING Submission). Active Storage's own tables
# (active_storage_blobs/attachments/variant_records) carry no
# institution_id/RLS at all — the tenant boundary is
# Assignments::SubmissionAttachment itself (RLS ENABLE+FORCE): a blob is
# only ever reachable by first resolving ITS row, which RLS already scopes.
# Serving always goes through an app-owned controller (never
# rails_blob_path/rails_representation_path) — three of them, one per
# access path (teacher, student portal, guardian portal), same "never
# collapse distinct access paths into one controller" convention as
# communication/v1.20.0.
class AttachmentsTest < ActionDispatch::IntegrationTest
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

    @grade_level = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado Adj", level_number: 9) }
    @subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Arte", code: "ADJ-1") }

    @student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Lucía", last_name: "Gómez", student_code: "ADJ-001")
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

  def create_and_publish_assignment!(subject: @subject, title: "Colección de collages", due_date: Date.new(2026, 3, 10),
    group_work: false)
    as_teacher do
      post "/assignments/subjects/#{subject.id}/assignments",
        params: { assignment: { title: title, due_date: due_date.iso8601, group_work: group_work ? "1" : "0" } }
    end
    assignment = Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: subject.id, title: title)
    as_teacher { post "/assignments/subjects/#{subject.id}/assignments/#{assignment.id}/publish" }
    assignment.reload
  end

  def form_group!(assignment, name:, student_ids:)
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/submission_groups",
        params: { name: name, student_ids: student_ids }
    end
    Assignments::SubmissionGroup.find_by!(institution_id: @institution.id, assignment_id: assignment.id, name: name)
  end

  test "acceptance: a student attaches docx/pdf/jpg/png to their own entrega, and the teacher can view/download them" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    %w[attachment.docx attachment.pdf attachment.jpg attachment.png].each do |fixture|
      post "/portal/student/assignments/#{assignment.id}/attachments", params: { file: fixture_file_upload(fixture) }
      assert_redirected_to portal_student_assignment_path(assignment)
    end

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 4, submission.submission_attachments.count
    assert submission.submission_attachments.all? { |a| a.attached_by_user_id == student_user.id }

    docx = submission.submission_attachments.find { |a| a.file.filename.to_s == "attachment.docx" }
    pdf = submission.submission_attachments.find { |a| a.file.filename.to_s == "attachment.pdf" }

    get "/portal/student/assignments/#{assignment.id}/attachments/#{docx.id}"
    assert_response :success
    assert_match(/^attachment/, response.headers["Content-Disposition"], "docx never renders in-browser — download only")

    get "/portal/student/assignments/#{assignment.id}/attachments/#{pdf.id}"
    assert_response :success
    assert_match(/^inline/, response.headers["Content-Disposition"], "pdf/jpg/png preview inline")

    # Switch to the teacher — same files, served through the TEACHER's own
    # controller (never Active Storage's own signed routes either way).
    sign_in_as(@user, institution: @institution, password: "password-123456")
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/attachment\.pdf/, response.body)

      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/attachments/#{pdf.id}"
      assert_response :success
      assert_match(/^inline/, response.headers["Content-Disposition"])
    end
  end

  test "rejects a file whose REAL content-type is forbidden, even when renamed to look like an allowed one" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student2-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    # fake.pdf is actually GIF-magic-byte content — Marcel's real detection
    # (never the .pdf extension, never this declared header) must catch it.
    post "/portal/student/assignments/#{assignment.id}/attachments",
      params: { file: fixture_file_upload("fake.pdf", "application/pdf") }
    assert_redirected_to portal_student_assignment_path(assignment)
    assert_match(/no permitido/, flash[:alert].to_s)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 0, submission.submission_attachments.count
    assert_equal 0, ActiveStorage::Blob.count, "a rejected upload must never leave an orphaned blob"
  end

  test "rejects an outright forbidden content-type uploaded honestly" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student3-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    post "/portal/student/assignments/#{assignment.id}/attachments",
      params: { file: fixture_file_upload("attachment.gif", "image/gif") }
    assert_redirected_to portal_student_assignment_path(assignment)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 0, submission.submission_attachments.count
  end

  test "caps at 5 attachments per entrega — a 6th attempt (even on resubmit) is rejected" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student4-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    5.times do
      post "/portal/student/assignments/#{assignment.id}/attachments", params: { file: fixture_file_upload("attachment.pdf") }
    end
    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 5, submission.submission_attachments.count

    post "/portal/student/assignments/#{assignment.id}/attachments", params: { file: fixture_file_upload("attachment.pdf") }
    assert_redirected_to portal_student_assignment_path(assignment)
    assert_match(/máximo/, flash[:alert].to_s)
    assert_equal 5, submission.submission_attachments.reload.count
  end

  test "caps at 10MB per file" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student5-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    oversized = Tempfile.new(%w[oversized .pdf])
    oversized.binmode
    oversized.write("%PDF-1.4\n")
    oversized.write("0" * 11.megabytes)
    oversized.rewind

    post "/portal/student/assignments/#{assignment.id}/attachments",
      params: { file: Rack::Test::UploadedFile.new(oversized.path, "application/pdf") }
    assert_redirected_to portal_student_assignment_path(assignment)
    assert_match(/10MB/, flash[:alert].to_s)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 0, submission.submission_attachments.count
  ensure
    oversized&.close!
  end

  test "a guardian attaches on behalf of a primaria child — attribution records the guardian, ownership stays the child's" do
    assignment = create_and_publish_assignment!
    guardian_user = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @student, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    post "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/submission", params: { body: "Entrega de mi hija" }
    post "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/attachments",
      params: { file: fixture_file_upload("attachment.pdf") }
    assert_redirected_to portal_guardian_student_assignment_path(@student, assignment)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    attachment = submission.submission_attachments.sole
    assert_equal guardian_user.id, attachment.attached_by_user_id
    assert_equal @student.id, submission.student_id, "the entrega — and its attachments — belong to the child regardless of who uploaded"

    get "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/attachments/#{attachment.id}"
    assert_response :success
  end

  test "a guardian cannot attach for a student who is not their child" do
    assignment = create_and_publish_assignment!
    other_student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Otro", last_name: "Estudiante", student_code: "ADJ-002")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    unrelated_guardian = within_tenant(@institution) do
      link_as_guardian!(@institution, student: other_student, email: "unrelated-#{SecureRandom.hex(4)}@member.test", name: "Ajeno")
    end

    sign_in_as(unrelated_guardian, institution: @institution, password: "password-123456")
    post "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/attachments",
      params: { file: fixture_file_upload("attachment.pdf") }
    assert_response :not_found
  end

  test "acceptance: one group member attaches to the shared entrega, another member sees it and can remove it" do
    assignment = create_and_publish_assignment!(title: "Mural colectivo", group_work: true)
    student_b = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Beto", last_name: "Dos", student_code: "ADJ-003")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    form_group!(assignment, name: "Equipo 1", student_ids: [ @student.id, student_b.id ])

    user_a = within_tenant(@institution) { link_as_student_user!(@institution, student: @student, email: "a-#{SecureRandom.hex(4)}@member.test", name: "Lucía") }
    user_b = within_tenant(@institution) { link_as_student_user!(@institution, student: student_b, email: "b-#{SecureRandom.hex(4)}@member.test", name: "Beto") }

    sign_in_as(user_a, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Borrador del mural" }
    post "/portal/student/assignments/#{assignment.id}/attachments", params: { file: fixture_file_upload("attachment.jpg") }

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_nil submission.student_id
    attachment = submission.submission_attachments.sole
    assert_equal user_a.id, attachment.attached_by_user_id

    sign_in_as(user_b, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}/attachments/#{attachment.id}"
    assert_response :success, "any group member can see the SAME shared entrega's attachments"

    delete "/portal/student/assignments/#{assignment.id}/attachments/#{attachment.id}"
    assert_redirected_to portal_student_assignment_path(assignment)
    assert_equal 0, submission.submission_attachments.reload.count
  end

  test "cross-tenant: an attachment seeded in a different institution never leaks into the teacher's or student's view" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "attach-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    ghost_attachment_id = within_tenant(other_institution) do
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-ADJ")
      other_assignment = Assignments::Assignment.create!(institution: other_institution, subject: subject,
        title: "Tarea ajena", due_date: Date.new(2026, 4, 1), status: "published", published_at: Time.current)
      ghost_student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno", student_code: "GHOST-ADJ")
      ghost_submission = Assignments::Submission.create!(institution: other_institution, assignment: other_assignment,
        student: ghost_student, body: "Contenido ajeno", submitted_at: Time.current)
      ghost_attachment = ghost_submission.submission_attachments.create!(institution: other_institution)
      ghost_attachment.file.attach(io: File.open(Rails.root.join("test/fixtures/files/attachment.pdf")),
        filename: "ajeno.pdf", content_type: "application/pdf")
      ghost_attachment.id
    end

    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student6-#{SecureRandom.hex(4)}@member.test", name: "Lucía")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Mi collage" }

    get "/portal/student/assignments/#{assignment.id}/attachments/#{ghost_attachment_id}"
    assert_response :not_found

    sign_in_as(@user, institution: @institution, password: "password-123456")
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/attachments/#{ghost_attachment_id}"
      assert_response :not_found
    end

    within_tenant(@institution) do
      assert_empty Assignments::SubmissionAttachment.where(institution_id: other_institution.id)
    end
  end
end
