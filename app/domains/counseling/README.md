# Counseling

School counseling: cases, session notes, and referrals for a student. Carved
out of `student_support` because it is **more sensitive** than the rest of that
domain and needs a narrower access boundary.

## Models
- `Counseling::Case` (`counseling_cases`) — one case per student concern.
- `Counseling::SessionNote` (`session_notes`) — sensitive notes; `confidential`
  defaults `true`.
- `Counseling::Referral` (`referrals`) — external/internal referrals.

## Confidentiality boundary (enforcement lands in the auth iteration)
Today these tables carry the standard **tenant RLS** backstop (ENABLE + FORCE +
`institution_id = current GUC`). That is necessary but NOT sufficient for
counseling — a tenant admin is not automatically a counselor.

Planned, not yet implemented:
1. **Permission key `counseling.read`** (already in the global catalog, see
   `IdentityAccess::SeedPermissions`) gates who may read counseling data. The
   app layer checks it before querying.
2. **Stricter RLS predicate**: a role-aware policy in addition to the tenant
   predicate — e.g. require a counseling-role GUC to be set for `SELECT` on
   `counseling_cases` / `session_notes`, so even a raw connection without the
   counseling context returns nothing. To be added alongside the auth model.
3. **Column-level encryption** of `session_notes.body` (Active Record
   Encryption) is an option to evaluate; not enabled in this phase.

Authorship FKs (`opened_by`, `author_id`) are `ON DELETE RESTRICT` to preserve
accountability — a membership with counseling history is deactivated, not
deleted.
