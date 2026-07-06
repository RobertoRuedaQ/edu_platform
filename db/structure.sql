SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assessments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    enrollment_id uuid NOT NULL,
    kind character varying NOT NULL,
    title character varying NOT NULL,
    score numeric(3,1),
    max_score numeric(3,1) DEFAULT 5.0 NOT NULL,
    weight numeric(4,3) DEFAULT 1.0 NOT NULL,
    assessed_on date,
    term character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT assessments_score_range_check CHECK (((score IS NULL) OR ((score >= (0)::numeric) AND (score <= (5)::numeric))))
);

ALTER TABLE ONLY public.assessments FORCE ROW LEVEL SECURITY;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    kind character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT departments_kind_check CHECK (((kind)::text = ANY ((ARRAY['academic'::character varying, 'operational'::character varying])::text[])))
);

ALTER TABLE ONLY public.departments FORCE ROW LEVEL SECURITY;


--
-- Name: dietary_restrictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dietary_restrictions (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    restriction_type character varying NOT NULL,
    severity character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.dietary_restrictions FORCE ROW LEVEL SECURITY;


--
-- Name: employment_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employment_periods (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    staff_member_id uuid NOT NULL,
    contract_type character varying NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    fte numeric(4,2),
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT employment_periods_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'ended'::character varying])::text[])))
);

ALTER TABLE ONLY public.employment_periods FORCE ROW LEVEL SECURITY;


--
-- Name: enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    term character varying NOT NULL,
    status character varying DEFAULT 'enrolled'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.enrollments FORCE ROW LEVEL SECURITY;


--
-- Name: faculties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faculties (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.faculties FORCE ROW LEVEL SECURITY;


--
-- Name: grade_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grade_levels (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    name character varying NOT NULL,
    level_number integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.grade_levels FORCE ROW LEVEL SECURITY;


--
-- Name: guardians; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardians (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    gender character varying NOT NULL,
    email character varying,
    phone character varying,
    relationship character varying DEFAULT 'acudiente'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT guardians_gender_check CHECK (((gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying])::text[])))
);

ALTER TABLE ONLY public.guardians FORCE ROW LEVEL SECURITY;


--
-- Name: institution_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institution_settings (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    locale character varying DEFAULT 'en'::character varying NOT NULL,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.institution_settings FORCE ROW LEVEL SECURITY;


--
-- Name: institution_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institution_users (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.institution_users FORCE ROW LEVEL SECURITY;


--
-- Name: institutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institutions (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    code character varying NOT NULL,
    kind character varying NOT NULL,
    CONSTRAINT institutions_kind_check CHECK (((kind)::text = ANY ((ARRAY['school'::character varying, 'university'::character varying])::text[])))
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    key character varying NOT NULL,
    description character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: programs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.programs (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    faculty_id uuid NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    degree_level character varying DEFAULT 'pregrado'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.programs FORCE ROW LEVEL SECURITY;


--
-- Name: role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    institution_user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    scope_department_id uuid,
    scope_grade_level_id uuid,
    scope_group_id uuid,
    idempotency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.role_assignments FORCE ROW LEVEL SECURITY;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.role_permissions FORCE ROW LEVEL SECURITY;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    key character varying NOT NULL,
    name character varying NOT NULL,
    description character varying,
    system boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.roles FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sections (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    grade_level_id uuid,
    name character varying NOT NULL,
    academic_year integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.sections FORCE ROW LEVEL SECURITY;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    user_id uuid NOT NULL,
    current_institution_id uuid,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: staff_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_members (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    institution_user_id uuid NOT NULL,
    department_id uuid,
    employee_number character varying NOT NULL,
    staff_category character varying NOT NULL,
    employment_type character varying NOT NULL,
    hire_date date,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT staff_members_category_check CHECK (((staff_category)::text = ANY ((ARRAY['teaching'::character varying, 'kitchen'::character varying, 'transport'::character varying, 'maintenance'::character varying, 'security'::character varying, 'admin'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT staff_members_employment_type_check CHECK (((employment_type)::text = ANY ((ARRAY['full_time'::character varying, 'part_time'::character varying, 'contract'::character varying])::text[]))),
    CONSTRAINT staff_members_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'on_leave'::character varying, 'terminated'::character varying])::text[])))
);

ALTER TABLE ONLY public.staff_members FORCE ROW LEVEL SECURITY;


--
-- Name: student_guardians; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_guardians (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    guardian_id uuid NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.student_guardians FORCE ROW LEVEL SECURITY;


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    gender character varying NOT NULL,
    birthdate date NOT NULL,
    student_code character varying NOT NULL,
    email character varying,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    city character varying DEFAULT 'Bogotá'::character varying NOT NULL,
    address character varying,
    entry_year integer NOT NULL,
    grade_level_id uuid,
    section_id uuid,
    program_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT students_gender_check CHECK (((gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying])::text[])))
);

ALTER TABLE ONLY public.students FORCE ROW LEVEL SECURITY;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subjects (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    grade_level_id uuid,
    program_id uuid,
    name character varying NOT NULL,
    code character varying NOT NULL,
    credits integer,
    term character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.subjects FORCE ROW LEVEL SECURITY;


--
-- Name: teachers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teachers (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    faculty_id uuid,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    gender character varying NOT NULL,
    email character varying,
    teacher_code character varying NOT NULL,
    hired_on date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    staff_member_id uuid,
    CONSTRAINT teachers_gender_check CHECK (((gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying])::text[])))
);

ALTER TABLE ONLY public.teachers FORCE ROW LEVEL SECURITY;


--
-- Name: teaching_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teaching_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    teacher_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.teaching_assignments FORCE ROW LEVEL SECURITY;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    email public.citext NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: assessments assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments
    ADD CONSTRAINT assessments_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: dietary_restrictions dietary_restrictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dietary_restrictions
    ADD CONSTRAINT dietary_restrictions_pkey PRIMARY KEY (id);


--
-- Name: employment_periods employment_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT employment_periods_pkey PRIMARY KEY (id);


--
-- Name: enrollments enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_pkey PRIMARY KEY (id);


--
-- Name: faculties faculties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculties
    ADD CONSTRAINT faculties_pkey PRIMARY KEY (id);


--
-- Name: grade_levels grade_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_levels
    ADD CONSTRAINT grade_levels_pkey PRIMARY KEY (id);


--
-- Name: guardians guardians_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardians
    ADD CONSTRAINT guardians_pkey PRIMARY KEY (id);


--
-- Name: institution_settings institution_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_settings
    ADD CONSTRAINT institution_settings_pkey PRIMARY KEY (id);


--
-- Name: institution_users institution_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_users
    ADD CONSTRAINT institution_users_pkey PRIMARY KEY (id);


--
-- Name: institutions institutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institutions
    ADD CONSTRAINT institutions_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: programs programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT programs_pkey PRIMARY KEY (id);


--
-- Name: role_assignments role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT role_assignments_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: staff_members staff_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT staff_members_pkey PRIMARY KEY (id);


--
-- Name: student_guardians student_guardians_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_guardians
    ADD CONSTRAINT student_guardians_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (id);


--
-- Name: teaching_assignments teaching_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT teaching_assignments_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_on_institution_id_student_id_guardian_id_6bb82a7a17; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_institution_id_student_id_guardian_id_6bb82a7a17 ON public.student_guardians USING btree (institution_id, student_id, guardian_id);


--
-- Name: idx_on_institution_id_student_id_subject_id_d3059c6cb5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_institution_id_student_id_subject_id_d3059c6cb5 ON public.enrollments USING btree (institution_id, student_id, subject_id);


--
-- Name: idx_on_institution_id_teacher_id_subject_id_b6a57dc73b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_institution_id_teacher_id_subject_id_b6a57dc73b ON public.teaching_assignments USING btree (institution_id, teacher_id, subject_id);


--
-- Name: idx_ra_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ra_idempotency ON public.role_assignments USING btree (institution_id, idempotency_key);


--
-- Name: idx_ra_inst_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ra_inst_role ON public.role_assignments USING btree (institution_id, role_id);


--
-- Name: idx_ra_inst_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ra_inst_user ON public.role_assignments USING btree (institution_id, institution_user_id);


--
-- Name: idx_ra_unique_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ra_unique_scope ON public.role_assignments USING btree (institution_id, institution_user_id, role_id, scope_department_id, scope_grade_level_id, scope_group_id) NULLS NOT DISTINCT;


--
-- Name: idx_rp_inst_permission; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rp_inst_permission ON public.role_permissions USING btree (institution_id, permission_id);


--
-- Name: idx_rp_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rp_unique ON public.role_permissions USING btree (institution_id, role_id, permission_id);


--
-- Name: index_assessments_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_enrollment_id ON public.assessments USING btree (enrollment_id);


--
-- Name: index_assessments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_institution_id ON public.assessments USING btree (institution_id);


--
-- Name: index_departments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_institution_id ON public.departments USING btree (institution_id);


--
-- Name: index_departments_on_institution_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departments_on_institution_id_and_code ON public.departments USING btree (institution_id, code);


--
-- Name: index_dietary_restrictions_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dietary_restrictions_on_institution_id ON public.dietary_restrictions USING btree (institution_id);


--
-- Name: index_dietary_restrictions_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dietary_restrictions_on_student_id ON public.dietary_restrictions USING btree (student_id);


--
-- Name: index_employment_periods_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employment_periods_on_institution_id ON public.employment_periods USING btree (institution_id);


--
-- Name: index_employment_periods_on_institution_id_and_staff_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employment_periods_on_institution_id_and_staff_member_id ON public.employment_periods USING btree (institution_id, staff_member_id);


--
-- Name: index_enrollments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_institution_id ON public.enrollments USING btree (institution_id);


--
-- Name: index_enrollments_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_student_id ON public.enrollments USING btree (student_id);


--
-- Name: index_enrollments_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_subject_id ON public.enrollments USING btree (subject_id);


--
-- Name: index_faculties_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_faculties_on_institution_id ON public.faculties USING btree (institution_id);


--
-- Name: index_faculties_on_institution_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_faculties_on_institution_id_and_code ON public.faculties USING btree (institution_id, code);


--
-- Name: index_grade_levels_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grade_levels_on_institution_id ON public.grade_levels USING btree (institution_id);


--
-- Name: index_grade_levels_on_institution_id_and_level_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_grade_levels_on_institution_id_and_level_number ON public.grade_levels USING btree (institution_id, level_number);


--
-- Name: index_guardians_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guardians_on_institution_id ON public.guardians USING btree (institution_id);


--
-- Name: index_institution_settings_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_institution_settings_on_institution_id ON public.institution_settings USING btree (institution_id);


--
-- Name: index_institution_users_on_institution_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_institution_users_on_institution_id_and_user_id ON public.institution_users USING btree (institution_id, user_id);


--
-- Name: index_institution_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_institution_users_on_user_id ON public.institution_users USING btree (user_id);


--
-- Name: index_institutions_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_institutions_on_code ON public.institutions USING btree (code);


--
-- Name: index_institutions_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_institutions_on_slug ON public.institutions USING btree (slug);


--
-- Name: index_permissions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_key ON public.permissions USING btree (key);


--
-- Name: index_programs_on_faculty_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_programs_on_faculty_id ON public.programs USING btree (faculty_id);


--
-- Name: index_programs_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_programs_on_institution_id ON public.programs USING btree (institution_id);


--
-- Name: index_programs_on_institution_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_programs_on_institution_id_and_code ON public.programs USING btree (institution_id, code);


--
-- Name: index_role_assignments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_assignments_on_institution_id ON public.role_assignments USING btree (institution_id);


--
-- Name: index_role_permissions_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_role_permissions_on_institution_id ON public.role_permissions USING btree (institution_id);


--
-- Name: index_roles_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_institution_id ON public.roles USING btree (institution_id);


--
-- Name: index_roles_on_institution_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_roles_on_institution_id_and_key ON public.roles USING btree (institution_id, key);


--
-- Name: index_sections_on_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_grade_level_id ON public.sections USING btree (grade_level_id);


--
-- Name: index_sections_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_institution_id ON public.sections USING btree (institution_id);


--
-- Name: index_sessions_on_current_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_current_institution_id ON public.sessions USING btree (current_institution_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_staff_members_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_members_on_institution_id ON public.staff_members USING btree (institution_id);


--
-- Name: index_staff_members_on_institution_id_and_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_members_on_institution_id_and_department_id ON public.staff_members USING btree (institution_id, department_id);


--
-- Name: index_staff_members_on_institution_id_and_employee_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_members_on_institution_id_and_employee_number ON public.staff_members USING btree (institution_id, employee_number);


--
-- Name: index_staff_members_on_institution_id_and_institution_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_staff_members_on_institution_id_and_institution_user_id ON public.staff_members USING btree (institution_id, institution_user_id);


--
-- Name: index_staff_members_on_institution_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_members_on_institution_user_id ON public.staff_members USING btree (institution_user_id);


--
-- Name: index_student_guardians_on_guardian_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_guardians_on_guardian_id ON public.student_guardians USING btree (guardian_id);


--
-- Name: index_student_guardians_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_guardians_on_institution_id ON public.student_guardians USING btree (institution_id);


--
-- Name: index_student_guardians_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_guardians_on_student_id ON public.student_guardians USING btree (student_id);


--
-- Name: index_students_on_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_grade_level_id ON public.students USING btree (grade_level_id);


--
-- Name: index_students_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_institution_id ON public.students USING btree (institution_id);


--
-- Name: index_students_on_institution_id_and_student_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_institution_id_and_student_code ON public.students USING btree (institution_id, student_code);


--
-- Name: index_students_on_program_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_program_id ON public.students USING btree (program_id);


--
-- Name: index_students_on_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_section_id ON public.students USING btree (section_id);


--
-- Name: index_subjects_on_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subjects_on_grade_level_id ON public.subjects USING btree (grade_level_id);


--
-- Name: index_subjects_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subjects_on_institution_id ON public.subjects USING btree (institution_id);


--
-- Name: index_subjects_on_institution_id_and_code_and_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subjects_on_institution_id_and_code_and_term ON public.subjects USING btree (institution_id, code, term);


--
-- Name: index_subjects_on_program_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subjects_on_program_id ON public.subjects USING btree (program_id);


--
-- Name: index_teachers_on_faculty_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teachers_on_faculty_id ON public.teachers USING btree (faculty_id);


--
-- Name: index_teachers_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teachers_on_institution_id ON public.teachers USING btree (institution_id);


--
-- Name: index_teachers_on_institution_id_and_teacher_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teachers_on_institution_id_and_teacher_code ON public.teachers USING btree (institution_id, teacher_code);


--
-- Name: index_teachers_on_staff_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teachers_on_staff_member_id ON public.teachers USING btree (staff_member_id);


--
-- Name: index_teaching_assignments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teaching_assignments_on_institution_id ON public.teaching_assignments USING btree (institution_id);


--
-- Name: index_teaching_assignments_on_subject_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teaching_assignments_on_subject_id ON public.teaching_assignments USING btree (subject_id);


--
-- Name: index_teaching_assignments_on_teacher_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teaching_assignments_on_teacher_id ON public.teaching_assignments USING btree (teacher_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: sections fk_rails_0265c1c0de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_0265c1c0de FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: assessments fk_rails_0a269157fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments
    ADD CONSTRAINT fk_rails_0a269157fd FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: student_guardians fk_rails_0eb2a4bdc7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_guardians
    ADD CONSTRAINT fk_rails_0eb2a4bdc7 FOREIGN KEY (guardian_id) REFERENCES public.guardians(id);


--
-- Name: enrollments fk_rails_107f77c451; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_107f77c451 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: students fk_rails_10eda8df32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_10eda8df32 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: enrollments fk_rails_130022d62b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_130022d62b FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: teaching_assignments fk_rails_1535481200; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT fk_rails_1535481200 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: subjects fk_rails_1b26c6deb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_1b26c6deb0 FOREIGN KEY (program_id) REFERENCES public.programs(id);


--
-- Name: employment_periods fk_rails_271ac67781; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT fk_rails_271ac67781 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: teachers fk_rails_2fabb62d4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_2fabb62d4c FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: departments fk_rails_33e5ee827a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_33e5ee827a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: student_guardians fk_rails_3a055ea1dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_guardians
    ADD CONSTRAINT fk_rails_3a055ea1dd FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: guardians fk_rails_3bb3ecce67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardians
    ADD CONSTRAINT fk_rails_3bb3ecce67 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: staff_members fk_rails_3c2c49abc0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_3c2c49abc0 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: grade_levels fk_rails_3d56a40347; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grade_levels
    ADD CONSTRAINT fk_rails_3d56a40347 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: role_assignments fk_rails_402eb6a154; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_402eb6a154 FOREIGN KEY (scope_department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: institution_users fk_rails_4d086ab524; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_users
    ADD CONSTRAINT fk_rails_4d086ab524 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: assessments fk_rails_4ee550d14a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments
    ADD CONSTRAINT fk_rails_4ee550d14a FOREIGN KEY (enrollment_id) REFERENCES public.enrollments(id);


--
-- Name: institution_users fk_rails_54725f8cd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_users
    ADD CONSTRAINT fk_rails_54725f8cd2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: role_permissions fk_rails_60126080bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_60126080bd FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: role_assignments fk_rails_646eed7bbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_646eed7bbc FOREIGN KEY (scope_grade_level_id) REFERENCES public.grade_levels(id) ON DELETE CASCADE;


--
-- Name: institution_settings fk_rails_693e18446a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_settings
    ADD CONSTRAINT fk_rails_693e18446a FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: staff_members fk_rails_6b44b8a383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_6b44b8a383 FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sessions fk_rails_75eb72a884; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_75eb72a884 FOREIGN KEY (current_institution_id) REFERENCES public.institutions(id);


--
-- Name: sections fk_rails_7a7057fef3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_7a7057fef3 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: staff_members fk_rails_7d2a281eaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_7d2a281eaa FOREIGN KEY (institution_user_id) REFERENCES public.institution_users(id) ON DELETE CASCADE;


--
-- Name: role_permissions fk_rails_92f10f160c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_92f10f160c FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: programs fk_rails_93568c9eb7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT fk_rails_93568c9eb7 FOREIGN KEY (faculty_id) REFERENCES public.faculties(id);


--
-- Name: teaching_assignments fk_rails_951c063a8a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT fk_rails_951c063a8a FOREIGN KEY (teacher_id) REFERENCES public.teachers(id);


--
-- Name: dietary_restrictions fk_rails_b2a3dacafe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dietary_restrictions
    ADD CONSTRAINT fk_rails_b2a3dacafe FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: students fk_rails_b2fee63e99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_b2fee63e99 FOREIGN KEY (program_id) REFERENCES public.programs(id);


--
-- Name: teaching_assignments fk_rails_b86c9538a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT fk_rails_b86c9538a3 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: dietary_restrictions fk_rails_bc8b5d9bbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dietary_restrictions
    ADD CONSTRAINT fk_rails_bc8b5d9bbf FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: students fk_rails_c00693d6db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_c00693d6db FOREIGN KEY (section_id) REFERENCES public.sections(id);


--
-- Name: roles fk_rails_c08d8438fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT fk_rails_c08d8438fe FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: teachers fk_rails_c43d25a88a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_c43d25a88a FOREIGN KEY (faculty_id) REFERENCES public.faculties(id);


--
-- Name: students fk_rails_c6f327792b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_c6f327792b FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: student_guardians fk_rails_c768bff12d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_guardians
    ADD CONSTRAINT fk_rails_c768bff12d FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: role_assignments fk_rails_c81e0ed360; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_c81e0ed360 FOREIGN KEY (institution_user_id) REFERENCES public.institution_users(id) ON DELETE CASCADE;


--
-- Name: faculties fk_rails_d5a8b19638; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculties
    ADD CONSTRAINT fk_rails_d5a8b19638 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: employment_periods fk_rails_daffc2b6c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT fk_rails_daffc2b6c8 FOREIGN KEY (staff_member_id) REFERENCES public.staff_members(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_e2fd7aa72b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_e2fd7aa72b FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: role_assignments fk_rails_e4bfc1cd2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_e4bfc1cd2c FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: role_assignments fk_rails_ebf84047d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_ebf84047d2 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: programs fk_rails_ed68a5b16c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT fk_rails_ed68a5b16c FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: enrollments fk_rails_f01c555e06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_f01c555e06 FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: teachers fk_rails_f0edb92a45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_f0edb92a45 FOREIGN KEY (staff_member_id) REFERENCES public.staff_members(id) ON DELETE SET NULL;


--
-- Name: role_assignments fk_rails_f2c879ee03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_f2c879ee03 FOREIGN KEY (scope_group_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_fba2424889; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_fba2424889 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: assessments assessments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assessments_tenant_isolation ON public.assessments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: departments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

--
-- Name: departments departments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY departments_tenant_isolation ON public.departments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: dietary_restrictions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dietary_restrictions ENABLE ROW LEVEL SECURITY;

--
-- Name: dietary_restrictions dietary_restrictions_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dietary_restrictions_tenant_isolation ON public.dietary_restrictions USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: employment_periods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.employment_periods ENABLE ROW LEVEL SECURITY;

--
-- Name: employment_periods employment_periods_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY employment_periods_tenant_isolation ON public.employment_periods USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: enrollments enrollments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY enrollments_tenant_isolation ON public.enrollments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: faculties; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.faculties ENABLE ROW LEVEL SECURITY;

--
-- Name: faculties faculties_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY faculties_tenant_isolation ON public.faculties USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: grade_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.grade_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: grade_levels grade_levels_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY grade_levels_tenant_isolation ON public.grade_levels USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: guardians; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardians ENABLE ROW LEVEL SECURITY;

--
-- Name: guardians guardians_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardians_tenant_isolation ON public.guardians USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: institution_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.institution_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: institution_settings institution_settings_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY institution_settings_tenant_isolation ON public.institution_settings USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: institution_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.institution_users ENABLE ROW LEVEL SECURITY;

--
-- Name: institution_users institution_users_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY institution_users_tenant_isolation ON public.institution_users USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: programs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

--
-- Name: programs programs_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY programs_tenant_isolation ON public.programs USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: role_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: role_assignments role_assignments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY role_assignments_tenant_isolation ON public.role_assignments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: role_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: role_permissions role_permissions_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY role_permissions_tenant_isolation ON public.role_permissions USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles roles_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roles_tenant_isolation ON public.roles USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

--
-- Name: sections sections_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sections_tenant_isolation ON public.sections USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: staff_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;

--
-- Name: staff_members staff_members_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_members_tenant_isolation ON public.staff_members USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: student_guardians; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_guardians ENABLE ROW LEVEL SECURITY;

--
-- Name: student_guardians student_guardians_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_guardians_tenant_isolation ON public.student_guardians USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: students students_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_tenant_isolation ON public.students USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects subjects_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subjects_tenant_isolation ON public.subjects USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: teachers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

--
-- Name: teachers teachers_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY teachers_tenant_isolation ON public.teachers USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: teaching_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teaching_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: teaching_assignments teaching_assignments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY teaching_assignments_tenant_isolation ON public.teaching_assignments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260706000003'),
('20260706000002'),
('20260706000001'),
('20260703000014'),
('20260703000013'),
('20260703000012'),
('20260703000011'),
('20260703000010'),
('20260703000009'),
('20260703000008'),
('20260703000007'),
('20260703000006'),
('20260703000005'),
('20260703000004'),
('20260703000003'),
('20260703000002'),
('20260703000001');

