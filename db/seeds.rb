# db/seeds.rb — Datos de demostración robustos para "mitad de semestre" (midterm).
#
# Crea dos instituciones (una escuela y una universidad), 1500 estudiantes cada
# una, con estructura académica, matrículas, notas variadas (0.0–5.0, aprueba
# 3.0), tutores, docentes de ambos géneros y restricciones de cafetería.
#
# Es RLS-aware: como el seed corre como edu_app_runtime (NOBYPASSRLS), cada
# bloque de datos de inquilino se inserta dentro de UNA transacción con
# `Tenant::Guc.set_local`, de modo que el WITH CHECK de RLS aprueba las filas.
# Idempotente: borra los datos previos de cada institución sembrada.

require "securerandom"

srand(20260703) # secuencia reproducible

NOW  = Time.current
TERM = "2026-1"
CITY = "Bogotá"

FIRST_M = %w[Juan Carlos Andrés Santiago Sebastián Mateo Nicolás Samuel David Daniel
             Alejandro Diego Miguel Felipe Tomás Emiliano Gabriel Martín Julián Esteban
             Camilo Fernando Ricardo Jorge Óscar Iván Héctor Álvaro Rodrigo Cristian].freeze
FIRST_F = %w[María Valentina Sofía Isabella Camila Valeria Mariana Gabriela Daniela Sara
             Luciana Martina Antonella Salomé Manuela Paula Andrea Carolina Laura Natalia
             Juana Alejandra Catalina Ana Diana Adriana Lucía Verónica Patricia Carmen].freeze
LAST    = %w[García Rodríguez Martínez López González Hernández Pérez Sánchez Ramírez Torres
             Flores Rivera Gómez Díaz Cruz Morales Ortiz Gutiérrez Chávez Ramos Vargas Castillo
             Jiménez Romero Álvarez Mendoza Ruiz Herrera Medina Aguilar Rojas Moreno Muñoz Rueda
             Castro Ospina Cárdenas Quintero Pardo Zapata].freeze

RESTRICTIONS = %w[vegetariano vegano celiaco alergia_mani alergia_lactosa intolerancia_gluten
                  kosher halal diabetico].freeze
SEVERITIES   = %w[leve moderada severa].freeze
STREETS      = ["Calle", "Carrera", "Avenida", "Transversal", "Diagonal"].freeze

# guidelines/CLOSURE_PLAN.md Fase D — cafeteria resto: no menu-authoring UI in
# this increment (same posture already applied to character_frameworks
# authorship), so the catalog is seeded like Cafeteria::DietaryRestriction
# already was. Same 5 items the retired MenuRoster stub carried, allergens
# now real Cafeteria::DietaryRestriction::ALLERGEN_NAMES display values.
MENU_ITEMS = [
  { name: "Arroz con pollo", category: "Almuerzo", price_cents: 950_000, allergens: [], dietary_tags: [] },
  { name: "Sándwich de mantequilla de maní", category: "Snack", price_cents: 450_000,
    allergens: [ "Maní" ], dietary_tags: [] },
  { name: "Yogurt con granola", category: "Snack", price_cents: 380_000,
    allergens: [ "Lactosa" ], dietary_tags: [ "Vegetariano" ] },
  { name: "Ensalada vegana", category: "Almuerzo", price_cents: 800_000,
    allergens: [], dietary_tags: %w[Vegano Vegetariano] },
  { name: "Pasta integral", category: "Almuerzo", price_cents: 880_000,
    allergens: [ "Gluten" ], dietary_tags: [] }
].freeze

# Evaluaciones de mitad de semestre (suman peso 1.0).
ASSESSMENTS = [
  { kind: "quiz",     title: "Quiz 1",    weight: 0.15, on: Date.new(2026, 2, 20) },
  { kind: "taller",   title: "Taller 1",  weight: 0.15, on: Date.new(2026, 3, 5) },
  { kind: "parcial",  title: "Parcial 1", weight: 0.35, on: Date.new(2026, 3, 20) },
  { kind: "proyecto", title: "Proyecto",  weight: 0.35, on: Date.new(2026, 4, 10) }
].freeze

SCHOOL_SUBJECTS = ["Matemáticas", "Lengua Castellana", "Ciencias Naturales", "Ciencias Sociales",
                   "Inglés", "Educación Física", "Artes", "Informática"].freeze

UNI_FACULTIES = {
  "Ciencias Sociales"   => ["Historia", "Antropología", "Sociología", "Ciencia Política"],
  "Ingeniería"          => ["Ingeniería de Sistemas", "Ingeniería Civil", "Ingeniería Industrial", "Ingeniería Electrónica"],
  "Ciencias de la Salud" => ["Medicina", "Enfermería", "Odontología"],
  "Ciencias Económicas" => ["Economía", "Administración", "Contaduría"],
  "Artes y Humanidades" => ["Filosofía", "Literatura", "Música"]
}.freeze

# ---- helpers ---------------------------------------------------------------

def full_name(gender)
  first = (gender == "male" ? FIRST_M : FIRST_F).sample
  [first, "#{LAST.sample} #{LAST.sample}"]
end

# Habilidad latente por estudiante -> notas consistentes con buenos y malos.
def latent_ability
  r = rand
  if    r < 0.15 then rand(1.0..2.7)   # bajos (algunos reprueban)
  elsif r < 0.78 then rand(3.0..4.3)   # promedio / buenos
  else               rand(4.3..5.0)    # altos
  end
end

def score_for(ability)
  s = ability + ((rand - 0.5) * 1.4)   # ruido ±0.7
  s = 0.0 if s.negative?
  s = 5.0 if s > 5
  s.round(1)
end

def slugify(str)
  str.downcase.tr("áéíóúñ", "aeioun").gsub(/[^a-z]/, "")
end

def email_for(first, last, seq, domain)
  "#{slugify(first)}.#{slugify(last.split.first)}#{seq}@#{domain}.edu.co"
end

def address_sample
  "#{STREETS.sample} #{rand(1..180)} ##{rand(1..120)}-#{rand(1..99)}, #{CITY}"
end

def phone_sample
  "+57 3#{rand(10..29)} #{rand(100..999)} #{rand(1000..9999)}"
end

def distribute(total, buckets)
  base = total / buckets
  rem  = total % buckets
  Array.new(buckets) { |i| base + (i < rem ? 1 : 0) }
end

# insert_all en lotes; devuelve los ids generados (en orden) si returning: %w[id].
def insert_rows(model, rows, returning: nil)
  out = []
  rows.each_slice(1000) do |slice|
    res = model.insert_all!(slice, returning: returning)
    out.concat(res.rows.flatten) if returning
  end
  out
end

# v1.15.0: gives every seeded institution a real, active academic_terms row
# matching TERM, so the enrollments.academic_term_id join (Cav./B2, model
# half) has real data to resolve against — without this, the new column
# would be populated but never actually joinable in dev/demo data.
def build_active_term(iid)
  Core::AcademicTerm.create!(institution_id: iid, code: TERM, name: "Semestre #{TERM}",
    starts_on: Date.new(2026, 1, 20), ends_on: Date.new(2026, 6, 15), status: "active")
end

def with_tenant(institution)
  ActiveRecord::Base.transaction do
    Tenant::Guc.set_local(institution.id)
    yield institution.id
  end
end

# Matrículas (estudiante x materia) + notas de mitad de semestre por matrícula.
def build_enrollments(iid, student_ids, abilities, subject_ids, academic_term_id:)
  enr_rows = []
  enr_ab   = []
  student_ids.each_with_index do |sid, i|
    subject_ids.each do |subj|
      enr_rows << { institution_id: iid, student_id: sid, subject_id: subj,
                    term: TERM, academic_term_id: academic_term_id, status: "enrolled",
                    created_at: NOW, updated_at: NOW }
      enr_ab << abilities[i]
    end
  end
  enr_ids = insert_rows(Schedules::Enrollment, enr_rows, returning: %w[id])

  ass_rows = []
  enr_ids.each_with_index do |eid, j|
    ability = enr_ab[j]
    ASSESSMENTS.each do |t|
      ass_rows << { institution_id: iid, enrollment_id: eid, kind: t[:kind], title: t[:title],
                    score: score_for(ability), max_score: 5.0, weight: t[:weight],
                    assessed_on: t[:on], term: TERM, created_at: NOW, updated_at: NOW }
    end
  end
  insert_rows(Schedules::Assessment, ass_rows)
end

def build_teachers(iid, count:, code_prefix:, faculty_ids: [])
  rows = Array.new(count) do |i|
    gender = i.even? ? "male" : "female" # ambos géneros ~50/50
    first, last = full_name(gender)
    { institution_id: iid, faculty_id: (faculty_ids.empty? ? nil : faculty_ids.sample),
      first_name: first, last_name: last, gender: gender,
      email: email_for(first, last, i, code_prefix.downcase),
      teacher_code: format("#{code_prefix}-T-%03d", i + 1),
      hired_on: Date.new(2015 + rand(0..10), rand(1..12), rand(1..28)),
      created_at: NOW, updated_at: NOW }
  end
  insert_rows(TeacherManagement::Teacher, rows, returning: %w[id])
end

def assign_teaching(iid, teacher_ids, subject_ids)
  rows = subject_ids.each_with_index.map do |subj, i|
    { institution_id: iid, teacher_id: teacher_ids[i % teacher_ids.size], subject_id: subj,
      created_at: NOW, updated_at: NOW }
  end
  insert_rows(TeacherManagement::TeachingAssignment, rows)
end

def build_dietary_restrictions(iid, student_ids, rate: 0.05)
  chosen = student_ids.select { rand < rate }
  rows = chosen.map do |sid|
    { institution_id: iid, student_id: sid, restriction_type: RESTRICTIONS.sample,
      severity: SEVERITIES.sample, created_at: NOW, updated_at: NOW }
  end
  insert_rows(Cafeteria::DietaryRestriction, rows)
  chosen.size
end

def build_menu_items(iid)
  MENU_ITEMS.each { |attrs| Cafeteria::MenuItem.create!(attrs.merge(institution_id: iid)) }
end

def reset_institution!(slug)
  inst = Core::Institution.find_by(slug: slug)
  return unless inst

  ActiveRecord::Base.transaction do
    Tenant::Guc.set_local(inst.id)
    [Schedules::Assessment, TeacherManagement::TeachingAssignment, Cafeteria::DietaryRestriction,
     Cafeteria::PurchaseLine, Cafeteria::Purchase, Cafeteria::MenuItem,
     StudentSupport::StudentGuardian, Schedules::Enrollment, Core::AcademicTerm, StudentSupport::Guardian,
     TeacherManagement::Teacher, Schedules::Subject, GroupManagement::Student,
     GroupManagement::Section, GroupManagement::Program, GroupManagement::GradeLevel,
     GroupManagement::Faculty, Core::InstitutionSetting].each(&:delete_all)
  end
  inst.destroy
end

def print_summary(inst, label)
  with_tenant(inst) do
    students = GroupManagement::Student.count
    males    = GroupManagement::Student.where(gender: "male").count
    puts "== #{label} (#{inst.kind}) =="
    puts "  Estudiantes: #{students} (H:#{males} M:#{students - males})"
    puts "  Docentes:    #{TeacherManagement::Teacher.count} " \
         "(H:#{TeacherManagement::Teacher.where(gender: 'male').count} " \
         "M:#{TeacherManagement::Teacher.where(gender: 'female').count})"
    puts "  Matrículas:  #{Schedules::Enrollment.count} | Notas: #{Schedules::Assessment.count} " \
         "(aprob #{Schedules::Assessment.passing.count} / reprob #{Schedules::Assessment.failing.count})"
    puts "  Tutores:     #{StudentSupport::Guardian.count} | " \
         "Restricciones alimentarias: #{Cafeteria::DietaryRestriction.count}"
  end
end

# ---- ESCUELA ---------------------------------------------------------------

def build_school(inst)
  iid = inst.id
  with_tenant(inst) do
    term_id = build_active_term(iid).id

    levels = (6..11).to_a
    gl_rows = levels.map { |n| { institution_id: iid, name: "Grado #{n}", level_number: n, created_at: NOW, updated_at: NOW } }
    gl_ids  = insert_rows(GroupManagement::GradeLevel, gl_rows, returning: %w[id])
    grade_of = levels.zip(gl_ids).to_h

    # Secciones A, B, C por grado.
    sec_specs = levels.product(%w[A B C])
    sec_rows  = sec_specs.map do |lvl, ltr|
      { institution_id: iid, grade_level_id: grade_of[lvl], name: ltr, academic_year: 2026, created_at: NOW, updated_at: NOW }
    end
    sec_ids = insert_rows(GroupManagement::Section, sec_rows, returning: %w[id])
    sections = sec_specs.each_index.map { |i| { id: sec_ids[i], level: sec_specs[i][0] } }

    # Materias por grado (8).
    subj_specs = levels.flat_map { |lvl| SCHOOL_SUBJECTS.each_with_index.map { |nm, i| [lvl, nm, i] } }
    subj_rows  = subj_specs.map do |lvl, nm, i|
      { institution_id: iid, grade_level_id: grade_of[lvl], name: "#{nm} #{lvl}",
        code: "G#{lvl}M#{i}", credits: 4, term: TERM, created_at: NOW, updated_at: NOW }
    end
    subj_ids = insert_rows(Schedules::Subject, subj_rows, returning: %w[id])
    subjects_by_level = Hash.new { |h, k| h[k] = [] }
    subj_specs.each_with_index { |(lvl, _, _), idx| subjects_by_level[lvl] << subj_ids[idx] }

    # Estudiantes distribuidos en las secciones.
    counts = distribute(1500, sections.size)
    counter = 0
    all_student_ids = []
    student_gender  = {}
    sections.each_with_index do |sec, si|
      abil = []
      srows = Array.new(counts[si]) do
        gender = rand < 0.5 ? "male" : "female"
        first, last = full_name(gender)
        counter += 1
        age = sec[:level] + 5
        abil << latent_ability
        { institution_id: iid, first_name: first, last_name: last, gender: gender,
          birthdate: Date.new(2026 - age, rand(1..12), rand(1..28)),
          student_code: format("CSJ-2026-%04d", counter), email: email_for(first, last, counter, "csj"),
          status: "active", city: CITY, address: address_sample,
          entry_year: 2026 - (sec[:level] - 6), grade_level_id: grade_of[sec[:level]],
          section_id: sec[:id], created_at: NOW, updated_at: NOW }
      end
      sid = insert_rows(GroupManagement::Student, srows, returning: %w[id])
      build_enrollments(iid, sid, abil, subjects_by_level[sec[:level]], academic_term_id: term_id)
      sid.each_with_index { |id, i| student_gender[id] = srows[i][:gender] }
      all_student_ids.concat(sid)
    end

    # Tutores: el 45% de los estudiantes tiene 2 (ambos géneros).
    chosen = all_student_ids.select { rand < 0.45 }
    g_rows = []
    chosen.each do
      g_rows << guardian_row(iid, prefer: "male")
      g_rows << guardian_row(iid, prefer: "female")
    end
    g_ids = insert_rows(StudentSupport::Guardian, g_rows, returning: %w[id])
    sg_rows = []
    chosen.each_with_index do |sid, i|
      sg_rows << { institution_id: iid, student_id: sid, guardian_id: g_ids[2 * i],     is_primary: true,  created_at: NOW, updated_at: NOW }
      sg_rows << { institution_id: iid, student_id: sid, guardian_id: g_ids[2 * i + 1], is_primary: false, created_at: NOW, updated_at: NOW }
    end
    insert_rows(StudentSupport::StudentGuardian, sg_rows)

    # Docentes (ambos géneros) y su asignación a materias.
    teacher_ids = build_teachers(iid, count: 40, code_prefix: "CSJ")
    assign_teaching(iid, teacher_ids, subj_ids)

    # Cafetería: 5% con restricción, catálogo de menú real.
    build_dietary_restrictions(iid, all_student_ids, rate: 0.05)
    build_menu_items(iid)
  end
end

def guardian_row(iid, prefer:)
  gender = rand < 0.85 ? prefer : (prefer == "male" ? "female" : "male")
  first, last = full_name(gender)
  { institution_id: iid, first_name: first, last_name: last, gender: gender,
    email: email_for(first, last, rand(10_000), "acudientes"), phone: phone_sample,
    relationship: (gender == "male" ? "padre" : "madre"), created_at: NOW, updated_at: NOW }
end

# ---- UNIVERSIDAD -----------------------------------------------------------

def build_university(inst)
  iid = inst.id
  with_tenant(inst) do
    term_id = build_active_term(iid).id

    fac_names = UNI_FACULTIES.keys
    fac_rows  = fac_names.each_with_index.map { |nm, i| { institution_id: iid, name: nm, code: "F#{i + 1}", created_at: NOW, updated_at: NOW } }
    fac_ids   = insert_rows(GroupManagement::Faculty, fac_rows, returning: %w[id])
    faculty_of = fac_names.zip(fac_ids).to_h

    prog_specs = UNI_FACULTIES.flat_map { |fac, progs| progs.map { |p| [fac, p] } }
    prog_rows  = prog_specs.each_with_index.map do |(fac, prog), i|
      { institution_id: iid, faculty_id: faculty_of[fac], name: prog, code: format("P%02d", i + 1),
        degree_level: "pregrado", created_at: NOW, updated_at: NOW }
    end
    prog_ids = insert_rows(GroupManagement::Program, prog_rows, returning: %w[id])
    programs = prog_specs.each_index.map { |i| { id: prog_ids[i], name: prog_specs[i][1], code: format("P%02d", i + 1) } }

    # Materias por programa (6).
    subjects_by_program = {}
    all_subject_ids = []
    programs.each do |pr|
      srows = (1..6).map do |k|
        { institution_id: iid, program_id: pr[:id], name: "#{pr[:name]} — Curso #{k}",
          code: "#{pr[:code]}-#{k}", credits: 3, term: TERM, created_at: NOW, updated_at: NOW }
      end
      ids = insert_rows(Schedules::Subject, srows, returning: %w[id])
      subjects_by_program[pr[:id]] = ids
      all_subject_ids.concat(ids)
    end

    # Estudiantes distribuidos en los programas.
    counts = distribute(1500, programs.size)
    counter = 0
    all_student_ids = []
    programs.each_with_index do |pr, pi|
      abil = []
      srows = Array.new(counts[pi]) do
        gender = rand < 0.5 ? "male" : "female"
        first, last = full_name(gender)
        counter += 1
        age = 18 + rand(0..7)
        abil << latent_ability
        { institution_id: iid, first_name: first, last_name: last, gender: gender,
          birthdate: Date.new(2026 - age, rand(1..12), rand(1..28)),
          student_code: format("UAND-2026-%04d", counter), email: email_for(first, last, counter, "uand"),
          status: "active", city: CITY, address: address_sample,
          entry_year: 2026 - rand(0..4), program_id: pr[:id], created_at: NOW, updated_at: NOW }
      end
      sid = insert_rows(GroupManagement::Student, srows, returning: %w[id])
      build_enrollments(iid, sid, abil, subjects_by_program[pr[:id]], academic_term_id: term_id)
      all_student_ids.concat(sid)
    end

    # Docentes (ambos géneros, con facultad) y su asignación.
    teacher_ids = build_teachers(iid, count: 60, code_prefix: "UAND", faculty_ids: fac_ids)
    assign_teaching(iid, teacher_ids, all_subject_ids)

    # Cafetería: 5% con restricción, catálogo de menú real.
    build_dietary_restrictions(iid, all_student_ids, rate: 0.05)
    build_menu_items(iid)
  end
end

# ---- EJECUCIÓN -------------------------------------------------------------

puts "Reseteando datos previos (si existen)..."
reset_institution!("colegio-san-jose")
reset_institution!("universidad-andina")

puts "Creando Colegio San José (escuela)..."
school = Provisioning::CreateInstitution.call(
  name: "Colegio San José", slug: "colegio-san-jose", code: "CSJ", kind: "school",
  settings: { timezone: "America/Bogota", locale: "es" }
).institution
build_school(school)

puts "Creando Universidad Andina (universidad)..."
university = Provisioning::CreateInstitution.call(
  name: "Universidad Andina", slug: "universidad-andina", code: "UAND", kind: "university",
  settings: { timezone: "America/Bogota", locale: "es" }
).institution
build_university(university)

puts "\nResumen:"
print_summary(school, "Colegio San José")
print_summary(university, "Universidad Andina")
puts "\nSeed completado."
