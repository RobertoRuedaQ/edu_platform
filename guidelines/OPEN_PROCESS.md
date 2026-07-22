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

1. **Fase D — `transportation` real (siguiente incremento recomendado)** (`guidelines/CLOSURE_PLAN.md`
   Fase D) — recon ya hecho (2026-07-21, ver `CLOSURE_PLAN.md` §5): de los cuatro candidatos sin
   construir, `transportation` es el más urgente — tiene nav ("Rutas"/"Abordaje") y rutas reales YA
   visibles en producción sobre datos 100% `Data.define` (`RouteRoster`/`RiderRoster`), un dead-end
   activo, no un hueco invisible. Paso a paso:
   1. **Migración**: `routes` (nombre/placa/conductor — decidir si `driver` es un
      `institution_users.id` real vía FK o solo texto libre, ver decisión más abajo), `route_stops`
      (parada + orden dentro de la ruta, `EXCLUDE`/único parcial si el orden no puede repetirse),
      `route_riders` (estudiante↔ruta, N:1 o N:N según si un estudiante puede tener AM≠PM —
      confirmar antes de migrar), todas RLS `ENABLE+FORCE`, `uuidv7()`, índice líder `institution_id`.
   2. **Modelos**: `Transportation::Route`/`RouteStop`/`RouteRider`, validaciones-espejo de
      cualquier CHECK.
   3. **Reemplazar stubs**: `Transportation::RouteScope` deja de envolver `RouteRoster`, lee la tabla
      real; `RoutesController`/`BoardingController`/`BoardingEventsController` — el hallazgo más
      importante es que `BoardingEventsController#create` hoy es un no-op literal (flash "(stub)"
      sin persistir) — necesita una tabla real de eventos de abordaje (`boarding_events`:
      estudiante, ruta, tipo subida/bajada, timestamp) si el registro debe persistir de verdad, o
      quedar explícitamente fuera de alcance si el incremento solo cubre routes/riders.
   4. **Decisión a confirmar con el owner ANTES de migrar** (no asumir default): ¿el conductor es un
      `institution_users` real (staff con rol específico) o solo un campo de texto? `route_riders`
      — ¿AM y PM son la misma fila o dos? Sin esto confirmado, no migrar — mismo criterio que "no
      modelar sin regla de negocio confirmada" ya aplicado a Alertas Tempranas (`HISTORIA.md`
      v1.46.0).
   5. **Reemplazar `Portals::GuardianTransportInfo`/`StudentTransportInfo`** (hoy sobre la misma data
      falsa) para que el portal del acudiente/estudiante lea la ruta real del hijo.
   6. **Tests**: migrar cualquier test que dependa de IDs de stub (`route-1`, `s-1`, etc.) a
      rutas/estudiantes reales, mismo patrón `find_or_create_by!` idempotente de
      `student_support_test.rb`.
   7. **Docs de cierre**: `HISTORIA.md` (nueva versión), `PROJECT_STATE.md` (línea de dominio
      `transportation`, hoy dice "Clase C" — corregir), `CLOSURE_PLAN.md` (marcar Fase D ítem
      cerrado), este archivo (quitar este ítem; `schedules` timetable queda como el otro dead-end
      pendiente, mismo criterio de urgencia — ver ítem 2 abajo).
   - **Fuera de alcance salvo decisión explícita del owner**: tiempo real (Turbo Streams sobre el
     abordaje, ver ítem 5 abajo) y cualquier integración GPS/mapa — ninguna de las dos tiene señal
     de necesidad real hoy.

2. **Fase D — resto** (`guidelines/CLOSURE_PLAN.md` §5, detalle completo ahí — no duplicado aquí):
   - `schedules` — mitad de horario/timetable (`rooms`/`meeting_patterns`): mismo dead-end activo que
     `transportation` (nav "Horario institucional" + rutas reales sobre stub 100% falso) — segundo
     candidato más urgente tras el ítem 1.
   - `cafeteria` — resto (Menú/Compra/Saldo): `MenuRoster`/`Purchase`/`StudentAccount`, sin
     construir, pieza más grande (deducción de saldo con locking).
   - `admissions`/`library`: no existen en absoluto (cero archivos/rutas/nav) — greenfield puro, sin
     urgencia de "arreglar un dead-end visible" como los dos anteriores.

3. **Onboarding — hardening no bloqueante, sin necesidad de producción confirmada** (ver
   `HISTORIA.md` v1.7.0/v1.32.0): batch-invite tras el alta de acudientes, full-async de
   parse+validar de `RosterImport`, purga de `roster_import_rows` post-commit; webhook real para
   `Invitations::BounceHandler` (requiere integración con el proveedor de correo elegido).

4. **Billing — hardening pendiente** (ver `HISTORIA.md` v1.33.0 para lo ya cerrado): estos tres
   requieren una decisión de negocio real, no son defaults seguros de asumir — prorrateo de
   `addon_fee`; edición manual de líneas de un borrador; tabla `billing_periods` explícita.

5. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis) — `transportation` (abordaje) y
   `communication` (canales). Diferido, sin driver real todavía.

6. **M1 — metering por dominio, resto** (ver `PROJECT_STATE.md` §10, fila M1): sigue abierto para
   `transportation`/`cafeteria`/`student_support`/`counseling`/`analytics_bi`/`schedules`-timetable
   (todos Clase C o sin evento de negocio claro) — cerrar por dominio, cuando cada uno tenga un
   evento real que medir, nunca de una vez.

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
