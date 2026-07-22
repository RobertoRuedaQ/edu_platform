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
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


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
-- Name: academic_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_terms (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    status character varying DEFAULT 'upcoming'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT academic_terms_date_range_check CHECK ((ends_on >= starts_on)),
    CONSTRAINT academic_terms_status_check CHECK (((status)::text = ANY ((ARRAY['upcoming'::character varying, 'active'::character varying, 'closed'::character varying])::text[])))
);

ALTER TABLE ONLY public.academic_terms FORCE ROW LEVEL SECURITY;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    instructor_staff_member_id uuid,
    kind character varying NOT NULL,
    name character varying NOT NULL,
    capacity integer NOT NULL,
    fee_cents bigint,
    location character varying,
    schedule_info character varying,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT activities_capacity_positive_check CHECK ((capacity > 0)),
    CONSTRAINT activities_fee_cents_nonneg_check CHECK (((fee_cents IS NULL) OR (fee_cents >= 0))),
    CONSTRAINT activities_kind_check CHECK (((kind)::text = ANY ((ARRAY['sport'::character varying, 'art'::character varying, 'tutoring'::character varying])::text[]))),
    CONSTRAINT activities_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);

ALTER TABLE ONLY public.activities FORCE ROW LEVEL SECURITY;


--
-- Name: activity_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_enrollments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    activity_id uuid NOT NULL,
    student_id uuid NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    enrolled_at timestamp(6) without time zone NOT NULL,
    withdrawn_at timestamp(6) without time zone,
    enrolled_via character varying NOT NULL,
    enrolled_by_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT activity_enrollments_enrolled_via_check CHECK (((enrolled_via)::text = ANY ((ARRAY['staff'::character varying, 'guardian'::character varying])::text[]))),
    CONSTRAINT activity_enrollments_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'withdrawn'::character varying])::text[])))
);

ALTER TABLE ONLY public.activity_enrollments FORCE ROW LEVEL SECURITY;


--
-- Name: addons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addons (
    id uuid DEFAULT uuidv7() NOT NULL,
    key public.citext NOT NULL,
    name character varying NOT NULL,
    description text,
    monthly_fee_cents bigint DEFAULT 0 NOT NULL,
    currency character varying DEFAULT 'COP'::character varying NOT NULL,
    metered boolean DEFAULT false NOT NULL,
    included_quota bigint,
    unit character varying,
    overage_unit_price_cents bigint,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT addons_currency_check CHECK ((char_length((currency)::text) = 3)),
    CONSTRAINT addons_included_quota_check CHECK (((included_quota IS NULL) OR (included_quota >= 0))),
    CONSTRAINT addons_metering_consistency_check CHECK ((((metered = false) AND (included_quota IS NULL) AND (unit IS NULL) AND (overage_unit_price_cents IS NULL)) OR ((metered = true) AND (included_quota IS NOT NULL) AND (unit IS NOT NULL) AND (overage_unit_price_cents IS NOT NULL)))),
    CONSTRAINT addons_monthly_fee_cents_check CHECK ((monthly_fee_cents >= 0)),
    CONSTRAINT addons_overage_unit_price_cents_check CHECK (((overage_unit_price_cents IS NULL) OR (overage_unit_price_cents >= 0))),
    CONSTRAINT addons_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'retired'::character varying])::text[])))
);


--
-- Name: affinity_taxonomy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.affinity_taxonomy (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    parent_id uuid,
    department_id uuid,
    name character varying NOT NULL,
    kind character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    search_tsv tsvector GENERATED ALWAYS AS (to_tsvector('spanish'::regconfig, (COALESCE(name, ''::character varying))::text)) STORED,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT affinity_taxonomy_kind_check CHECK (((kind)::text = ANY ((ARRAY['sport'::character varying, 'art'::character varying, 'hobby'::character varying, 'academic'::character varying])::text[])))
);

ALTER TABLE ONLY public.affinity_taxonomy FORCE ROW LEVEL SECURITY;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    author_institution_user_id uuid,
    title character varying NOT NULL,
    body text NOT NULL,
    status character varying DEFAULT 'published'::character varying NOT NULL,
    published_at timestamp(6) without time zone NOT NULL,
    retracted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT announcements_status_check CHECK (((status)::text = ANY ((ARRAY['published'::character varying, 'retracted'::character varying])::text[])))
);

ALTER TABLE ONLY public.announcements FORCE ROW LEVEL SECURITY;


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
    assignment_id uuid,
    CONSTRAINT assessments_score_range_check CHECK (((score IS NULL) OR ((score >= (0)::numeric) AND (score <= (5)::numeric))))
);

ALTER TABLE ONLY public.assessments FORCE ROW LEVEL SECURITY;


--
-- Name: assignment_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignment_materials (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    attached_by_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.assignment_materials FORCE ROW LEVEL SECURITY;


--
-- Name: assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    title character varying NOT NULL,
    instructions text,
    due_date date NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_by_institution_user_id uuid,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    group_work boolean DEFAULT false NOT NULL,
    evaluation_method character varying DEFAULT 'direct'::character varying NOT NULL,
    rubric_template_id uuid,
    rubric_snapshot jsonb,
    CONSTRAINT assignments_evaluation_method_check CHECK (((evaluation_method)::text = ANY ((ARRAY['direct'::character varying, 'rubric'::character varying])::text[]))),
    CONSTRAINT assignments_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);

ALTER TABLE ONLY public.assignments FORCE ROW LEVEL SECURITY;


--
-- Name: attendance_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_records (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    group_id uuid NOT NULL,
    date date NOT NULL,
    status character varying DEFAULT 'present'::character varying NOT NULL,
    recorded_by_staff_member_id uuid,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT attendance_records_status_check CHECK (((status)::text = ANY ((ARRAY['present'::character varying, 'absent'::character varying, 'late'::character varying, 'excused'::character varying])::text[])))
);

ALTER TABLE ONLY public.attendance_records FORCE ROW LEVEL SECURITY;


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    actor_institution_user_id uuid,
    action character varying NOT NULL,
    target_type character varying,
    target_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip character varying,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.audit_events FORCE ROW LEVEL SECURITY;


--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    title character varying NOT NULL,
    description text,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    scope_grade_level_id uuid,
    scope_group_id uuid,
    created_by_institution_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT calendar_events_scope_exclusive_check CHECK ((NOT ((scope_grade_level_id IS NOT NULL) AND (scope_group_id IS NOT NULL)))),
    CONSTRAINT calendar_events_time_order_check CHECK ((ends_at >= starts_at))
);

ALTER TABLE ONLY public.calendar_events FORCE ROW LEVEL SECURITY;


--
-- Name: care_auras; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.care_auras (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    authored_by_counselor_id uuid NOT NULL,
    aura_kind character varying NOT NULL,
    guidance_text text NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT care_auras_aura_kind_check CHECK (((aura_kind)::text = ANY ((ARRAY['private_or_oral_evaluation'::character varying, 'positive_reinforcement_public'::character varying, 'extra_time'::character varying, 'quiet_space'::character varying])::text[]))),
    CONSTRAINT care_auras_effective_range_check CHECK (((effective_until IS NULL) OR (effective_until >= effective_from)))
);

ALTER TABLE ONLY public.care_auras FORCE ROW LEVEL SECURITY;


--
-- Name: character_dimension_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_dimension_scores (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    evaluation_id uuid NOT NULL,
    dimension_key text NOT NULL,
    level_label text NOT NULL,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.character_dimension_scores FORCE ROW LEVEL SECURITY;


--
-- Name: character_dimensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_dimensions (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    framework_id uuid NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    weight numeric(6,2) DEFAULT 1.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.character_dimensions FORCE ROW LEVEL SECURITY;


--
-- Name: character_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_evaluations (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    framework_id uuid NOT NULL,
    framework_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    author_kind character varying NOT NULL,
    author_institution_user_id uuid NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT character_evaluations_author_kind_check CHECK (((author_kind)::text = ANY ((ARRAY['teacher'::character varying, 'counselor'::character varying])::text[]))),
    CONSTRAINT character_evaluations_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying])::text[])))
);

ALTER TABLE ONLY public.character_evaluations FORCE ROW LEVEL SECURITY;


--
-- Name: character_frameworks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_frameworks (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT character_frameworks_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);

ALTER TABLE ONLY public.character_frameworks FORCE ROW LEVEL SECURITY;


--
-- Name: character_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_levels (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    dimension_id uuid NOT NULL,
    label character varying NOT NULL,
    descriptor text,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.character_levels FORCE ROW LEVEL SECURITY;


--
-- Name: character_program_consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.character_program_consents (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    granted_by_guardian_user_id uuid NOT NULL,
    granted_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.character_program_consents FORCE ROW LEVEL SECURITY;


--
-- Name: charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    invoice_number character varying NOT NULL,
    description character varying,
    amount numeric(12,2) NOT NULL,
    currency character varying NOT NULL,
    due_on date,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    idempotency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT charges_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'overdue'::character varying, 'void'::character varying])::text[])))
);

ALTER TABLE ONLY public.charges FORCE ROW LEVEL SECURITY;


--
-- Name: classroom_layouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classroom_layouts (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    section_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    rows smallint NOT NULL,
    cols smallint NOT NULL,
    board_orientation smallint DEFAULT 0 NOT NULL,
    aisles jsonb DEFAULT '[]'::jsonb NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT classroom_layouts_board_orientation_check CHECK ((board_orientation = ANY (ARRAY[0, 90, 180, 270]))),
    CONSTRAINT classroom_layouts_cols_positive_check CHECK ((cols > 0)),
    CONSTRAINT classroom_layouts_effective_range_check CHECK (((effective_until IS NULL) OR (effective_until >= effective_from))),
    CONSTRAINT classroom_layouts_rows_positive_check CHECK ((rows > 0))
);

ALTER TABLE ONLY public.classroom_layouts FORCE ROW LEVEL SECURITY;


--
-- Name: control_plane_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.control_plane_audit_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    platform_admin_id uuid,
    action character varying NOT NULL,
    target_type character varying,
    target_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip_address character varying,
    created_at timestamp(6) without time zone DEFAULT now() NOT NULL
);


--
-- Name: control_plane_email_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.control_plane_email_otps (
    id uuid DEFAULT uuidv7() NOT NULL,
    platform_admin_id uuid NOT NULL,
    code_digest character varying NOT NULL,
    purpose character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    consumed_at timestamp(6) without time zone,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT control_plane_email_otps_purpose_check CHECK (((purpose)::text = 'sign_in'::text))
);


--
-- Name: control_plane_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.control_plane_sessions (
    id uuid DEFAULT uuidv7() NOT NULL,
    platform_admin_id uuid NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: conversation_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_participants (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    institution_user_id uuid,
    guardian_user_id uuid,
    last_read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT conversation_participants_identity_check CHECK ((num_nonnulls(institution_user_id, guardian_user_id) = 1))
);

ALTER TABLE ONLY public.conversation_participants FORCE ROW LEVEL SECURITY;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    subject character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_by_institution_user_id uuid,
    closed_at timestamp(6) without time zone,
    closed_by_institution_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT conversations_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'closed'::character varying])::text[])))
);

ALTER TABLE ONLY public.conversations FORCE ROW LEVEL SECURITY;


--
-- Name: counseling_cases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counseling_cases (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    opened_by_id uuid NOT NULL,
    category character varying NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    opened_at timestamp(6) without time zone NOT NULL,
    closed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT counseling_cases_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'in_progress'::character varying, 'closed'::character varying])::text[])))
);

ALTER TABLE ONLY public.counseling_cases FORCE ROW LEVEL SECURITY;


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
-- Name: disciplinary_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disciplinary_logs (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    reported_by_institution_user_id uuid NOT NULL,
    category character varying NOT NULL,
    description text NOT NULL,
    occurred_at date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT disciplinary_logs_category_check CHECK (((category)::text = ANY ((ARRAY['attendance'::character varying, 'conduct'::character varying, 'academic_integrity'::character varying, 'other'::character varying])::text[])))
);

ALTER TABLE ONLY public.disciplinary_logs FORCE ROW LEVEL SECURITY;


--
-- Name: email_otps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_otps (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    user_id uuid NOT NULL,
    code_digest character varying NOT NULL,
    purpose character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    consumed_at timestamp(6) without time zone,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT email_otps_purpose_check CHECK (((purpose)::text = ANY ((ARRAY['login'::character varying, 'step_up'::character varying])::text[])))
);

ALTER TABLE ONLY public.email_otps FORCE ROW LEVEL SECURITY;


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
    updated_at timestamp(6) without time zone NOT NULL,
    academic_term_id uuid
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
-- Name: group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_memberships (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    submission_group_id uuid NOT NULL,
    student_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.group_memberships FORCE ROW LEVEL SECURITY;


--
-- Name: guardian_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardian_relationships (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    guardian_student_id uuid NOT NULL,
    relationship_kind character varying NOT NULL,
    is_primary_caregiver boolean DEFAULT false NOT NULL,
    custody_kind character varying,
    household_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT guardian_relationships_custody_kind_check CHECK (((custody_kind IS NULL) OR ((custody_kind)::text = ANY ((ARRAY['shared'::character varying, 'sole'::character varying, 'supervised'::character varying, 'unspecified'::character varying])::text[])))),
    CONSTRAINT guardian_relationships_relationship_kind_check CHECK (((relationship_kind)::text = ANY ((ARRAY['mother'::character varying, 'father'::character varying, 'grandparent'::character varying, 'legal_guardian'::character varying, 'sibling'::character varying, 'other'::character varying])::text[])))
);

ALTER TABLE ONLY public.guardian_relationships FORCE ROW LEVEL SECURITY;


--
-- Name: guardian_students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guardian_students (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    guardian_user_id uuid NOT NULL,
    student_id uuid NOT NULL,
    relationship character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_by_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT guardian_students_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[])))
);

ALTER TABLE ONLY public.guardian_students FORCE ROW LEVEL SECURITY;


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
-- Name: households; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.households (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    kind character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT households_kind_check CHECK (((kind)::text = ANY ((ARRAY['nuclear'::character varying, 'single_parent'::character varying, 'extended'::character varying, 'blended'::character varying, 'other'::character varying])::text[])))
);

ALTER TABLE ONLY public.households FORCE ROW LEVEL SECURITY;


--
-- Name: hps_term_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hps_term_snapshots (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    captured_on date NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.hps_term_snapshots FORCE ROW LEVEL SECURITY;


--
-- Name: installments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.installments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    payment_plan_id uuid NOT NULL,
    sequence integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    due_on date NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT installments_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'overdue'::character varying])::text[])))
);

ALTER TABLE ONLY public.installments FORCE ROW LEVEL SECURITY;


--
-- Name: institution_entitlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institution_entitlements (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    addon_id uuid NOT NULL,
    subscription_id uuid,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    valid_from date DEFAULT CURRENT_DATE NOT NULL,
    valid_until date,
    override_monthly_fee_cents bigint,
    override_included_quota bigint,
    override_unit_price_cents bigint,
    override_currency character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT institution_entitlements_override_currency_check CHECK (((override_currency IS NULL) OR (char_length((override_currency)::text) = 3))),
    CONSTRAINT institution_entitlements_override_included_quota_check CHECK (((override_included_quota IS NULL) OR (override_included_quota >= 0))),
    CONSTRAINT institution_entitlements_override_monthly_fee_cents_check CHECK (((override_monthly_fee_cents IS NULL) OR (override_monthly_fee_cents >= 0))),
    CONSTRAINT institution_entitlements_override_unit_price_cents_check CHECK (((override_unit_price_cents IS NULL) OR (override_unit_price_cents >= 0))),
    CONSTRAINT institution_entitlements_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'revoked'::character varying])::text[]))),
    CONSTRAINT institution_entitlements_valid_until_check CHECK (((valid_until IS NULL) OR (valid_until > valid_from)))
);


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
    updated_at timestamp(6) without time zone NOT NULL,
    default_currency character varying DEFAULT 'COP'::character varying NOT NULL
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
    updated_at timestamp(6) without time zone NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    CONSTRAINT institution_users_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying])::text[])))
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
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    user_id uuid NOT NULL,
    email character varying NOT NULL,
    token_digest character varying,
    status character varying DEFAULT 'sent'::character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    sent_at timestamp(6) without time zone NOT NULL,
    completed_at timestamp(6) without time zone,
    created_by_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invitations_status_check CHECK (((status)::text = ANY ((ARRAY['sent'::character varying, 'completed'::character varying, 'expired'::character varying, 'bounced'::character varying])::text[])))
);

ALTER TABLE ONLY public.invitations FORCE ROW LEVEL SECURITY;


--
-- Name: invoice_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_line_items (
    id uuid DEFAULT uuidv7() NOT NULL,
    invoice_id uuid NOT NULL,
    addon_id uuid,
    kind text NOT NULL,
    description text NOT NULL,
    quantity numeric NOT NULL,
    unit_price_cents bigint NOT NULL,
    amount_cents bigint NOT NULL,
    source_ref jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invoice_line_items_addon_coherence_check CHECK ((((kind = 'base_seats'::text) AND (addon_id IS NULL)) OR ((kind = ANY (ARRAY['addon_fee'::text, 'usage_overage'::text])) AND (addon_id IS NOT NULL)))),
    CONSTRAINT invoice_line_items_kind_check CHECK ((kind = ANY (ARRAY['base_seats'::text, 'addon_fee'::text, 'usage_overage'::text]))),
    CONSTRAINT invoice_line_items_quantity_check CHECK ((quantity >= (0)::numeric)),
    CONSTRAINT invoice_line_items_unit_price_cents_check CHECK ((unit_price_cents >= 0))
);


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    subscription_id uuid,
    period_start date NOT NULL,
    period_end date NOT NULL,
    currency text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    subtotal_cents bigint DEFAULT 0 NOT NULL,
    notes text,
    finalized_at timestamp with time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invoices_currency_check CHECK ((char_length(currency) = 3)),
    CONSTRAINT invoices_period_check CHECK ((period_end >= period_start)),
    CONSTRAINT invoices_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'finalized'::text, 'void'::text]))),
    CONSTRAINT invoices_subtotal_cents_check CHECK ((subtotal_cents >= 0))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    institution_user_id uuid,
    guardian_user_id uuid,
    body text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT messages_sender_identity_check CHECK ((num_nonnulls(institution_user_id, guardian_user_id) = 1))
);

ALTER TABLE ONLY public.messages FORCE ROW LEVEL SECURITY;


--
-- Name: payment_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_plans (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    name character varying NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    currency character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payment_plans_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);

ALTER TABLE ONLY public.payment_plans FORCE ROW LEVEL SECURITY;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_account_id uuid NOT NULL,
    charge_id uuid,
    amount numeric(12,2) NOT NULL,
    currency character varying NOT NULL,
    method character varying NOT NULL,
    status character varying DEFAULT 'completed'::character varying NOT NULL,
    paid_at timestamp(6) without time zone,
    idempotency_key character varying,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT payments_method_check CHECK (((method)::text = ANY ((ARRAY['cash'::character varying, 'card'::character varying, 'transfer'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT payments_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying, 'void'::character varying])::text[])))
);

ALTER TABLE ONLY public.payments FORCE ROW LEVEL SECURITY;


--
-- Name: peer_appreciation_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.peer_appreciation_tags (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    label character varying NOT NULL,
    category character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.peer_appreciation_tags FORCE ROW LEVEL SECURITY;


--
-- Name: peer_appreciations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.peer_appreciations (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    giver_kind character varying NOT NULL,
    giver_student_id uuid,
    giver_guardian_user_id uuid,
    academic_term_id uuid NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT peer_appreciations_giver_identity_check CHECK ((num_nonnulls(giver_student_id, giver_guardian_user_id) = 1)),
    CONSTRAINT peer_appreciations_giver_kind_check CHECK (((giver_kind)::text = ANY ((ARRAY['peer_student'::character varying, 'guardian'::character varying])::text[]))),
    CONSTRAINT peer_appreciations_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'withheld_by_moderation'::character varying])::text[])))
);

ALTER TABLE ONLY public.peer_appreciations FORCE ROW LEVEL SECURITY;


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
-- Name: plan_price_tiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plan_price_tiers (
    id uuid DEFAULT uuidv7() NOT NULL,
    plan_id uuid NOT NULL,
    min_students integer NOT NULL,
    max_students integer,
    price_per_student_cents bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT plan_price_tiers_max_students_check CHECK (((max_students IS NULL) OR (max_students > min_students))),
    CONSTRAINT plan_price_tiers_min_students_check CHECK ((min_students >= 0)),
    CONSTRAINT plan_price_tiers_price_per_student_cents_check CHECK ((price_per_student_cents >= 0))
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id uuid DEFAULT uuidv7() NOT NULL,
    key character varying NOT NULL,
    name character varying NOT NULL,
    description text,
    base_price_per_student_cents bigint NOT NULL,
    currency character varying DEFAULT 'COP'::character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT plans_base_price_per_student_cents_check CHECK ((base_price_per_student_cents >= 0)),
    CONSTRAINT plans_currency_check CHECK ((char_length((currency)::text) = 3)),
    CONSTRAINT plans_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'retired'::character varying])::text[])))
);


--
-- Name: platform_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_admins (
    id uuid DEFAULT uuidv7() NOT NULL,
    email public.citext NOT NULL,
    password_digest character varying NOT NULL,
    name character varying NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    last_sign_in_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    role character varying DEFAULT 'super_admin'::character varying NOT NULL,
    CONSTRAINT platform_admins_role_check CHECK (((role)::text = ANY ((ARRAY['super_admin'::character varying, 'billing_ops'::character varying, 'viewer'::character varying])::text[]))),
    CONSTRAINT platform_admins_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying])::text[])))
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
-- Name: referrals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referrals (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    counseling_case_id uuid NOT NULL,
    referred_to character varying NOT NULL,
    reason text,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT referrals_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'completed'::character varying, 'declined'::character varying])::text[])))
);

ALTER TABLE ONLY public.referrals FORCE ROW LEVEL SECURITY;


--
-- Name: report_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_cards (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    status character varying DEFAULT 'published'::character varying NOT NULL,
    lines_snapshot jsonb DEFAULT '[]'::jsonb NOT NULL,
    overall_average numeric(3,1),
    published_at timestamp(6) without time zone NOT NULL,
    published_by_staff_member_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT report_cards_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying])::text[])))
);

ALTER TABLE ONLY public.report_cards FORCE ROW LEVEL SECURITY;


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
    updated_at timestamp(6) without time zone NOT NULL,
    valid_from date DEFAULT CURRENT_DATE NOT NULL,
    valid_until date,
    CONSTRAINT role_assignments_valid_until_after_valid_from CHECK (((valid_until IS NULL) OR (valid_until >= valid_from)))
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
-- Name: roster_import_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roster_import_batches (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    kind character varying NOT NULL,
    academic_term_id uuid NOT NULL,
    status character varying DEFAULT 'uploaded'::character varying NOT NULL,
    summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT roster_import_batches_kind_check CHECK (((kind)::text = ANY ((ARRAY['students'::character varying, 'guardians'::character varying])::text[]))),
    CONSTRAINT roster_import_batches_status_check CHECK (((status)::text = ANY ((ARRAY['uploaded'::character varying, 'validated'::character varying, 'previewed'::character varying, 'committed'::character varying, 'failed'::character varying])::text[])))
);

ALTER TABLE ONLY public.roster_import_batches FORCE ROW LEVEL SECURITY;


--
-- Name: roster_import_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roster_import_rows (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    roster_import_batch_id uuid NOT NULL,
    line_number integer NOT NULL,
    raw jsonb NOT NULL,
    status character varying,
    message character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    resolved_record_id uuid,
    CONSTRAINT roster_import_rows_status_check CHECK (((status)::text = ANY ((ARRAY['valid'::character varying, 'error'::character varying, 'duplicate'::character varying, 'collision'::character varying])::text[])))
);

ALTER TABLE ONLY public.roster_import_rows FORCE ROW LEVEL SECURITY;


--
-- Name: rubric_cell_descriptors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rubric_cell_descriptors (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    rubric_criterion_id uuid NOT NULL,
    rubric_level_id uuid NOT NULL,
    descriptor text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.rubric_cell_descriptors FORCE ROW LEVEL SECURITY;


--
-- Name: rubric_criteria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rubric_criteria (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    rubric_template_id uuid NOT NULL,
    name character varying NOT NULL,
    weight numeric(6,2) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.rubric_criteria FORCE ROW LEVEL SECURITY;


--
-- Name: rubric_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rubric_evaluations (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    student_id uuid,
    submission_group_id uuid,
    levels_by_criterion jsonb DEFAULT '{}'::jsonb NOT NULL,
    evaluated_by_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT rubric_evaluations_identity_check CHECK ((num_nonnulls(student_id, submission_group_id) = 1))
);

ALTER TABLE ONLY public.rubric_evaluations FORCE ROW LEVEL SECURITY;


--
-- Name: rubric_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rubric_levels (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    rubric_template_id uuid NOT NULL,
    label character varying NOT NULL,
    points numeric(6,2) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.rubric_levels FORCE ROW LEVEL SECURITY;


--
-- Name: rubric_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rubric_templates (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    authored_by_user_id uuid NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.rubric_templates FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: seat_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seat_assignments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    classroom_layout_id uuid NOT NULL,
    student_id uuid NOT NULL,
    "row" smallint NOT NULL,
    col smallint NOT NULL,
    effective_from date NOT NULL,
    effective_until date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT seat_assignments_col_nonneg_check CHECK ((col >= 0)),
    CONSTRAINT seat_assignments_effective_range_check CHECK (((effective_until IS NULL) OR (effective_until >= effective_from))),
    CONSTRAINT seat_assignments_row_nonneg_check CHECK (("row" >= 0))
);

ALTER TABLE ONLY public.seat_assignments FORCE ROW LEVEL SECURITY;


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
-- Name: session_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_notes (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    counseling_case_id uuid NOT NULL,
    author_id uuid NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    body text NOT NULL,
    confidential boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.session_notes FORCE ROW LEVEL SECURITY;


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
-- Name: student_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_accounts (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    balance numeric(12,2) DEFAULT 0.0 NOT NULL,
    currency character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.student_accounts FORCE ROW LEVEL SECURITY;


--
-- Name: student_affinities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_affinities (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    taxonomy_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    source character varying NOT NULL,
    context character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT student_affinities_context_check CHECK (((context)::text = ANY ((ARRAY['in_school'::character varying, 'out_of_school'::character varying])::text[]))),
    CONSTRAINT student_affinities_source_check CHECK (((source)::text = ANY ((ARRAY['teacher_observed'::character varying, 'guardian_reported'::character varying, 'self_reported'::character varying])::text[])))
);

ALTER TABLE ONLY public.student_affinities FORCE ROW LEVEL SECURITY;


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
-- Name: student_headcount_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_headcount_snapshots (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    as_of_date date NOT NULL,
    headcount integer NOT NULL,
    academic_term_label text,
    breakdown jsonb DEFAULT '{}'::jsonb NOT NULL,
    source text DEFAULT 'tenant_push'::text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT student_headcount_snapshots_headcount_check CHECK ((headcount >= 0))
);


--
-- Name: student_placements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_placements (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    student_id uuid NOT NULL,
    section_id uuid NOT NULL,
    grade_level_id uuid NOT NULL,
    academic_term_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_until date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT student_placements_valid_range_check CHECK (((valid_until IS NULL) OR (valid_until >= valid_from)))
);

ALTER TABLE ONLY public.student_placements FORCE ROW LEVEL SECURITY;


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
    national_id character varying,
    user_id uuid,
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
-- Name: submission_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submission_attachments (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    submission_id uuid NOT NULL,
    attached_by_user_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.submission_attachments FORCE ROW LEVEL SECURITY;


--
-- Name: submission_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submission_groups (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.submission_groups FORCE ROW LEVEL SECURITY;


--
-- Name: submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.submissions (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    student_id uuid,
    body text NOT NULL,
    submitted_by_user_id uuid,
    submitted_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    submission_group_id uuid,
    CONSTRAINT submissions_identity_check CHECK ((num_nonnulls(student_id, submission_group_id) = 1))
);

ALTER TABLE ONLY public.submissions FORCE ROW LEVEL SECURITY;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    plan_id uuid,
    plan_key character varying NOT NULL,
    base_price_per_student_cents bigint NOT NULL,
    currency character varying DEFAULT 'COP'::character varying NOT NULL,
    price_tiers_snapshot jsonb DEFAULT '[]'::jsonb NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    starts_on date NOT NULL,
    ends_on date,
    signed_at timestamp(6) without time zone DEFAULT now() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT subscriptions_base_price_per_student_cents_check CHECK ((base_price_per_student_cents >= 0)),
    CONSTRAINT subscriptions_currency_check CHECK ((char_length((currency)::text) = 3)),
    CONSTRAINT subscriptions_ends_on_check CHECK (((ends_on IS NULL) OR (ends_on > starts_on))),
    CONSTRAINT subscriptions_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'ended'::character varying])::text[])))
);


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
-- Name: usage_daily_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_daily_rollups (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    addon_id uuid NOT NULL,
    unit text NOT NULL,
    usage_date date NOT NULL,
    total_quantity bigint DEFAULT 0 NOT NULL,
    event_count integer DEFAULT 0 NOT NULL,
    rolled_up_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT usage_daily_rollups_event_count_check CHECK ((event_count >= 0)),
    CONSTRAINT usage_daily_rollups_total_quantity_check CHECK ((total_quantity >= 0))
);


--
-- Name: usage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usage_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    institution_id uuid NOT NULL,
    addon_id uuid NOT NULL,
    unit text NOT NULL,
    quantity bigint DEFAULT 1 NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    idempotency_key text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT usage_events_quantity_check CHECK ((quantity > 0))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT uuidv7() NOT NULL,
    email public.citext NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    password_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    national_id character varying
);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: academic_terms academic_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_terms
    ADD CONSTRAINT academic_terms_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity_enrollments activity_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_enrollments
    ADD CONSTRAINT activity_enrollments_pkey PRIMARY KEY (id);


--
-- Name: addons addons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addons
    ADD CONSTRAINT addons_pkey PRIMARY KEY (id);


--
-- Name: affinity_taxonomy affinity_taxonomy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.affinity_taxonomy
    ADD CONSTRAINT affinity_taxonomy_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


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
-- Name: assignment_materials assignment_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignment_materials
    ADD CONSTRAINT assignment_materials_pkey PRIMARY KEY (id);


--
-- Name: assignments assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (id);


--
-- Name: attendance_records attendance_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_pkey PRIMARY KEY (id);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);


--
-- Name: care_auras care_auras_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_auras
    ADD CONSTRAINT care_auras_pkey PRIMARY KEY (id);


--
-- Name: character_dimension_scores character_dimension_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimension_scores
    ADD CONSTRAINT character_dimension_scores_pkey PRIMARY KEY (id);


--
-- Name: character_dimensions character_dimensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimensions
    ADD CONSTRAINT character_dimensions_pkey PRIMARY KEY (id);


--
-- Name: character_evaluations character_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT character_evaluations_pkey PRIMARY KEY (id);


--
-- Name: character_frameworks character_frameworks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_frameworks
    ADD CONSTRAINT character_frameworks_pkey PRIMARY KEY (id);


--
-- Name: character_levels character_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_levels
    ADD CONSTRAINT character_levels_pkey PRIMARY KEY (id);


--
-- Name: character_program_consents character_program_consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_program_consents
    ADD CONSTRAINT character_program_consents_pkey PRIMARY KEY (id);


--
-- Name: charges charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (id);


--
-- Name: classroom_layouts classroom_layouts_no_overlapping_versions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classroom_layouts
    ADD CONSTRAINT classroom_layouts_no_overlapping_versions EXCLUDE USING gist (institution_id WITH =, section_id WITH =, academic_term_id WITH =, daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: classroom_layouts classroom_layouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classroom_layouts
    ADD CONSTRAINT classroom_layouts_pkey PRIMARY KEY (id);


--
-- Name: control_plane_audit_events control_plane_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_audit_events
    ADD CONSTRAINT control_plane_audit_events_pkey PRIMARY KEY (id);


--
-- Name: control_plane_email_otps control_plane_email_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_email_otps
    ADD CONSTRAINT control_plane_email_otps_pkey PRIMARY KEY (id);


--
-- Name: control_plane_sessions control_plane_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_sessions
    ADD CONSTRAINT control_plane_sessions_pkey PRIMARY KEY (id);


--
-- Name: conversation_participants conversation_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT conversation_participants_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: counseling_cases counseling_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counseling_cases
    ADD CONSTRAINT counseling_cases_pkey PRIMARY KEY (id);


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
-- Name: disciplinary_logs disciplinary_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disciplinary_logs
    ADD CONSTRAINT disciplinary_logs_pkey PRIMARY KEY (id);


--
-- Name: email_otps email_otps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_otps
    ADD CONSTRAINT email_otps_pkey PRIMARY KEY (id);


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
-- Name: group_memberships group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pkey PRIMARY KEY (id);


--
-- Name: guardian_relationships guardian_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_relationships
    ADD CONSTRAINT guardian_relationships_pkey PRIMARY KEY (id);


--
-- Name: guardian_students guardian_students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_students
    ADD CONSTRAINT guardian_students_pkey PRIMARY KEY (id);


--
-- Name: guardians guardians_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardians
    ADD CONSTRAINT guardians_pkey PRIMARY KEY (id);


--
-- Name: households households_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT households_pkey PRIMARY KEY (id);


--
-- Name: hps_term_snapshots hps_term_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hps_term_snapshots
    ADD CONSTRAINT hps_term_snapshots_pkey PRIMARY KEY (id);


--
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT installments_pkey PRIMARY KEY (id);


--
-- Name: institution_entitlements institution_entitlements_no_overlapping_periods; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT institution_entitlements_no_overlapping_periods EXCLUDE USING gist (institution_id WITH =, addon_id WITH =, daterange(valid_from, COALESCE(valid_until, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: institution_entitlements institution_entitlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT institution_entitlements_pkey PRIMARY KEY (id);


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
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: invoice_line_items invoice_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT invoice_line_items_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: payment_plans payment_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_plans
    ADD CONSTRAINT payment_plans_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: peer_appreciation_tags peer_appreciation_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciation_tags
    ADD CONSTRAINT peer_appreciation_tags_pkey PRIMARY KEY (id);


--
-- Name: peer_appreciations peer_appreciations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT peer_appreciations_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: plan_price_tiers plan_price_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_price_tiers
    ADD CONSTRAINT plan_price_tiers_pkey PRIMARY KEY (id);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: platform_admins platform_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admins
    ADD CONSTRAINT platform_admins_pkey PRIMARY KEY (id);


--
-- Name: programs programs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT programs_pkey PRIMARY KEY (id);


--
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);


--
-- Name: report_cards report_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT report_cards_pkey PRIMARY KEY (id);


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
-- Name: roster_import_batches roster_import_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_batches
    ADD CONSTRAINT roster_import_batches_pkey PRIMARY KEY (id);


--
-- Name: roster_import_rows roster_import_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_rows
    ADD CONSTRAINT roster_import_rows_pkey PRIMARY KEY (id);


--
-- Name: rubric_cell_descriptors rubric_cell_descriptors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_cell_descriptors
    ADD CONSTRAINT rubric_cell_descriptors_pkey PRIMARY KEY (id);


--
-- Name: rubric_criteria rubric_criteria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_criteria
    ADD CONSTRAINT rubric_criteria_pkey PRIMARY KEY (id);


--
-- Name: rubric_evaluations rubric_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT rubric_evaluations_pkey PRIMARY KEY (id);


--
-- Name: rubric_levels rubric_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_levels
    ADD CONSTRAINT rubric_levels_pkey PRIMARY KEY (id);


--
-- Name: rubric_templates rubric_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_templates
    ADD CONSTRAINT rubric_templates_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: seat_assignments seat_assignments_no_double_booked_seat; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT seat_assignments_no_double_booked_seat EXCLUDE USING gist (institution_id WITH =, classroom_layout_id WITH =, "row" WITH =, col WITH =, daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: seat_assignments seat_assignments_no_two_seats_per_student; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT seat_assignments_no_two_seats_per_student EXCLUDE USING gist (institution_id WITH =, classroom_layout_id WITH =, student_id WITH =, daterange(effective_from, COALESCE(effective_until, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: seat_assignments seat_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT seat_assignments_pkey PRIMARY KEY (id);


--
-- Name: sections sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT sections_pkey PRIMARY KEY (id);


--
-- Name: session_notes session_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_notes
    ADD CONSTRAINT session_notes_pkey PRIMARY KEY (id);


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
-- Name: student_accounts student_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_accounts
    ADD CONSTRAINT student_accounts_pkey PRIMARY KEY (id);


--
-- Name: student_affinities student_affinities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_affinities
    ADD CONSTRAINT student_affinities_pkey PRIMARY KEY (id);


--
-- Name: student_guardians student_guardians_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_guardians
    ADD CONSTRAINT student_guardians_pkey PRIMARY KEY (id);


--
-- Name: student_headcount_snapshots student_headcount_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_headcount_snapshots
    ADD CONSTRAINT student_headcount_snapshots_pkey PRIMARY KEY (id);


--
-- Name: student_placements student_placements_no_overlapping_periods; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT student_placements_no_overlapping_periods EXCLUDE USING gist (institution_id WITH =, student_id WITH =, daterange(valid_from, COALESCE(valid_until, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: student_placements student_placements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT student_placements_pkey PRIMARY KEY (id);


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
-- Name: submission_attachments submission_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_attachments
    ADD CONSTRAINT submission_attachments_pkey PRIMARY KEY (id);


--
-- Name: submission_groups submission_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_groups
    ADD CONSTRAINT submission_groups_pkey PRIMARY KEY (id);


--
-- Name: submissions submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT submissions_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_no_overlapping_periods; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_no_overlapping_periods EXCLUDE USING gist (institution_id WITH =, daterange(starts_on, COALESCE(ends_on, 'infinity'::date), '[)'::text) WITH &&);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


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
-- Name: usage_daily_rollups usage_daily_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_daily_rollups
    ADD CONSTRAINT usage_daily_rollups_pkey PRIMARY KEY (id);


--
-- Name: usage_events usage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_activities_on_institution_instructor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activities_on_institution_instructor ON public.activities USING btree (institution_id, instructor_staff_member_id);


--
-- Name: idx_activities_on_institution_term_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activities_on_institution_term_status ON public.activities USING btree (institution_id, academic_term_id, status);


--
-- Name: idx_activity_enrollments_active_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_activity_enrollments_active_unique ON public.activity_enrollments USING btree (institution_id, activity_id, student_id) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_activity_enrollments_on_institution_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_enrollments_on_institution_activity ON public.activity_enrollments USING btree (institution_id, activity_id);


--
-- Name: idx_activity_enrollments_on_institution_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_enrollments_on_institution_student ON public.activity_enrollments USING btree (institution_id, student_id);


--
-- Name: idx_affinity_taxonomy_on_inst_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_affinity_taxonomy_on_inst_active ON public.affinity_taxonomy USING btree (institution_id, active);


--
-- Name: idx_affinity_taxonomy_on_inst_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_affinity_taxonomy_on_inst_department ON public.affinity_taxonomy USING btree (institution_id, department_id);


--
-- Name: idx_affinity_taxonomy_on_inst_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_affinity_taxonomy_on_inst_parent ON public.affinity_taxonomy USING btree (institution_id, parent_id);


--
-- Name: idx_affinity_taxonomy_on_search_tsv; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_affinity_taxonomy_on_search_tsv ON public.affinity_taxonomy USING gin (search_tsv);


--
-- Name: idx_assignment_materials_on_institution_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assignment_materials_on_institution_assignment ON public.assignment_materials USING btree (institution_id, assignment_id);


--
-- Name: idx_assignments_on_institution_subject_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assignments_on_institution_subject_status ON public.assignments USING btree (institution_id, subject_id, status);


--
-- Name: idx_care_auras_on_inst_student_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_care_auras_on_inst_student_from ON public.care_auras USING btree (institution_id, student_id, effective_from);


--
-- Name: idx_care_auras_one_active_per_student_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_care_auras_one_active_per_student_kind ON public.care_auras USING btree (institution_id, student_id, aura_kind) WHERE (effective_until IS NULL);


--
-- Name: idx_character_dimension_scores_on_inst_eval; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_character_dimension_scores_on_inst_eval ON public.character_dimension_scores USING btree (institution_id, evaluation_id);


--
-- Name: idx_character_dimensions_on_inst_framework_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_character_dimensions_on_inst_framework_pos ON public.character_dimensions USING btree (institution_id, framework_id, "position");


--
-- Name: idx_character_evaluations_unique_author; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_character_evaluations_unique_author ON public.character_evaluations USING btree (institution_id, student_id, academic_term_id, framework_id, author_institution_user_id);


--
-- Name: idx_character_frameworks_on_inst_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_character_frameworks_on_inst_status ON public.character_frameworks USING btree (institution_id, status);


--
-- Name: idx_character_levels_on_inst_dimension_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_character_levels_on_inst_dimension_pos ON public.character_levels USING btree (institution_id, dimension_id, "position");


--
-- Name: idx_character_program_consents_active_per_student; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_character_program_consents_active_per_student ON public.character_program_consents USING btree (institution_id, student_id) WHERE (revoked_at IS NULL);


--
-- Name: idx_charges_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_charges_idempotency ON public.charges USING btree (institution_id, idempotency_key);


--
-- Name: idx_classroom_layouts_on_inst_section_term_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_classroom_layouts_on_inst_section_term_from ON public.classroom_layouts USING btree (institution_id, section_id, academic_term_id, effective_from);


--
-- Name: idx_disciplinary_logs_on_inst_student_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disciplinary_logs_on_inst_student_occurred ON public.disciplinary_logs USING btree (institution_id, student_id, occurred_at);


--
-- Name: idx_group_memberships_on_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_memberships_on_group ON public.group_memberships USING btree (institution_id, submission_group_id);


--
-- Name: idx_group_memberships_unique_student_per_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_group_memberships_unique_student_per_assignment ON public.group_memberships USING btree (institution_id, assignment_id, student_id);


--
-- Name: idx_guardian_relationships_on_inst_household; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_guardian_relationships_on_inst_household ON public.guardian_relationships USING btree (institution_id, household_id);


--
-- Name: idx_guardian_relationships_unique_link; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_guardian_relationships_unique_link ON public.guardian_relationships USING btree (institution_id, guardian_student_id);


--
-- Name: idx_households_on_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_households_on_institution ON public.households USING btree (institution_id);


--
-- Name: idx_hps_term_snapshots_one_per_student_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_hps_term_snapshots_one_per_student_term ON public.hps_term_snapshots USING btree (institution_id, student_id, academic_term_id);


--
-- Name: idx_installments_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_installments_seq ON public.installments USING btree (institution_id, payment_plan_id, sequence);


--
-- Name: idx_messages_on_conversation_and_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_on_conversation_and_time ON public.messages USING btree (institution_id, conversation_id, created_at);


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
-- Name: idx_participants_on_guardian_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_participants_on_guardian_user ON public.conversation_participants USING btree (institution_id, guardian_user_id);


--
-- Name: idx_participants_on_institution_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_participants_on_institution_user ON public.conversation_participants USING btree (institution_id, institution_user_id);


--
-- Name: idx_participants_unique_guardian_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_participants_unique_guardian_user ON public.conversation_participants USING btree (institution_id, conversation_id, guardian_user_id);


--
-- Name: idx_participants_unique_institution_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_participants_unique_institution_user ON public.conversation_participants USING btree (institution_id, conversation_id, institution_user_id);


--
-- Name: idx_payments_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payments_idempotency ON public.payments USING btree (institution_id, idempotency_key);


--
-- Name: idx_peer_appreciation_tags_on_inst_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_peer_appreciation_tags_on_inst_active ON public.peer_appreciation_tags USING btree (institution_id, active);


--
-- Name: idx_peer_appreciations_active_guardian_giver; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_peer_appreciations_active_guardian_giver ON public.peer_appreciations USING btree (institution_id, student_id, tag_id, giver_guardian_user_id, academic_term_id) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_peer_appreciations_active_peer_giver; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_peer_appreciations_active_peer_giver ON public.peer_appreciations USING btree (institution_id, student_id, tag_id, giver_student_id, academic_term_id) WHERE ((status)::text = 'active'::text);


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
-- Name: idx_rubric_cell_descriptors_on_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rubric_cell_descriptors_on_institution ON public.rubric_cell_descriptors USING btree (institution_id);


--
-- Name: idx_rubric_cell_descriptors_unique_cell; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rubric_cell_descriptors_unique_cell ON public.rubric_cell_descriptors USING btree (rubric_criterion_id, rubric_level_id);


--
-- Name: idx_rubric_criteria_on_institution_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rubric_criteria_on_institution_template ON public.rubric_criteria USING btree (institution_id, rubric_template_id);


--
-- Name: idx_rubric_evaluations_unique_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rubric_evaluations_unique_group ON public.rubric_evaluations USING btree (institution_id, assignment_id, submission_group_id);


--
-- Name: idx_rubric_evaluations_unique_student; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rubric_evaluations_unique_student ON public.rubric_evaluations USING btree (institution_id, assignment_id, student_id);


--
-- Name: idx_rubric_levels_on_institution_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rubric_levels_on_institution_template ON public.rubric_levels USING btree (institution_id, rubric_template_id);


--
-- Name: idx_rubric_templates_on_institution_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rubric_templates_on_institution_author ON public.rubric_templates USING btree (institution_id, authored_by_user_id);


--
-- Name: idx_seat_assignments_on_inst_layout_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_seat_assignments_on_inst_layout_from ON public.seat_assignments USING btree (institution_id, classroom_layout_id, effective_from);


--
-- Name: idx_student_affinities_on_inst_taxonomy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_affinities_on_inst_taxonomy ON public.student_affinities USING btree (institution_id, taxonomy_id);


--
-- Name: idx_student_affinities_unique_link; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_student_affinities_unique_link ON public.student_affinities USING btree (institution_id, student_id, taxonomy_id, academic_term_id);


--
-- Name: idx_student_placements_on_inst_student_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_student_placements_on_inst_student_from ON public.student_placements USING btree (institution_id, student_id, valid_from);


--
-- Name: idx_submission_attachments_on_institution_submission; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_submission_attachments_on_institution_submission ON public.submission_attachments USING btree (institution_id, submission_id);


--
-- Name: idx_submission_groups_on_institution_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_submission_groups_on_institution_assignment ON public.submission_groups USING btree (institution_id, assignment_id);


--
-- Name: idx_submissions_unique_assignment_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_submissions_unique_assignment_group ON public.submissions USING btree (institution_id, assignment_id, submission_group_id);


--
-- Name: idx_submissions_unique_assignment_student; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_submissions_unique_assignment_student ON public.submissions USING btree (institution_id, assignment_id, student_id);


--
-- Name: index_academic_terms_on_institution_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_academic_terms_on_institution_id_and_code ON public.academic_terms USING btree (institution_id, code);


--
-- Name: index_academic_terms_one_active_per_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_academic_terms_one_active_per_institution ON public.academic_terms USING btree (institution_id) WHERE ((status)::text = 'active'::text);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_addons_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_addons_on_key ON public.addons USING btree (key);


--
-- Name: index_announcements_on_institution_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_institution_and_published_at ON public.announcements USING btree (institution_id, published_at);


--
-- Name: index_assessments_on_assignment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_assignment_id ON public.assessments USING btree (assignment_id);


--
-- Name: index_assessments_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_enrollment_id ON public.assessments USING btree (enrollment_id);


--
-- Name: index_assessments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_institution_id ON public.assessments USING btree (institution_id);


--
-- Name: index_attendance_records_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendance_records_on_group_id ON public.attendance_records USING btree (group_id);


--
-- Name: index_attendance_records_on_institution_group_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendance_records_on_institution_group_date ON public.attendance_records USING btree (institution_id, group_id, date);


--
-- Name: index_attendance_records_on_institution_student_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_attendance_records_on_institution_student_date ON public.attendance_records USING btree (institution_id, student_id, date);


--
-- Name: index_attendance_records_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_attendance_records_on_student_id ON public.attendance_records USING btree (student_id);


--
-- Name: index_audit_events_on_institution_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_institution_and_action ON public.audit_events USING btree (institution_id, action);


--
-- Name: index_audit_events_on_institution_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_institution_and_created_at ON public.audit_events USING btree (institution_id, created_at DESC);


--
-- Name: index_audit_events_on_institution_and_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_institution_and_target ON public.audit_events USING btree (institution_id, target_type, target_id);


--
-- Name: index_calendar_events_on_institution_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_institution_and_starts_at ON public.calendar_events USING btree (institution_id, starts_at);


--
-- Name: index_calendar_events_on_scope_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_scope_grade_level_id ON public.calendar_events USING btree (scope_grade_level_id);


--
-- Name: index_calendar_events_on_scope_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_scope_group_id ON public.calendar_events USING btree (scope_group_id);


--
-- Name: index_charges_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_institution_id ON public.charges USING btree (institution_id);


--
-- Name: index_charges_on_institution_id_and_invoice_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_charges_on_institution_id_and_invoice_number ON public.charges USING btree (institution_id, invoice_number);


--
-- Name: index_charges_on_institution_id_and_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_institution_id_and_student_id ON public.charges USING btree (institution_id, student_id);


--
-- Name: index_control_plane_email_otps_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_control_plane_email_otps_on_expires_at ON public.control_plane_email_otps USING btree (expires_at);


--
-- Name: index_control_plane_email_otps_on_platform_admin_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_control_plane_email_otps_on_platform_admin_id ON public.control_plane_email_otps USING btree (platform_admin_id);


--
-- Name: index_control_plane_sessions_on_platform_admin_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_control_plane_sessions_on_platform_admin_id ON public.control_plane_sessions USING btree (platform_admin_id);


--
-- Name: index_conversations_on_institution_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_institution_and_status ON public.conversations USING btree (institution_id, status);


--
-- Name: index_counseling_cases_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counseling_cases_on_institution_id ON public.counseling_cases USING btree (institution_id);


--
-- Name: index_counseling_cases_on_institution_id_and_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counseling_cases_on_institution_id_and_student_id ON public.counseling_cases USING btree (institution_id, student_id);


--
-- Name: index_counseling_cases_on_opened_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counseling_cases_on_opened_by_id ON public.counseling_cases USING btree (opened_by_id);


--
-- Name: index_cp_audit_events_on_platform_admin_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cp_audit_events_on_platform_admin_and_action ON public.control_plane_audit_events USING btree (platform_admin_id, action);


--
-- Name: index_cp_audit_events_on_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cp_audit_events_on_target ON public.control_plane_audit_events USING btree (target_type, target_id);


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
-- Name: index_email_otps_on_institution_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_otps_on_institution_and_user ON public.email_otps USING btree (institution_id, user_id);


--
-- Name: index_employment_periods_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employment_periods_on_institution_id ON public.employment_periods USING btree (institution_id);


--
-- Name: index_employment_periods_on_institution_id_and_staff_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_employment_periods_on_institution_id_and_staff_member_id ON public.employment_periods USING btree (institution_id, staff_member_id);


--
-- Name: index_enrollments_on_institution_and_academic_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_enrollments_on_institution_and_academic_term ON public.enrollments USING btree (institution_id, academic_term_id);


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
-- Name: index_entitlements_one_active_per_institution_addon; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entitlements_one_active_per_institution_addon ON public.institution_entitlements USING btree (institution_id, addon_id) WHERE ((status)::text = 'active'::text);


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
-- Name: index_guardian_students_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_guardian_students_uniqueness ON public.guardian_students USING btree (institution_id, guardian_user_id, student_id);


--
-- Name: index_guardians_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guardians_on_institution_id ON public.guardians USING btree (institution_id);


--
-- Name: index_headcount_snapshots_on_institution_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_headcount_snapshots_on_institution_and_date ON public.student_headcount_snapshots USING btree (institution_id, as_of_date);


--
-- Name: index_installments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_installments_on_institution_id ON public.installments USING btree (institution_id);


--
-- Name: index_institution_entitlements_on_addon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_institution_entitlements_on_addon_id ON public.institution_entitlements USING btree (addon_id);


--
-- Name: index_institution_entitlements_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_institution_entitlements_on_institution_id ON public.institution_entitlements USING btree (institution_id);


--
-- Name: index_institution_entitlements_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_institution_entitlements_on_subscription_id ON public.institution_entitlements USING btree (subscription_id);


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
-- Name: index_invitations_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_token_digest ON public.invitations USING btree (token_digest) WHERE (token_digest IS NOT NULL);


--
-- Name: index_invitations_one_live_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_one_live_per_user ON public.invitations USING btree (institution_id, user_id) WHERE ((status)::text = 'sent'::text);


--
-- Name: index_invoice_line_items_on_addon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_line_items_on_addon_id ON public.invoice_line_items USING btree (addon_id);


--
-- Name: index_invoice_line_items_on_invoice_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoice_line_items_on_invoice_id ON public.invoice_line_items USING btree (invoice_id);


--
-- Name: index_invoices_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_institution_id ON public.invoices USING btree (institution_id);


--
-- Name: index_invoices_on_subscription_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_subscription_id ON public.invoices USING btree (subscription_id);


--
-- Name: index_invoices_one_per_institution_and_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_one_per_institution_and_period ON public.invoices USING btree (institution_id, period_start, period_end) WHERE (status <> 'void'::text);


--
-- Name: index_payment_plans_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_plans_on_institution_id ON public.payment_plans USING btree (institution_id);


--
-- Name: index_payment_plans_on_institution_id_and_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_plans_on_institution_id_and_student_id ON public.payment_plans USING btree (institution_id, student_id);


--
-- Name: index_payments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_institution_id ON public.payments USING btree (institution_id);


--
-- Name: index_payments_on_institution_id_and_student_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_institution_id_and_student_account_id ON public.payments USING btree (institution_id, student_account_id);


--
-- Name: index_permissions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_key ON public.permissions USING btree (key);


--
-- Name: index_plan_price_tiers_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_plan_price_tiers_on_plan_id ON public.plan_price_tiers USING btree (plan_id);


--
-- Name: index_plans_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plans_on_key ON public.plans USING btree (key);


--
-- Name: index_platform_admins_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_platform_admins_on_email ON public.platform_admins USING btree (email);


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
-- Name: index_referrals_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referrals_on_institution_id ON public.referrals USING btree (institution_id);


--
-- Name: index_referrals_on_institution_id_and_counseling_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referrals_on_institution_id_and_counseling_case_id ON public.referrals USING btree (institution_id, counseling_case_id);


--
-- Name: index_report_cards_on_academic_term_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_academic_term_id ON public.report_cards USING btree (academic_term_id);


--
-- Name: index_report_cards_on_institution_student_term; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_report_cards_on_institution_student_term ON public.report_cards USING btree (institution_id, student_id, academic_term_id);


--
-- Name: index_report_cards_on_institution_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_institution_term ON public.report_cards USING btree (institution_id, academic_term_id);


--
-- Name: index_report_cards_on_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_report_cards_on_student_id ON public.report_cards USING btree (student_id);


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
-- Name: index_roster_import_batches_on_institution_and_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roster_import_batches_on_institution_and_term ON public.roster_import_batches USING btree (institution_id, academic_term_id);


--
-- Name: index_roster_import_rows_on_institution_and_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roster_import_rows_on_institution_and_batch ON public.roster_import_rows USING btree (institution_id, roster_import_batch_id);


--
-- Name: index_sections_on_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_grade_level_id ON public.sections USING btree (grade_level_id);


--
-- Name: index_sections_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sections_on_institution_id ON public.sections USING btree (institution_id);


--
-- Name: index_session_notes_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_notes_on_author_id ON public.session_notes USING btree (author_id);


--
-- Name: index_session_notes_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_notes_on_institution_id ON public.session_notes USING btree (institution_id);


--
-- Name: index_session_notes_on_institution_id_and_counseling_case_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_session_notes_on_institution_id_and_counseling_case_id ON public.session_notes USING btree (institution_id, counseling_case_id);


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
-- Name: index_student_accounts_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_accounts_on_institution_id ON public.student_accounts USING btree (institution_id);


--
-- Name: index_student_accounts_on_institution_id_and_student_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_student_accounts_on_institution_id_and_student_id ON public.student_accounts USING btree (institution_id, student_id);


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
-- Name: index_student_headcount_snapshots_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_student_headcount_snapshots_on_institution_id ON public.student_headcount_snapshots USING btree (institution_id);


--
-- Name: index_students_on_grade_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_students_on_grade_level_id ON public.students USING btree (grade_level_id);


--
-- Name: index_students_on_institution_and_national_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_institution_and_national_id ON public.students USING btree (institution_id, national_id) WHERE (national_id IS NOT NULL);


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
-- Name: index_students_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_students_on_user_id ON public.students USING btree (user_id) WHERE (user_id IS NOT NULL);


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
-- Name: index_subscriptions_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_institution_id ON public.subscriptions USING btree (institution_id);


--
-- Name: index_subscriptions_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_plan_id ON public.subscriptions USING btree (plan_id);


--
-- Name: index_subscriptions_one_active_per_institution; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_subscriptions_one_active_per_institution ON public.subscriptions USING btree (institution_id) WHERE ((status)::text = 'active'::text);


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
-- Name: index_usage_daily_rollups_on_addon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_daily_rollups_on_addon_id ON public.usage_daily_rollups USING btree (addon_id);


--
-- Name: index_usage_daily_rollups_on_bucket; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_daily_rollups_on_bucket ON public.usage_daily_rollups USING btree (institution_id, addon_id, unit, usage_date);


--
-- Name: index_usage_daily_rollups_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_daily_rollups_on_institution_id ON public.usage_daily_rollups USING btree (institution_id);


--
-- Name: index_usage_events_for_rollup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_for_rollup ON public.usage_events USING btree (institution_id, addon_id, occurred_at);


--
-- Name: index_usage_events_on_addon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_on_addon_id ON public.usage_events USING btree (addon_id);


--
-- Name: index_usage_events_on_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usage_events_on_idempotency ON public.usage_events USING btree (institution_id, addon_id, idempotency_key);


--
-- Name: index_usage_events_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usage_events_on_institution_id ON public.usage_events USING btree (institution_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_national_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_national_id ON public.users USING btree (national_id) WHERE (national_id IS NOT NULL);


--
-- Name: sections fk_rails_0265c1c0de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_0265c1c0de FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: submission_attachments fk_rails_05c03d867a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_attachments
    ADD CONSTRAINT fk_rails_05c03d867a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: rubric_evaluations fk_rails_05f3c0a0d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT fk_rails_05f3c0a0d9 FOREIGN KEY (submission_group_id) REFERENCES public.submission_groups(id) ON DELETE CASCADE;


--
-- Name: rubric_cell_descriptors fk_rails_08263dde9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_cell_descriptors
    ADD CONSTRAINT fk_rails_08263dde9d FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: report_cards fk_rails_0eed72e3b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_0eed72e3b0 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: disciplinary_logs fk_rails_0f6f9b9c53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disciplinary_logs
    ADD CONSTRAINT fk_rails_0f6f9b9c53 FOREIGN KEY (reported_by_institution_user_id) REFERENCES public.institution_users(id) ON DELETE RESTRICT;


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
-- Name: usage_daily_rollups fk_rails_11b586ee6f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_daily_rollups
    ADD CONSTRAINT fk_rails_11b586ee6f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


--
-- Name: enrollments fk_rails_130022d62b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_130022d62b FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: students fk_rails_148c9e88f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_148c9e88f4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: teaching_assignments fk_rails_1535481200; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT fk_rails_1535481200 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: group_memberships fk_rails_16f363265c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_16f363265c FOREIGN KEY (submission_group_id) REFERENCES public.submission_groups(id) ON DELETE CASCADE;


--
-- Name: roster_import_rows fk_rails_17b37d6b3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_rows
    ADD CONSTRAINT fk_rails_17b37d6b3e FOREIGN KEY (roster_import_batch_id) REFERENCES public.roster_import_batches(id) ON DELETE CASCADE;


--
-- Name: student_placements fk_rails_18193fb5e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT fk_rails_18193fb5e3 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: submissions fk_rails_19447e9b4d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT fk_rails_19447e9b4d FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_1b26c6deb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_1b26c6deb0 FOREIGN KEY (program_id) REFERENCES public.programs(id);


--
-- Name: attendance_records fk_rails_1b3d8c1086; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT fk_rails_1b3d8c1086 FOREIGN KEY (recorded_by_staff_member_id) REFERENCES public.staff_members(id) ON DELETE SET NULL;


--
-- Name: conversations fk_rails_1c8ed89d7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_1c8ed89d7f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: student_placements fk_rails_1c9fb41b84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT fk_rails_1c9fb41b84 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: roster_import_batches fk_rails_1ddd8e9cad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_batches
    ADD CONSTRAINT fk_rails_1ddd8e9cad FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: invitations fk_rails_1e69da856c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_1e69da856c FOREIGN KEY (created_by_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: peer_appreciations fk_rails_20ac912a33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_20ac912a33 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: attendance_records fk_rails_24851af891; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT fk_rails_24851af891 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: hps_term_snapshots fk_rails_2691923cf2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hps_term_snapshots
    ADD CONSTRAINT fk_rails_2691923cf2 FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: student_accounts fk_rails_26abc07ba9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_accounts
    ADD CONSTRAINT fk_rails_26abc07ba9 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: employment_periods fk_rails_271ac67781; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT fk_rails_271ac67781 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: guardian_students fk_rails_27d935807b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_students
    ADD CONSTRAINT fk_rails_27d935807b FOREIGN KEY (created_by_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: plan_price_tiers fk_rails_2ab14ed687; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plan_price_tiers
    ADD CONSTRAINT fk_rails_2ab14ed687 FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE;


--
-- Name: activity_enrollments fk_rails_2ad3fa68c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_enrollments
    ADD CONSTRAINT fk_rails_2ad3fa68c2 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: rubric_evaluations fk_rails_2bb4cfc474; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT fk_rails_2bb4cfc474 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: session_notes fk_rails_2c82ac95c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_notes
    ADD CONSTRAINT fk_rails_2c82ac95c1 FOREIGN KEY (counseling_case_id) REFERENCES public.counseling_cases(id) ON DELETE CASCADE;


--
-- Name: payments fk_rails_2f2f391007; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_2f2f391007 FOREIGN KEY (charge_id) REFERENCES public.charges(id) ON DELETE RESTRICT;


--
-- Name: teachers fk_rails_2fabb62d4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_2fabb62d4c FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: payment_plans fk_rails_316ebe4c27; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_plans
    ADD CONSTRAINT fk_rails_316ebe4c27 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: messages fk_rails_31aae3c129; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_31aae3c129 FOREIGN KEY (institution_user_id) REFERENCES public.institution_users(id) ON DELETE CASCADE;


--
-- Name: departments fk_rails_33e5ee827a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_33e5ee827a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: submissions fk_rails_3474dffb40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT fk_rails_3474dffb40 FOREIGN KEY (submitted_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: seat_assignments fk_rails_367791f28a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT fk_rails_367791f28a FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: audit_events fk_rails_373d303452; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_373d303452 FOREIGN KEY (actor_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: rubric_evaluations fk_rails_3840ddaa8a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT fk_rails_3840ddaa8a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: session_notes fk_rails_39e6058ec2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_notes
    ADD CONSTRAINT fk_rails_39e6058ec2 FOREIGN KEY (author_id) REFERENCES public.institution_users(id) ON DELETE RESTRICT;


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
-- Name: charges fk_rails_3d9614692c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_3d9614692c FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT;


--
-- Name: guardian_relationships fk_rails_3fc1896e36; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_relationships
    ADD CONSTRAINT fk_rails_3fc1896e36 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE SET NULL;


--
-- Name: role_assignments fk_rails_402eb6a154; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_402eb6a154 FOREIGN KEY (scope_department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: audit_events fk_rails_41272af5ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_41272af5ee FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: activity_enrollments fk_rails_414ce4a0c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_enrollments
    ADD CONSTRAINT fk_rails_414ce4a0c6 FOREIGN KEY (enrolled_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: guardian_relationships fk_rails_4298c313af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_relationships
    ADD CONSTRAINT fk_rails_4298c313af FOREIGN KEY (guardian_student_id) REFERENCES public.guardian_students(id) ON DELETE CASCADE;


--
-- Name: affinity_taxonomy fk_rails_438d28b022; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.affinity_taxonomy
    ADD CONSTRAINT fk_rails_438d28b022 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: disciplinary_logs fk_rails_4512f14aa5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disciplinary_logs
    ADD CONSTRAINT fk_rails_4512f14aa5 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: disciplinary_logs fk_rails_455a29b78b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disciplinary_logs
    ADD CONSTRAINT fk_rails_455a29b78b FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: invoices fk_rails_457c900f6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_457c900f6e FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


--
-- Name: peer_appreciations fk_rails_465947ef76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_465947ef76 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: rubric_templates fk_rails_47d9a03d06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_templates
    ADD CONSTRAINT fk_rails_47d9a03d06 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: student_affinities fk_rails_48d04b1eca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_affinities
    ADD CONSTRAINT fk_rails_48d04b1eca FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: rubric_cell_descriptors fk_rails_4a4a422198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_cell_descriptors
    ADD CONSTRAINT fk_rails_4a4a422198 FOREIGN KEY (rubric_criterion_id) REFERENCES public.rubric_criteria(id) ON DELETE CASCADE;


--
-- Name: submission_groups fk_rails_4c975513bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_groups
    ADD CONSTRAINT fk_rails_4c975513bf FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: institution_users fk_rails_4d086ab524; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_users
    ADD CONSTRAINT fk_rails_4d086ab524 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: messages fk_rails_4e7bd59607; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_4e7bd59607 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: institution_entitlements fk_rails_54b75433ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT fk_rails_54b75433ee FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


--
-- Name: assignment_materials fk_rails_54ffd64328; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignment_materials
    ADD CONSTRAINT fk_rails_54ffd64328 FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;


--
-- Name: rubric_evaluations fk_rails_55498d8d16; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT fk_rails_55498d8d16 FOREIGN KEY (evaluated_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: email_otps fk_rails_57d2c47354; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_otps
    ADD CONSTRAINT fk_rails_57d2c47354 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: assessments fk_rails_5977cbb29b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments
    ADD CONSTRAINT fk_rails_5977cbb29b FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE SET NULL;


--
-- Name: peer_appreciations fk_rails_5b34a227e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_5b34a227e6 FOREIGN KEY (giver_guardian_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: report_cards fk_rails_5c455c708b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_5c455c708b FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: invoice_line_items fk_rails_5c7d14200a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT fk_rails_5c7d14200a FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE RESTRICT;


--
-- Name: control_plane_audit_events fk_rails_5d30c7a0fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_audit_events
    ADD CONSTRAINT fk_rails_5d30c7a0fb FOREIGN KEY (platform_admin_id) REFERENCES public.platform_admins(id) ON DELETE SET NULL;


--
-- Name: assignments fk_rails_5e63c7027f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_5e63c7027f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: role_permissions fk_rails_60126080bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_60126080bd FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: character_program_consents fk_rails_6163c184b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_program_consents
    ADD CONSTRAINT fk_rails_6163c184b0 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: submissions fk_rails_61cac0823d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT fk_rails_61cac0823d FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;


--
-- Name: activities fk_rails_62052ad23c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT fk_rails_62052ad23c FOREIGN KEY (instructor_staff_member_id) REFERENCES public.staff_members(id) ON DELETE SET NULL;


--
-- Name: assignment_materials fk_rails_62b763c424; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignment_materials
    ADD CONSTRAINT fk_rails_62b763c424 FOREIGN KEY (attached_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: character_evaluations fk_rails_631e05dfe4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT fk_rails_631e05dfe4 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: character_frameworks fk_rails_636ffa8dcc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_frameworks
    ADD CONSTRAINT fk_rails_636ffa8dcc FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: subscriptions fk_rails_63d3df128b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_63d3df128b FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;


--
-- Name: assignments fk_rails_63e6cfa07e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_63e6cfa07e FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE;


--
-- Name: classroom_layouts fk_rails_642b1ed42f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classroom_layouts
    ADD CONSTRAINT fk_rails_642b1ed42f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: role_assignments fk_rails_646eed7bbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_646eed7bbc FOREIGN KEY (scope_grade_level_id) REFERENCES public.grade_levels(id) ON DELETE CASCADE;


--
-- Name: character_dimensions fk_rails_662f16e5ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimensions
    ADD CONSTRAINT fk_rails_662f16e5ca FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: attendance_records fk_rails_67992edee0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT fk_rails_67992edee0 FOREIGN KEY (group_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: usage_events fk_rails_68b7a87222; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_rails_68b7a87222 FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE RESTRICT;


--
-- Name: institution_settings fk_rails_693e18446a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_settings
    ADD CONSTRAINT fk_rails_693e18446a FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: rubric_criteria fk_rails_697dff3820; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_criteria
    ADD CONSTRAINT fk_rails_697dff3820 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: academic_terms fk_rails_69be7e5d5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_terms
    ADD CONSTRAINT fk_rails_69be7e5d5a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: submission_attachments fk_rails_69cd53b44b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_attachments
    ADD CONSTRAINT fk_rails_69cd53b44b FOREIGN KEY (submission_id) REFERENCES public.submissions(id) ON DELETE CASCADE;


--
-- Name: enrollments fk_rails_6a2ee9516d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_6a2ee9516d FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE SET NULL;


--
-- Name: student_placements fk_rails_6af522c18c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT fk_rails_6af522c18c FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id) ON DELETE CASCADE;


--
-- Name: staff_members fk_rails_6b44b8a383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_6b44b8a383 FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: student_affinities fk_rails_6ca864a80c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_affinities
    ADD CONSTRAINT fk_rails_6ca864a80c FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: character_levels fk_rails_6cdd625ba5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_levels
    ADD CONSTRAINT fk_rails_6cdd625ba5 FOREIGN KEY (dimension_id) REFERENCES public.character_dimensions(id) ON DELETE CASCADE;


--
-- Name: invitations fk_rails_6cecbd1575; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_6cecbd1575 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: conversations fk_rails_7024c7cecf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_7024c7cecf FOREIGN KEY (closed_by_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: classroom_layouts fk_rails_7026b4734c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classroom_layouts
    ADD CONSTRAINT fk_rails_7026b4734c FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: character_evaluations fk_rails_710ec7973f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT fk_rails_710ec7973f FOREIGN KEY (framework_id) REFERENCES public.character_frameworks(id) ON DELETE RESTRICT;


--
-- Name: assignment_materials fk_rails_72cc164557; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignment_materials
    ADD CONSTRAINT fk_rails_72cc164557 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: student_affinities fk_rails_7352153b1a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_affinities
    ADD CONSTRAINT fk_rails_7352153b1a FOREIGN KEY (taxonomy_id) REFERENCES public.affinity_taxonomy(id) ON DELETE CASCADE;


--
-- Name: assignments fk_rails_7453d408a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_7453d408a5 FOREIGN KEY (created_by_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


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
-- Name: group_memberships fk_rails_75ff151c1e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_75ff151c1e FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: institution_entitlements fk_rails_789c0738df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT fk_rails_789c0738df FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: submissions fk_rails_7950330b1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT fk_rails_7950330b1c FOREIGN KEY (submission_group_id) REFERENCES public.submission_groups(id) ON DELETE CASCADE;


--
-- Name: sections fk_rails_7a7057fef3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sections
    ADD CONSTRAINT fk_rails_7a7057fef3 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: character_dimension_scores fk_rails_7ce8806bd8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimension_scores
    ADD CONSTRAINT fk_rails_7ce8806bd8 FOREIGN KEY (evaluation_id) REFERENCES public.character_evaluations(id) ON DELETE CASCADE;


--
-- Name: staff_members fk_rails_7d2a281eaa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_7d2a281eaa FOREIGN KEY (institution_user_id) REFERENCES public.institution_users(id) ON DELETE CASCADE;


--
-- Name: invitations fk_rails_7eae413fe6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7eae413fe6 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversation_participants fk_rails_7ef36bddbe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_7ef36bddbe FOREIGN KEY (guardian_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages fk_rails_7f927086d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_7f927086d2 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: counseling_cases fk_rails_801b5a774d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counseling_cases
    ADD CONSTRAINT fk_rails_801b5a774d FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: invoice_line_items fk_rails_80427eb9d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line_items
    ADD CONSTRAINT fk_rails_80427eb9d3 FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE;


--
-- Name: conversations fk_rails_80b2afaacf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_80b2afaacf FOREIGN KEY (created_by_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: rubric_criteria fk_rails_80f1e80590; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_criteria
    ADD CONSTRAINT fk_rails_80f1e80590 FOREIGN KEY (rubric_template_id) REFERENCES public.rubric_templates(id) ON DELETE CASCADE;


--
-- Name: attendance_records fk_rails_828d16c97c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT fk_rails_828d16c97c FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: submissions fk_rails_8432d864a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submissions
    ADD CONSTRAINT fk_rails_8432d864a2 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: counseling_cases fk_rails_8671932b08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counseling_cases
    ADD CONSTRAINT fk_rails_8671932b08 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT;


--
-- Name: guardian_students fk_rails_8a488ba66f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_students
    ADD CONSTRAINT fk_rails_8a488ba66f FOREIGN KEY (guardian_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: peer_appreciations fk_rails_8a78bdd64d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_8a78bdd64d FOREIGN KEY (tag_id) REFERENCES public.peer_appreciation_tags(id) ON DELETE RESTRICT;


--
-- Name: guardian_relationships fk_rails_8bfbc2799f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_relationships
    ADD CONSTRAINT fk_rails_8bfbc2799f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: submission_attachments fk_rails_903b1e71cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_attachments
    ADD CONSTRAINT fk_rails_903b1e71cc FOREIGN KEY (attached_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: rubric_levels fk_rails_917a9be109; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_levels
    ADD CONSTRAINT fk_rails_917a9be109 FOREIGN KEY (rubric_template_id) REFERENCES public.rubric_templates(id) ON DELETE CASCADE;


--
-- Name: calendar_events fk_rails_919af76751; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_919af76751 FOREIGN KEY (created_by_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: installments fk_rails_91c63f70fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_rails_91c63f70fd FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: usage_daily_rollups fk_rails_9acf8873cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_daily_rollups
    ADD CONSTRAINT fk_rails_9acf8873cf FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE RESTRICT;


--
-- Name: student_placements fk_rails_9daf5d0b7c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT fk_rails_9daf5d0b7c FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: calendar_events fk_rails_a13b118c67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_a13b118c67 FOREIGN KEY (scope_group_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: control_plane_sessions fk_rails_a14868e66d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_sessions
    ADD CONSTRAINT fk_rails_a14868e66d FOREIGN KEY (platform_admin_id) REFERENCES public.platform_admins(id) ON DELETE CASCADE;


--
-- Name: referrals fk_rails_a2adb603c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT fk_rails_a2adb603c5 FOREIGN KEY (counseling_case_id) REFERENCES public.counseling_cases(id) ON DELETE CASCADE;


--
-- Name: character_evaluations fk_rails_a4ae08b190; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT fk_rails_a4ae08b190 FOREIGN KEY (author_institution_user_id) REFERENCES public.institution_users(id) ON DELETE RESTRICT;


--
-- Name: student_accounts fk_rails_a63606332a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_accounts
    ADD CONSTRAINT fk_rails_a63606332a FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT;


--
-- Name: classroom_layouts fk_rails_a905a0ac26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classroom_layouts
    ADD CONSTRAINT fk_rails_a905a0ac26 FOREIGN KEY (section_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: care_auras fk_rails_a974033225; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_auras
    ADD CONSTRAINT fk_rails_a974033225 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: payments fk_rails_a9b0755c20; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_a9b0755c20 FOREIGN KEY (student_account_id) REFERENCES public.student_accounts(id) ON DELETE RESTRICT;


--
-- Name: peer_appreciations fk_rails_ab30c04ecc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_ab30c04ecc FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: announcements fk_rails_ae3a554996; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT fk_rails_ae3a554996 FOREIGN KEY (author_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: assignments fk_rails_ae4a98177d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT fk_rails_ae4a98177d FOREIGN KEY (rubric_template_id) REFERENCES public.rubric_templates(id) ON DELETE SET NULL;


--
-- Name: conversation_participants fk_rails_af3ab0831d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_af3ab0831d FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: counseling_cases fk_rails_b0c6112576; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counseling_cases
    ADD CONSTRAINT fk_rails_b0c6112576 FOREIGN KEY (opened_by_id) REFERENCES public.institution_users(id) ON DELETE RESTRICT;


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
-- Name: character_program_consents fk_rails_b34ec1389b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_program_consents
    ADD CONSTRAINT fk_rails_b34ec1389b FOREIGN KEY (granted_by_guardian_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: guardian_students fk_rails_b35643a6a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_students
    ADD CONSTRAINT fk_rails_b35643a6a7 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: payments fk_rails_b439880051; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_b439880051 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: announcements fk_rails_b77566ea57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT fk_rails_b77566ea57 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: character_dimension_scores fk_rails_b813123410; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimension_scores
    ADD CONSTRAINT fk_rails_b813123410 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: teaching_assignments fk_rails_b86c9538a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_assignments
    ADD CONSTRAINT fk_rails_b86c9538a3 FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: roster_import_batches fk_rails_b8dabed25c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_batches
    ADD CONSTRAINT fk_rails_b8dabed25c FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: care_auras fk_rails_b9314c8338; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_auras
    ADD CONSTRAINT fk_rails_b9314c8338 FOREIGN KEY (authored_by_counselor_id) REFERENCES public.institution_users(id) ON DELETE RESTRICT;


--
-- Name: households fk_rails_b9fc41fba6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT fk_rails_b9fc41fba6 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: peer_appreciation_tags fk_rails_bb0995073b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciation_tags
    ADD CONSTRAINT fk_rails_bb0995073b FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: hps_term_snapshots fk_rails_bb3e105301; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hps_term_snapshots
    ADD CONSTRAINT fk_rails_bb3e105301 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: activity_enrollments fk_rails_bb8b57ebab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_enrollments
    ADD CONSTRAINT fk_rails_bb8b57ebab FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: report_cards fk_rails_bbed8eb10a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_bbed8eb10a FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: usage_events fk_rails_bc377e8add; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT fk_rails_bc377e8add FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


--
-- Name: dietary_restrictions fk_rails_bc8b5d9bbf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dietary_restrictions
    ADD CONSTRAINT fk_rails_bc8b5d9bbf FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: activities fk_rails_be32e7f3a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT fk_rails_be32e7f3a9 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: email_otps fk_rails_bf2bd8aedb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_otps
    ADD CONSTRAINT fk_rails_bf2bd8aedb FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages fk_rails_bf37ff0933; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_bf37ff0933 FOREIGN KEY (guardian_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: students fk_rails_c00693d6db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_c00693d6db FOREIGN KEY (section_id) REFERENCES public.sections(id);


--
-- Name: control_plane_email_otps fk_rails_c03c816fa4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.control_plane_email_otps
    ADD CONSTRAINT fk_rails_c03c816fa4 FOREIGN KEY (platform_admin_id) REFERENCES public.platform_admins(id) ON DELETE CASCADE;


--
-- Name: roles fk_rails_c08d8438fe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT fk_rails_c08d8438fe FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: referrals fk_rails_c16c5fc424; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT fk_rails_c16c5fc424 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: peer_appreciations fk_rails_c2ecc37ba6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.peer_appreciations
    ADD CONSTRAINT fk_rails_c2ecc37ba6 FOREIGN KEY (giver_student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: submission_groups fk_rails_c35f1bef68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.submission_groups
    ADD CONSTRAINT fk_rails_c35f1bef68 FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: installments fk_rails_c437a1a46c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT fk_rails_c437a1a46c FOREIGN KEY (payment_plan_id) REFERENCES public.payment_plans(id) ON DELETE CASCADE;


--
-- Name: teachers fk_rails_c43d25a88a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT fk_rails_c43d25a88a FOREIGN KEY (faculty_id) REFERENCES public.faculties(id);


--
-- Name: activities fk_rails_c444820378; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT fk_rails_c444820378 FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: rubric_cell_descriptors fk_rails_c4fc274650; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_cell_descriptors
    ADD CONSTRAINT fk_rails_c4fc274650 FOREIGN KEY (rubric_level_id) REFERENCES public.rubric_levels(id) ON DELETE CASCADE;


--
-- Name: students fk_rails_c6f327792b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_rails_c6f327792b FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: payment_plans fk_rails_c72ffb7be9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_plans
    ADD CONSTRAINT fk_rails_c72ffb7be9 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT;


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
-- Name: care_auras fk_rails_cb00545723; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_auras
    ADD CONSTRAINT fk_rails_cb00545723 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: conversation_participants fk_rails_cd21bdc262; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_cd21bdc262 FOREIGN KEY (institution_user_id) REFERENCES public.institution_users(id) ON DELETE CASCADE;


--
-- Name: group_memberships fk_rails_cfcf8ca0a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_cfcf8ca0a6 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: group_memberships fk_rails_d237094e0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT fk_rails_d237094e0b FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;


--
-- Name: activity_enrollments fk_rails_d2c4aaceb3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_enrollments
    ADD CONSTRAINT fk_rails_d2c4aaceb3 FOREIGN KEY (activity_id) REFERENCES public.activities(id) ON DELETE CASCADE;


--
-- Name: roster_import_batches fk_rails_d389255138; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_batches
    ADD CONSTRAINT fk_rails_d389255138 FOREIGN KEY (created_by_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


--
-- Name: rubric_templates fk_rails_d4ae9b7938; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_templates
    ADD CONSTRAINT fk_rails_d4ae9b7938 FOREIGN KEY (authored_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversation_participants fk_rails_d4fdd4cae0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_participants
    ADD CONSTRAINT fk_rails_d4fdd4cae0 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: faculties fk_rails_d5a8b19638; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculties
    ADD CONSTRAINT fk_rails_d5a8b19638 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: roster_import_rows fk_rails_d5c3ec3b1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_rows
    ADD CONSTRAINT fk_rails_d5c3ec3b1c FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: affinity_taxonomy fk_rails_d973a92d33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.affinity_taxonomy
    ADD CONSTRAINT fk_rails_d973a92d33 FOREIGN KEY (parent_id) REFERENCES public.affinity_taxonomy(id) ON DELETE CASCADE;


--
-- Name: rubric_levels fk_rails_da91b8ecba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_levels
    ADD CONSTRAINT fk_rails_da91b8ecba FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: employment_periods fk_rails_daffc2b6c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT fk_rails_daffc2b6c8 FOREIGN KEY (staff_member_id) REFERENCES public.staff_members(id) ON DELETE CASCADE;


--
-- Name: rubric_evaluations fk_rails_dd5889f3a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rubric_evaluations
    ADD CONSTRAINT fk_rails_dd5889f3a1 FOREIGN KEY (assignment_id) REFERENCES public.assignments(id) ON DELETE CASCADE;


--
-- Name: seat_assignments fk_rails_dd5e702175; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT fk_rails_dd5e702175 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: student_placements fk_rails_deb636331c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_placements
    ADD CONSTRAINT fk_rails_deb636331c FOREIGN KEY (section_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: student_headcount_snapshots fk_rails_dfadb12276; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_headcount_snapshots
    ADD CONSTRAINT fk_rails_dfadb12276 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


--
-- Name: calendar_events fk_rails_e21d958b99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_e21d958b99 FOREIGN KEY (scope_grade_level_id) REFERENCES public.grade_levels(id) ON DELETE CASCADE;


--
-- Name: session_notes fk_rails_e2a774b8c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_notes
    ADD CONSTRAINT fk_rails_e2a774b8c8 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_e2fd7aa72b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_e2fd7aa72b FOREIGN KEY (grade_level_id) REFERENCES public.grade_levels(id);


--
-- Name: affinity_taxonomy fk_rails_e39aa645da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.affinity_taxonomy
    ADD CONSTRAINT fk_rails_e39aa645da FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: charges fk_rails_e47d53b4c6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT fk_rails_e47d53b4c6 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: role_assignments fk_rails_e4bfc1cd2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_e4bfc1cd2c FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: student_affinities fk_rails_e50b4c976f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_affinities
    ADD CONSTRAINT fk_rails_e50b4c976f FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: character_program_consents fk_rails_e514d744a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_program_consents
    ADD CONSTRAINT fk_rails_e514d744a2 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: character_evaluations fk_rails_e7be994f33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT fk_rails_e7be994f33 FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: seat_assignments fk_rails_e8e04827c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seat_assignments
    ADD CONSTRAINT fk_rails_e8e04827c0 FOREIGN KEY (classroom_layout_id) REFERENCES public.classroom_layouts(id) ON DELETE CASCADE;


--
-- Name: role_assignments fk_rails_ebf84047d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_ebf84047d2 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: institution_entitlements fk_rails_ec2d329bc6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT fk_rails_ec2d329bc6 FOREIGN KEY (addon_id) REFERENCES public.addons(id) ON DELETE RESTRICT;


--
-- Name: subscriptions fk_rails_ed5ff6b39a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_ed5ff6b39a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


--
-- Name: programs fk_rails_ed68a5b16c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.programs
    ADD CONSTRAINT fk_rails_ed68a5b16c FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: guardian_students fk_rails_ed7f843d6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guardian_students
    ADD CONSTRAINT fk_rails_ed7f843d6e FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: character_evaluations fk_rails_edda201842; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_evaluations
    ADD CONSTRAINT fk_rails_edda201842 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: character_dimensions fk_rails_eed1f2d3ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_dimensions
    ADD CONSTRAINT fk_rails_eed1f2d3ad FOREIGN KEY (framework_id) REFERENCES public.character_frameworks(id) ON DELETE CASCADE;


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
-- Name: care_auras fk_rails_f15a82bef7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.care_auras
    ADD CONSTRAINT fk_rails_f15a82bef7 FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE CASCADE;


--
-- Name: report_cards fk_rails_f2bae774b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_cards
    ADD CONSTRAINT fk_rails_f2bae774b9 FOREIGN KEY (published_by_staff_member_id) REFERENCES public.staff_members(id) ON DELETE SET NULL;


--
-- Name: role_assignments fk_rails_f2c879ee03; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_f2c879ee03 FOREIGN KEY (scope_group_id) REFERENCES public.sections(id) ON DELETE CASCADE;


--
-- Name: calendar_events fk_rails_f872036c76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT fk_rails_f872036c76 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: hps_term_snapshots fk_rails_f8adf4b299; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hps_term_snapshots
    ADD CONSTRAINT fk_rails_f8adf4b299 FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: character_levels fk_rails_f8eab38ee3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.character_levels
    ADD CONSTRAINT fk_rails_f8eab38ee3 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_fba2424889; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_fba2424889 FOREIGN KEY (institution_id) REFERENCES public.institutions(id);


--
-- Name: invoices fk_rails_fd45bf1f0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_fd45bf1f0d FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


--
-- Name: academic_terms; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_terms ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_terms academic_terms_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_terms_tenant_isolation ON public.academic_terms USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

--
-- Name: activities activities_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY activities_tenant_isolation ON public.activities USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: activity_enrollments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_enrollments ENABLE ROW LEVEL SECURITY;

--
-- Name: activity_enrollments activity_enrollments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY activity_enrollments_tenant_isolation ON public.activity_enrollments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: affinity_taxonomy; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.affinity_taxonomy ENABLE ROW LEVEL SECURITY;

--
-- Name: affinity_taxonomy affinity_taxonomy_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY affinity_taxonomy_tenant_isolation ON public.affinity_taxonomy USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: announcements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

--
-- Name: announcements announcements_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY announcements_tenant_isolation ON public.announcements USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: assessments assessments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assessments_tenant_isolation ON public.assessments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: assignment_materials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assignment_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: assignment_materials assignment_materials_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assignment_materials_tenant_isolation ON public.assignment_materials USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: assignments assignments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assignments_tenant_isolation ON public.assignments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: attendance_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance_records attendance_records_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_records_tenant_isolation ON public.attendance_records USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_events audit_events_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_events_tenant_isolation ON public.audit_events USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: calendar_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_events calendar_events_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY calendar_events_tenant_isolation ON public.calendar_events USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: care_auras; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.care_auras ENABLE ROW LEVEL SECURITY;

--
-- Name: care_auras care_auras_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY care_auras_tenant_isolation ON public.care_auras USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_dimension_scores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_dimension_scores ENABLE ROW LEVEL SECURITY;

--
-- Name: character_dimension_scores character_dimension_scores_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_dimension_scores_tenant_isolation ON public.character_dimension_scores USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_dimensions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_dimensions ENABLE ROW LEVEL SECURITY;

--
-- Name: character_dimensions character_dimensions_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_dimensions_tenant_isolation ON public.character_dimensions USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_evaluations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_evaluations ENABLE ROW LEVEL SECURITY;

--
-- Name: character_evaluations character_evaluations_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_evaluations_tenant_isolation ON public.character_evaluations USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_frameworks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_frameworks ENABLE ROW LEVEL SECURITY;

--
-- Name: character_frameworks character_frameworks_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_frameworks_tenant_isolation ON public.character_frameworks USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: character_levels character_levels_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_levels_tenant_isolation ON public.character_levels USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: character_program_consents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.character_program_consents ENABLE ROW LEVEL SECURITY;

--
-- Name: character_program_consents character_program_consents_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY character_program_consents_tenant_isolation ON public.character_program_consents USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: charges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;

--
-- Name: charges charges_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY charges_tenant_isolation ON public.charges USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: classroom_layouts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.classroom_layouts ENABLE ROW LEVEL SECURITY;

--
-- Name: classroom_layouts classroom_layouts_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classroom_layouts_tenant_isolation ON public.classroom_layouts USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: conversation_participants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

--
-- Name: conversation_participants conversation_participants_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversation_participants_tenant_isolation ON public.conversation_participants USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations conversations_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY conversations_tenant_isolation ON public.conversations USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: counseling_cases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.counseling_cases ENABLE ROW LEVEL SECURITY;

--
-- Name: counseling_cases counseling_cases_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY counseling_cases_tenant_isolation ON public.counseling_cases USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
-- Name: disciplinary_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.disciplinary_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: disciplinary_logs disciplinary_logs_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY disciplinary_logs_tenant_isolation ON public.disciplinary_logs USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: email_otps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_otps ENABLE ROW LEVEL SECURITY;

--
-- Name: email_otps email_otps_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_otps_tenant_isolation ON public.email_otps USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
-- Name: group_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: group_memberships group_memberships_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_memberships_tenant_isolation ON public.group_memberships USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: guardian_relationships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardian_relationships ENABLE ROW LEVEL SECURITY;

--
-- Name: guardian_relationships guardian_relationships_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardian_relationships_tenant_isolation ON public.guardian_relationships USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: guardian_students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardian_students ENABLE ROW LEVEL SECURITY;

--
-- Name: guardian_students guardian_students_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardian_students_tenant_isolation ON public.guardian_students USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: guardians; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.guardians ENABLE ROW LEVEL SECURITY;

--
-- Name: guardians guardians_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY guardians_tenant_isolation ON public.guardians USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: households; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;

--
-- Name: households households_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY households_tenant_isolation ON public.households USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: hps_term_snapshots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hps_term_snapshots ENABLE ROW LEVEL SECURITY;

--
-- Name: hps_term_snapshots hps_term_snapshots_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY hps_term_snapshots_tenant_isolation ON public.hps_term_snapshots USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: installments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;

--
-- Name: installments installments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY installments_tenant_isolation ON public.installments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
-- Name: invitations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

--
-- Name: invitations invitations_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invitations_tenant_isolation ON public.invitations USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: messages messages_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY messages_tenant_isolation ON public.messages USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: payment_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_plans payment_plans_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_plans_tenant_isolation ON public.payment_plans USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: payments payments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payments_tenant_isolation ON public.payments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: peer_appreciation_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.peer_appreciation_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: peer_appreciation_tags peer_appreciation_tags_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY peer_appreciation_tags_tenant_isolation ON public.peer_appreciation_tags USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: peer_appreciations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.peer_appreciations ENABLE ROW LEVEL SECURITY;

--
-- Name: peer_appreciations peer_appreciations_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY peer_appreciations_tenant_isolation ON public.peer_appreciations USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: programs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

--
-- Name: programs programs_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY programs_tenant_isolation ON public.programs USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: referrals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

--
-- Name: referrals referrals_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY referrals_tenant_isolation ON public.referrals USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: report_cards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.report_cards ENABLE ROW LEVEL SECURITY;

--
-- Name: report_cards report_cards_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY report_cards_tenant_isolation ON public.report_cards USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
-- Name: roster_import_batches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roster_import_batches ENABLE ROW LEVEL SECURITY;

--
-- Name: roster_import_batches roster_import_batches_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roster_import_batches_tenant_isolation ON public.roster_import_batches USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: roster_import_rows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.roster_import_rows ENABLE ROW LEVEL SECURITY;

--
-- Name: roster_import_rows roster_import_rows_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY roster_import_rows_tenant_isolation ON public.roster_import_rows USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: rubric_cell_descriptors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rubric_cell_descriptors ENABLE ROW LEVEL SECURITY;

--
-- Name: rubric_cell_descriptors rubric_cell_descriptors_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rubric_cell_descriptors_tenant_isolation ON public.rubric_cell_descriptors USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: rubric_criteria; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rubric_criteria ENABLE ROW LEVEL SECURITY;

--
-- Name: rubric_criteria rubric_criteria_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rubric_criteria_tenant_isolation ON public.rubric_criteria USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: rubric_evaluations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rubric_evaluations ENABLE ROW LEVEL SECURITY;

--
-- Name: rubric_evaluations rubric_evaluations_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rubric_evaluations_tenant_isolation ON public.rubric_evaluations USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: rubric_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rubric_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: rubric_levels rubric_levels_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rubric_levels_tenant_isolation ON public.rubric_levels USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: rubric_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rubric_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: rubric_templates rubric_templates_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rubric_templates_tenant_isolation ON public.rubric_templates USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: seat_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.seat_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: seat_assignments seat_assignments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY seat_assignments_tenant_isolation ON public.seat_assignments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

--
-- Name: sections sections_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sections_tenant_isolation ON public.sections USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: session_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.session_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: session_notes session_notes_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_notes_tenant_isolation ON public.session_notes USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: staff_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;

--
-- Name: staff_members staff_members_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY staff_members_tenant_isolation ON public.staff_members USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: student_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: student_accounts student_accounts_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_accounts_tenant_isolation ON public.student_accounts USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: student_affinities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_affinities ENABLE ROW LEVEL SECURITY;

--
-- Name: student_affinities student_affinities_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_affinities_tenant_isolation ON public.student_affinities USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: student_guardians; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_guardians ENABLE ROW LEVEL SECURITY;

--
-- Name: student_guardians student_guardians_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_guardians_tenant_isolation ON public.student_guardians USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: student_placements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.student_placements ENABLE ROW LEVEL SECURITY;

--
-- Name: student_placements student_placements_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_placements_tenant_isolation ON public.student_placements USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
-- Name: submission_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.submission_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: submission_attachments submission_attachments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY submission_attachments_tenant_isolation ON public.submission_attachments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: submission_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.submission_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: submission_groups submission_groups_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY submission_groups_tenant_isolation ON public.submission_groups USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: submissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: submissions submissions_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY submissions_tenant_isolation ON public.submissions USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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
('20260721160000'),
('20260721150000'),
('20260721140000'),
('20260721130000'),
('20260721120000'),
('20260717220000'),
('20260717213000'),
('20260717210303'),
('20260717161248'),
('20260717155106'),
('20260716203439'),
('20260716153456'),
('20260716151744'),
('20260716151743'),
('20260716143401'),
('20260716140030'),
('20260716131320'),
('20260715203148'),
('20260715195639'),
('20260715190531'),
('20260715155950'),
('20260715142947'),
('20260714205355'),
('20260714201234'),
('20260714000001'),
('20260710152925'),
('20260710144823'),
('20260710120002'),
('20260710120001'),
('20260710000003'),
('20260710000002'),
('20260710000001'),
('20260709000002'),
('20260709000001'),
('20260708000018'),
('20260708000017'),
('20260708000016'),
('20260708000015'),
('20260708000014'),
('20260708000013'),
('20260708000012'),
('20260708000011'),
('20260708000010'),
('20260708000009'),
('20260708000008'),
('20260708000007'),
('20260708000006'),
('20260708000005'),
('20260708000004'),
('20260708000003'),
('20260708000002'),
('20260708000001'),
('20260707230312'),
('20260706000006'),
('20260706000005'),
('20260706000004'),
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

