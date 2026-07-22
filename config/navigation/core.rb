# Owned by app/domains/core. Core::AcademicTerm's first staff-facing surface
# (guidelines/CLOSURE_PLAN.md §4.2) — administrative, low-traffic, so it sits
# early/low in the nav ordering near other foundational setup entries.
Navigation::Registry.register(
  domain: "core",
  label: "Términos académicos",
  path: "/core/academic_terms",
  permission: "academic_terms.manage",
  position: 12
)
