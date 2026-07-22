# edu_platform — Plan de cierre end-to-end (app académica operativa y robusta)

> **Qué es este documento.** Valida el camino para que `edu_platform` ejecute **de principio a fin**
> todos los procesos académicos: matrícula · asignación de grupos · registro de notas · evaluación ·
> seguimiento académico · seguimiento disciplinario · psicoorientación · emisión de boletines ·
> alertas tempranas para docentes y acudientes (criterio de hecho, §1). Tier C
> (`cafeteria`/`transportation`/timetable/`admissions`/`library`) es **nice-to-have**, fuera de este
> criterio.
>
> **Estado: PLAN COMPLETO.** Los nueve procesos del criterio de hecho son reales (Fases A/B/C,
> cerradas v1.35.0→v1.46.0). Fase D (tier C, driver-based) cerró 5 de sus 6 candidatos de recon
> (`cafeteria` alérgenos v1.47.0, `student_support` resto v1.48.0, `transportation` v1.49.0,
> `schedules` timetable v1.50.0, `cafeteria` resto v1.51.0 + su metering v1.52.0) — **único ítem
> abierto: §2 abajo.**
>
> **Depurado 2026-07-22**: toda la narrativa de "cómo se cerró cada fase/slice" (matriz de
> operabilidad, cabos de operabilidad ya resueltos, decisiones a confirmar ya resueltas, checklist
> final) se retiró de aquí — cobertura 1:1 confirmada contra el repo antes de limpiar (commit log +
> `grep` de modelos/migraciones/wiring real, no solo lectura de los docs). Destino:
> - **Narrativa completa de cada fase/slice cerrado** → `HISTORIA.md` (changelog, v1.35.0→v1.52.0).
> - **Decisiones de arquitectura ya resueltas** (A1–A8, incl. autoría de `character_frameworks` y
>   settings-por-institución) → `guidelines/BI_DOCUMENT.md` §13.
> - **Decisiones de arquitectura aún abiertas** (B2/P2) y estado vivo por dominio →
>   `PROJECT_STATE.md` §4 (mapa de dominios) / §10.
> - **Backlog accionable restante** (incl. el ítem de §2 abajo) → `OPEN_PROCESS.md`.
>
> **El repositorio sigue siendo la fuente de verdad del código.** Ante discrepancia entre lo escrito
> aquí y lo que hay en disco, gana el repositorio.

---

## 1. Definición de "operativa end-to-end" (criterio de hecho fijado por el owner)

La app debe ejecutar, de punta a punta: **matrícula · asignación de grupos · registro de notas ·
evaluación · seguimiento académico · seguimiento disciplinario · psicoorientación · emisión de
boletines · alertas tempranas para docentes y acudientes.** Tier C (`cafeteria`/`transportation`/
timetable/`admissions`/`library`) es **nice-to-have**, explícitamente fuera de este criterio.

---

## 2. Único ítem abierto: Fase D — `admissions`/`library`

No tienen NINGÚN archivo, ruta, ni entrada de nav — cero superficie, cero riesgo de UX.
Construirlos sería un dominio enteramente greenfield, no una conversión stub→real, sin ningún spec
ni stub previo del que inferir las reglas de negocio (a diferencia de los cinco candidatos ya
cerrados, que partían de un stub con lógica ya observable). **Gateado a confirmación explícita del
owner** — Tier C de `PROJECT_STATE.md` §4: "crear SOLO bajo confirmación explícita". Ver
`guidelines/OPEN_PROCESS.md` ítem #1 para el estado vivo de este backlog.
