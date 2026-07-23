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

> **No queda ningún ítem listo para construir con un default seguro** (a diferencia de un stub
> existente con lógica ya inferible, o un evento real ya wireable con un molde ya usado varias
> veces) — **todo lo que sigue está gateado por una confirmación explícita del owner o una decisión
> de negocio real.** Cada ítem indica cuál.

1. **Fase D — greenfield puro** — ✅ **CERRADO POR COMPLETO (v1.56.0)**, confirmado explícitamente
   por el owner en cada incremento (`guidelines/library_prompt.md`, la especificación funcional
   completa que el owner entregó).
   ~~`library`~~ ✅ **CERRADO (v1.54.0)** — tres tablas net-new, `LoanRecorder`/`ReturnRecorder`
   (`copy.lock!`, primer molde de este repo que guarda la propia columna de estado de la fila
   bloqueada), portales estudiante/acudiente, metering M1 cableado desde el día uno. Ver
   `HISTORIA.md` v1.54.0.
   ~~`admissions` Incremento 2 (base)~~ ✅ **CERRADO (v1.55.0)** — cuatro tablas net-new
   (campañas/aspirantes/solicitudes/documentos), `AcceptanceConverter` (crea el `Student` real
   — corrección: `Schedules::Enrollment` era la primitiva equivocada, es matrícula de MATERIA —
   liga al acudiente, cobra la cuota vía `Finance::Charge` SOLO al aceptar, nunca al radicar, ver
   ítem #7 abajo). Ver `HISTORIA.md` v1.55.0.
   ~~`admissions` Incremento 3 (pasos configurables + tracker público)~~ ✅ **CERRADO (v1.56.0)**
   — `admission_step_templates`/`admission_application_steps` (instancias mutables reales, nunca
   snapshot); tracker público por token (`/admisiones/solicitud/:token`, subdominio-scoped, molde
   `Invitations::Issuer`); redacción de `private_notes`/evaluador vía `Admissions::Tracker::
   PublicView` (Data allowlist, molde `AuraScope`) — primera página pública de este repo que oculta
   CAMPOS, no filas enteras. Ver `HISTORIA.md` v1.56.0. **`admissions` queda 100% cerrado** — solo
   sigue pendiente el ítem #7 de este backlog (`finance` procesando/aprobando el cobro).

2. **Onboarding — hardening no bloqueante** — ⛔ **gateado: sin necesidad de producción confirmada**
   (ver `HISTORIA.md` v1.7.0/v1.32.0, marcado así explícitamente en el propio texto del ítem, no
   solo aquí): batch-invite tras el alta de acudientes (hoy un acudiente creado por roster import no
   recibe ninguna invitación — confirmado por `test/integration/roster_imports_guardians_test.rb`);
   full-async de parse+validar de `RosterImport` (hoy corre síncrono en `#create`, capado a
   `MAX_ROWS`, cambiarlo requiere rediseñar el estado "pendiente" de la vista previa y sus tests).
   Webhook real para `Invitations::BounceHandler` — ⛔ **gateado: decisión de negocio** (requiere
   elegir proveedor de correo antes de construir el receptor).
   ~~Purga de `roster_import_rows` post-commit~~ ✅ **CERRADO (v1.53.0), confirmado explícitamente
   por el owner** — `Core::RosterImport::RowPurger`/`PurgeRowsAllJob` (molde `ExpireAllJob`), purga
   DIFERIDA 30 días (`RETENTION`, PLACEHOLDER), ancla `committed_at` nueva en `roster_import_batches`.
   Ver `HISTORIA.md` v1.53.0.

3. **Billing — hardening pendiente** — ⛔ **gateado: decisión de negocio real** (ver `HISTORIA.md`
   v1.33.0 para lo ya cerrado): estos tres no son defaults seguros de asumir — prorrateo de
   `addon_fee`; edición manual de líneas de un borrador; tabla `billing_periods` explícita.

4. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis) — ⛔ **gateado: sin driver real
   todavía** — `transportation` (broadcast de `boarding_events`, cuya persistencia ya es real desde
   v1.49.0) y `communication` (canales). Diferido.

5. **M1 — metering por dominio, resto** — ⛔ **gateado: sin evento de negocio claro todavía** (ver
   `PROJECT_STATE.md` §10, fila M1). `cafeteria` y `transportation` ya cerrados (v1.51.0→v1.52.0,
   v1.49.0→v1.52.0); `library` cerrado desde el día uno (v1.54.0, sin retrofit) — sigue abierto solo
   para `student_support`/`counseling`/`analytics_bi` (Clase C o sin evento de negocio claro) y
   `schedules`-timetable (real desde v1.50.0, pero sin un evento tan claro como una clase impartida)
   — cerrar por dominio, cuando cada uno tenga un evento real que medir, nunca de una vez.

6. **Decisiones abiertas de arquitectura sin backlog de construcción propio** — ⛔ **gateado:
   pregunta para el owner, no una tarea de construcción** — ver `PROJECT_STATE.md` §10 para el
   detalle: **B2** (¿`role_assignments.valid_from/until` se acopla a `academic_terms`?), **P2**
   (¿qué hacer con `institution_users.role`, columna libre sin lectores?).

7. **`finance` — procesar/aprobar los cobros de admisión** — ⛔ **gateado: pedido explícito del
   owner al confirmar el diseño de `admissions` Incremento 2**. `Admissions::AcceptanceConverter`
   genera un `Finance::Charge` real al aceptar una solicitud (una vez existen `Student`+
   `StudentAccount`), pero cerrarlo — registrar el pago y dar por aprobado/cerrado el proceso de
   admisión — sigue siendo 100% manual vía `Finance::PaymentRecorder` ya existente, sin ningún
   gancho de vuelta hacia `admissions` (ni un estado "fee pagado" visible en la solicitud, ni nada
   que dispare una notificación). No se construye hasta que el owner confirme cómo debe verse ese
   camino — mismo criterio que el resto de items de este backlog (riel de pago real ya está fuera
   de alcance de v1, ver no-goals abajo).

**Próximo paso sugerido**: con el ítem #1 (Fase D) 100% cerrado, quedan seis pendientes (#2–#7) y
ninguno es "el siguiente slice obvio" — pedir al owner que elija uno y confirme explícitamente antes
de construir cualquiera de estos (mismo patrón que ya cerró la purga de `roster_import_rows`,
v1.53.0, y los tres incrementos de Fase D).

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
