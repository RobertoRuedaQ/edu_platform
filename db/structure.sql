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
-- Name: addons addons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addons
    ADD CONSTRAINT addons_pkey PRIMARY KEY (id);


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
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: charges charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (id);


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
-- Name: installments installments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.installments
    ADD CONSTRAINT installments_pkey PRIMARY KEY (id);


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
-- Name: idx_charges_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_charges_idempotency ON public.charges USING btree (institution_id, idempotency_key);


--
-- Name: idx_installments_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_installments_seq ON public.installments USING btree (institution_id, payment_plan_id, sequence);


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
-- Name: idx_payments_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payments_idempotency ON public.payments USING btree (institution_id, idempotency_key);


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
-- Name: index_assessments_on_enrollment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_enrollment_id ON public.assessments USING btree (enrollment_id);


--
-- Name: index_assessments_on_institution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_institution_id ON public.assessments USING btree (institution_id);


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
-- Name: roster_import_rows fk_rails_17b37d6b3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_rows
    ADD CONSTRAINT fk_rails_17b37d6b3e FOREIGN KEY (roster_import_batch_id) REFERENCES public.roster_import_batches(id) ON DELETE CASCADE;


--
-- Name: subjects fk_rails_1b26c6deb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_rails_1b26c6deb0 FOREIGN KEY (program_id) REFERENCES public.programs(id);


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
-- Name: departments fk_rails_33e5ee827a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_33e5ee827a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: audit_events fk_rails_373d303452; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_373d303452 FOREIGN KEY (actor_institution_user_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


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
-- Name: role_permissions fk_rails_439e640a3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_439e640a3f FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: invoices fk_rails_457c900f6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_457c900f6e FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


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
-- Name: institution_entitlements fk_rails_54b75433ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT fk_rails_54b75433ee FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;


--
-- Name: email_otps fk_rails_57d2c47354; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_otps
    ADD CONSTRAINT fk_rails_57d2c47354 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: role_permissions fk_rails_60126080bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT fk_rails_60126080bd FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: subscriptions fk_rails_63d3df128b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_63d3df128b FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE SET NULL;


--
-- Name: role_assignments fk_rails_646eed7bbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_assignments
    ADD CONSTRAINT fk_rails_646eed7bbc FOREIGN KEY (scope_grade_level_id) REFERENCES public.grade_levels(id) ON DELETE CASCADE;


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
-- Name: academic_terms fk_rails_69be7e5d5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_terms
    ADD CONSTRAINT fk_rails_69be7e5d5a FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: enrollments fk_rails_6a2ee9516d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT fk_rails_6a2ee9516d FOREIGN KEY (academic_term_id) REFERENCES public.academic_terms(id) ON DELETE SET NULL;


--
-- Name: staff_members fk_rails_6b44b8a383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_members
    ADD CONSTRAINT fk_rails_6b44b8a383 FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: invitations fk_rails_6cecbd1575; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_6cecbd1575 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: institution_entitlements fk_rails_789c0738df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institution_entitlements
    ADD CONSTRAINT fk_rails_789c0738df FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


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
-- Name: invitations fk_rails_7eae413fe6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7eae413fe6 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: student_accounts fk_rails_a63606332a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_accounts
    ADD CONSTRAINT fk_rails_a63606332a FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE RESTRICT;


--
-- Name: payments fk_rails_a9b0755c20; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_a9b0755c20 FOREIGN KEY (student_account_id) REFERENCES public.student_accounts(id) ON DELETE RESTRICT;


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
-- Name: email_otps fk_rails_bf2bd8aedb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_otps
    ADD CONSTRAINT fk_rails_bf2bd8aedb FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: roster_import_batches fk_rails_d389255138; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roster_import_batches
    ADD CONSTRAINT fk_rails_d389255138 FOREIGN KEY (created_by_id) REFERENCES public.institution_users(id) ON DELETE SET NULL;


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
-- Name: employment_periods fk_rails_daffc2b6c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employment_periods
    ADD CONSTRAINT fk_rails_daffc2b6c8 FOREIGN KEY (staff_member_id) REFERENCES public.staff_members(id) ON DELETE CASCADE;


--
-- Name: student_headcount_snapshots fk_rails_dfadb12276; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_headcount_snapshots
    ADD CONSTRAINT fk_rails_dfadb12276 FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE RESTRICT;


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
-- Name: assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: assessments assessments_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assessments_tenant_isolation ON public.assessments USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_events audit_events_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_events_tenant_isolation ON public.audit_events USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


--
-- Name: charges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;

--
-- Name: charges charges_tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY charges_tenant_isolation ON public.charges USING ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid)) WITH CHECK ((institution_id = (NULLIF(current_setting('app.current_institution_id'::text, true), ''::text))::uuid));


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

