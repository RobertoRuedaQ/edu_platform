# edu_platform — Proceso abierto (backlog pendiente)

> Archivo hermano de `PROJECT_STATE.md` y `HISTORIA.md`. **Reorganizado el 2026-07-21**: de aquí en
> adelante contiene SOLO la lista de pendientes accionables para los siguientes slices — nada
> cerrado. Antes de esta fecha acumulaba también la narrativa completa de cada slice YA cerrado
> (34 ítems) y los guardrails operativos; ambos crecían con cada slice y ya dominaban el tamaño de
> este archivo, exactamente el problema que `PROJECT_STATE.md`/`HISTORIA.md` habían resuelto en
> v1.21.0 para el documento magro. Destino de lo que se sacó:
> - **Narrativa de cada slice cerrado** → ya vivía duplicada en `HISTORIA.md` (changelog completo,
>   `v1.0.0`→última) — se confirmó cobertura 1:1 por versión antes de limpiar, y se eliminó de aquí.
> - **Guardrails operativos** (invariantes ya asentados, no tareas pendientes) → movidos a
>   `PROJECT_STATE.md` §13.
> - **Estado actual por dominio** → `PROJECT_STATE.md` §4 (mapa de dominios) y Metadatos ("estado en
>   una línea"), actualizados en cada slice de todas formas.
>
> **El repositorio sigue siendo la fuente de verdad del código.** Ante discrepancia entre lo escrito
> aquí y lo que hay en disco, gana el repositorio. Al cerrar un ítem de este backlog: (1) tachar/
> quitar la línea de aquí, (2) agregar la entrada de versión en `HISTORIA.md`, (3) actualizar el
> mapa de dominios/estado-en-una-línea de `PROJECT_STATE.md`, (4) si el slice deja una lección
> estructural reusable, agregar un guardrail nuevo en `PROJECT_STATE.md` §13.

---

## 1. Backlog pendiente (orden sugerido)

1. **Fase D — `cafeteria` resto (Menú/Compra/Saldo)** (`guidelines/CLOSURE_PLAN.md` §5) — sin
   construir, la pieza más grande que queda: `MenuRoster`/`Purchase`/`StudentAccount`, modelar
   Menú/MenuItem + Compra + deducción de saldo con locking (mismo molde de `Finance::ChargeCreator`/
   `PaymentRecorder`, `account.lock!` transaccional). Con `transportation` (v1.49.0) y `schedules`
   timetable (v1.50.0) ya cerrados, **no queda ningún dead-end activo en el repo** — este es
   trabajo diferido, no una urgencia.

2. **Fase D — greenfield puro, sin urgencia** (`guidelines/CLOSURE_PLAN.md` §5): `admissions`/
   `library` no existen en absoluto (cero archivos/rutas/nav) — construirlos es un dominio nuevo,
   no una conversión stub→real, y no hay señal de necesidad real hoy.

3. **Onboarding — hardening no bloqueante, sin necesidad de producción confirmada** (ver
   `HISTORIA.md` v1.7.0/v1.32.0): batch-invite tras el alta de acudientes, full-async de
   parse+validar de `RosterImport`, purga de `roster_import_rows` post-commit; webhook real para
   `Invitations::BounceHandler` (requiere integración con el proveedor de correo elegido).

4. **Billing — hardening pendiente** (ver `HISTORIA.md` v1.33.0 para lo ya cerrado): estos tres
   requieren una decisión de negocio real, no son defaults seguros de asumir — prorrateo de
   `addon_fee`; edición manual de líneas de un borrador; tabla `billing_periods` explícita.

5. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis) — `transportation` (broadcast de
   `boarding_events`, cuya persistencia ya es real desde v1.49.0) y `communication` (canales).
   Diferido, sin driver real todavía.

6. **M1 — metering por dominio, resto** (ver `PROJECT_STATE.md` §10, fila M1): sigue abierto para
   `cafeteria`/`student_support`/`counseling`/`analytics_bi` (Clase C o sin evento de negocio claro)
   y ahora también `transportation`/`schedules`-timetable — ambos reales desde v1.49.0/v1.50.0, pero
   SIN `ControlPlane::Usage::Ingest.emit` cableado todavía (`boarding_event`/una clase impartida
   serían los candidatos naturales) — cerrar por dominio, cuando cada uno tenga un evento real que
   medir, nunca de una vez.

7. **Decisiones abiertas de arquitectura sin backlog de construcción propio** — ver
   `PROJECT_STATE.md` §10 para el detalle: **B2** (¿`role_assignments.valid_from/until` se acopla a
   `academic_terms`?), **P2** (¿qué hacer con `institution_users.role`, columna libre sin lectores?).

### No-goals confirmados (fuera de alcance, no backlog)

- **Riel de pago** (cobrar/enviar una factura) — fuera de alcance de v1; finalizar una factura la
  congela, no la cobra.
- Integración GPS/mapa para `transportation` — sin señal de necesidad real.

---

## 2. Guardrails operativos

> **Movidos a `PROJECT_STATE.md` §13** (reorganización de 2026-07-21) — son invariantes ya
> asentados, no tareas pendientes de este backlog. Consultar esa sección antes de construir
> cualquier slice nuevo, especialmente uno que toque un dominio con guardrails propios ya
> documentados (billing, RLS/GUC, `assignments`, `analytics_bi`/HPS, portales, RBAC).
