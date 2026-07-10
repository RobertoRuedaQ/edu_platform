require "test_helper"

class Core::RosterImport::CommitterTest < ActiveSupport::TestCase
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_institution
    slug = "ric-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_validated_batch(institution, content)
    term = Core::AcademicTerm.create!(institution: institution, code: "2026-1", name: "2026-1",
      starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    batch = Core::RosterImportBatch.create!(institution: institution, academic_term: term, kind: "students")
    Core::RosterImport::Parser.call(batch: batch, content: content)
    Core::RosterImport::Validator.call(batch: batch)
    batch
  end

  CSV_HEADER = "national_id,first_name,last_name,gender,birthdate,student_code,entry_year,grade_level,section,email\n"

  test "commits a valid row as a new student" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_validated_batch(institution, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Committer.call(batch: batch)

      student = GroupManagement::Student.find_by(institution_id: institution.id, national_id: "1001")
      assert student.present?
      assert_equal "Ana", student.first_name
      assert_equal "COD-1", student.student_code
      assert_equal batch.roster_import_rows.first.reload.resolved_record_id, student.id
    end
  end

  test "commits a duplicate row as an ADDITIVE update — a blank CSV field never blanks an existing value" do
    institution = build_institution

    within_tenant(institution) do
      existing = GroupManagement::Student.create!(institution: institution, national_id: "2002",
        first_name: "Vieja", last_name: "Prueba", gender: "male", birthdate: Date.new(2014, 1, 1),
        student_code: "OLD-CODE", entry_year: 2024, email: "ya-tengo@correo.test")

      # email column left blank in the CSV — must NOT wipe the existing email.
      batch = build_validated_batch(institution,
        CSV_HEADER + "2002,Nueva,Prueba,male,2014-01-01,OLD-CODE,2026,,,\n")

      Core::RosterImport::Committer.call(batch: batch)

      existing.reload
      assert_equal "Nueva", existing.first_name # updated
      assert_equal "ya-tengo@correo.test", existing.email # NOT blanked
      assert_equal existing.id, batch.roster_import_rows.first.reload.resolved_record_id
    end
  end

  test "skips error and collision rows — never touches students for them" do
    institution = build_institution

    within_tenant(institution) do
      content = CSV_HEADER +
        ",Falta,Id,male,2014-01-01,COD-1,2026,,,\n" \
        "3003,Ana,Pérez,female,2015-03-01,COD-2,2026,,,\n"
      batch = build_validated_batch(institution, content)

      Core::RosterImport::Committer.call(batch: batch)

      assert_equal 1, GroupManagement::Student.count
      error_row = batch.roster_import_rows.order(:line_number).first
      assert_nil error_row.resolved_record_id
    end
  end

  test "idempotent: re-running commit on the same batch does not duplicate the student" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_validated_batch(institution, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Committer.call(batch: batch)
      Core::RosterImport::Committer.call(batch: batch)

      assert_equal 1, GroupManagement::Student.where(institution_id: institution.id, student_code: "COD-1").count
    end
  end

  test "sets the batch to committed" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_validated_batch(institution, CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,,,\n")

      Core::RosterImport::Committer.call(batch: batch)

      assert_equal "committed", batch.reload.status
    end
  end

  test "resolves grade_level/section by name when provided" do
    institution = build_institution

    within_tenant(institution) do
      grade = GroupManagement::GradeLevel.create!(institution: institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: institution, grade_level: grade, name: "9A", academic_year: 2026)

      batch = build_validated_batch(institution,
        CSV_HEADER + "1001,Ana,Pérez,female,2015-03-01,COD-1,2026,Grado 9,9A,\n")

      Core::RosterImport::Committer.call(batch: batch)

      student = GroupManagement::Student.find_by(institution_id: institution.id, national_id: "1001")
      assert_equal grade.id, student.grade_level_id
      assert_equal section.id, student.section_id
    end
  end

  test "entry_year defaults to the current year when the CSV omits it" do
    institution = build_institution

    within_tenant(institution) do
      batch = build_validated_batch(institution,
        "national_id,first_name,last_name,gender,birthdate,student_code\n" \
        "1001,Ana,Pérez,female,2015-03-01,COD-1\n")

      Core::RosterImport::Committer.call(batch: batch)

      student = GroupManagement::Student.find_by(institution_id: institution.id, national_id: "1001")
      assert_equal Date.current.year, student.entry_year
    end
  end
end
