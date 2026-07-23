# edu_platform — Proceso abierto (backlog pendiente)

> Archivo hermano de `PROJECT_STATE.md` y `HISTORIA.md`. **Es una TO-DO LIST, no un registro.**
> Contiene SOLO pendientes accionables para los siguientes slices — nunca la narrativa de lo que
> ya se cerró (eso vive en `HISTORIA.md`, changelog completo) ni el estado actual por dominio (eso
> vive en `PROJECT_STATE.md` §4/Metadatos). Un ítem cerrado se **quita de este archivo por
> completo** — nunca queda tachado/anotado aquí "a modo de recuerdo": ese recuerdo ya vive en los
> otros dos documentos, y dejarlo aquí también vuelve a mezclar backlog con historia (el problema
> que motivó separar estos tres archivos en primer lugar).
>
> **El repositorio sigue siendo la fuente de verdad del código.** Ante discrepancia entre lo escrito
> aquí y lo que hay en disco, gana el repositorio. Al cerrar un ítem de este backlog: (1) **quitar
> la línea de aquí por completo** (nunca tachar-y-dejar), (2) agregar la entrada de versión en
> `HISTORIA.md`, (3) actualizar el mapa de dominios/estado-en-una-línea de `PROJECT_STATE.md`,
> (4) si el slice deja una lección estructural reusable, agregar un guardrail nuevo en
> `PROJECT_STATE.md` §13.

---

## 1. Backlog pendiente (orden sugerido)

> **No queda ningún ítem listo para construir con un default seguro** (a diferencia de un stub
> existente con lógica ya inferible, o un evento real ya wireable con un molde ya usado varias
> veces) — **todo lo que sigue está gateado por una confirmación explícita del owner o una decisión
> de negocio real.** Cada ítem indica cuál.

1. **Onboarding — hardening no bloqueante** — ⛔ **gateado: sin necesidad de producción confirmada**
   (ver `HISTORIA.md` v1.7.0/v1.32.0, marcado así explícitamente en el propio texto del ítem, no
   solo aquí): batch-invite tras el alta de acudientes (hoy un acudiente creado por roster import no
   recibe ninguna invitación — confirmado por `test/integration/roster_imports_guardians_test.rb`);
   full-async de parse+validar de `RosterImport` (hoy corre síncrono en `#create`, capado a
   `MAX_ROWS`, cambiarlo requiere rediseñar el estado "pendiente" de la vista previa y sus tests).
   Webhook real para `Invitations::BounceHandler` — ⛔ **gateado: decisión de negocio** (requiere
   elegir proveedor de correo antes de construir el receptor).

2. **Tiempo real** (Turbo Streams sobre Solid Cable, sin Redis) — ⛔ **gateado: sin driver real
   todavía** — `transportation` (broadcast de `boarding_events`, cuya persistencia ya es real desde
   v1.49.0) y `communication` (canales). Diferido.

3. **M1 — metering por dominio, resto** — ⛔ **gateado: sin evento de negocio claro todavía** (ver
   `PROJECT_STATE.md` §10, fila M1). Sigue abierto solo para `student_support`/`counseling`/
   `analytics_bi` (Clase C o sin evento de negocio claro) y `schedules`-timetable (real desde
   v1.50.0, pero sin un evento tan claro como una clase impartida) — cerrar por dominio, cuando
   cada uno tenga un evento real que medir, nunca de una vez.

4. **Decisiones abiertas de arquitectura sin backlog de construcción propio** — ⛔ **gateado:
   pregunta para el owner, no una tarea de construcción** — ver `PROJECT_STATE.md` §10 para el
   detalle: **B2** (¿`role_assignments.valid_from/until` se acopla a `academic_terms`?), **P2**
   (¿qué hacer con `institution_users.role`, columna libre sin lectores?).

5. **`finance` — procesar/aprobar los cobros de admisión** — ⛔ **gateado: pedido explícito del
   owner al confirmar el diseño de `admissions` Incremento 2**. `Admissions::AcceptanceConverter`
   genera un `Finance::Charge` real al aceptar una solicitud (una vez existen `Student`+
   `StudentAccount`), pero cerrarlo — registrar el pago y dar por aprobado/cerrado el proceso de
   admisión — sigue siendo 100% manual vía `Finance::PaymentRecorder` ya existente, sin ningún
   gancho de vuelta hacia `admissions` (ni un estado "fee pagado" visible en la solicitud, ni nada
   que dispare una notificación). No se construye hasta que el owner confirme cómo debe verse ese
   camino — mismo criterio que el resto de items de este backlog (riel de pago real ya está fuera
   de alcance de v1, ver no-goals abajo).

**Próximo paso sugerido**: ninguno de los cinco es "el siguiente slice obvio" — pedir al owner que
elija uno y confirme explícitamente antes de construir cualquiera de estos.

### No-goals confirmados (fuera de alcance, no backlog)

- **Riel de pago AUTOMÁTICO/pasarela** (cobrar una factura sin intervención humana) — fuera de
  alcance de v1; finalizar una factura la congela, no la cobra. El registro MANUAL de un abono
  (`ControlPlane::Payment`) sí es real — este no-goal cubre solo la automatización.
- Integración GPS/mapa para `transportation` — sin señal de necesidad real.

---

## 2. Guardrails operativos

> **Viven en `PROJECT_STATE.md` §13** — son invariantes ya asentados, no tareas pendientes de este
> backlog. Consultar esa sección antes de construir cualquier slice nuevo, especialmente uno que
> toque un dominio con guardrails propios ya documentados (billing, RLS/GUC, `assignments`,
> `analytics_bi`/HPS, portales, RBAC).
