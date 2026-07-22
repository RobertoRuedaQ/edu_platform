# Arquitectura y Recursos Mínimos Recomendados

Para este tipo de stack **Single-Database**, la latencia de red entre Rails y la base de datos es crítica (ya que Solid Cache hará muchas consultas por petición). Recomiendo iniciar con una arquitectura de **Monolito Contenido (Single Instance)** o un clúster muy ajustado.

## Opción Recomendada: Servidor Único VPS / Instancia Dedicada

Al estar todo en la base de datos, correr Rails y PostgreSQL en la misma máquina virtual (con aislamiento por Docker/Kamal) elimina la latencia de red y optimiza el uso de RAM mediante el *page cache* de Linux.

| Componente     | Especificación Mínima               | Notas Operativas                                                                                                                                    |
| -------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| CPU            | 4 vCPUs (Dedicados preferiblemente) | 2 para Rails/Puma/Workers, 2 para Postgres 18                                                                                                       |
| Memoria RAM    | 8 GB RAM                            | 3 GB para Rails (YJIT + Puma + Workers), 4 GB para Postgres (Shared Buffers + Cache), 1 GB margen del S.O.                                          |
| Almacenamiento | 50 GB a 100 GB NVMe SSD             | Crítico: No usar discos HDD ni SSD estándar saturados. Solid Cache y Queue generarán muchas escrituras/lecturas de páginas. Necesitamos altos IOPS. |

Si se decide separar App y DB en instancias independientes:

* **Servidor de Aplicaciones:** 2 vCPUs / 4 GB RAM.
* **Servidor de Base de Datos:** 2 vCPUs / 4 GB RAM con almacenamiento NVMe.

### Configuración estimada del Servidor de Aplicaciones (Puma)

* **Puma Workers:** 2 procesos (aprovechando los cores de CPU).
* **Threads por Worker:** 5 threads (mínimo 3, máximo 5 para no saturar el pool de conexiones).
* **Solid Queue Workers:** 1 proceso dedicado con 3-5 threads para procesar correos y tareas secundarias.

---

# 2. Lineamientos y Recomendaciones para Desarrolladores

Para que este hardware mínimo resista la carga de los **150 usuarios concurrentes** sin degradarse, los desarrolladores deben programar bajo una premisa estricta:

> **"PostgreSQL es nuestro recurso más sagrado".**

## A. Base de Datos y Active Record

### Evitar el "Eager Loading" ciego, pero penalizar el N+1

Activar `strict_loading!` en entornos de desarrollo y staging.

Cada consulta N+1 innecesaria ahora compite con los recursos de Solid Cache.

### Uso correcto de UUIDv7

Al ser secuenciales por tiempo, son excelentes para los índices.

Los desarrolladores no deben usar ordenamientos por defecto por `created_at` si pueden ordenar directamente por el `id` (UUIDv7), ahorrando un índice secundario.

### JSONB y Full Text Search Nativo

**Prohibido** procesar strings o filtrar grandes volúmenes de datos en Ruby.

Si hay búsquedas de alumnos o cursos:

* Utilizar Full Text Search nativo de PostgreSQL 18.
* Crear índices adecuados (GIN).

Si hay metadatos mutables:

* Utilizar JSONB.
* Indexar correctamente los atributos consultados.

### Políticas RLS (Row Level Security) Eficientes

Como la autorización es un RBAC casero con RLS:

* Las funciones de las políticas deben ser extremadamente rápidas.
* Preferir operadores directos.
* Utilizar subconsultas simples.
* Evitar lógica compleja.

Una política RLS lenta duplicará el tiempo de ejecución de cada consulta dentro del tenant.

---

## B. Optimización de la Trilogía Solid (Cache, Queue y Cable)

### Solid Cache (Control de Tamaño)

Evitar cachear:

* Bloques gigantescos de HTML.
* Páginas completas con grandes cantidades de datos.

Preferir:

* Fragment caching.
* Datos serializados pequeños.

El *write amplification* en PostgreSQL puede fragmentar las tablas si se guardan objetos enormes constantemente.

### Solid Queue (Argumentos Livianos)

Al pasar trabajos mediante `deliver_later`:

**Nunca pasar objetos complejos.**

Pasar únicamente:

* IDs (UUIDv7).

Solid Queue almacena los argumentos como JSON en PostgreSQL. Strings u objetos muy grandes ralentizan las tablas de la cola.

### Solid Cable (Streaming Quirúrgico)

Al no utilizar Redis:

* Cada transmisión por WebSocket implica operaciones sobre PostgreSQL.

Evitar:

* Actualizaciones segundo a segundo.
* Streaming de progreso continuo.
* Eventos extremadamente frecuentes.

Preferir eventos discretos:

* `curso_completado`
* `nuevo_mensaje`
* `calificacion_publicada`
* `tarea_entregada`

---

## C. Gestión de Memoria en Ruby 4 + YJIT

### YJIT Warmup

YJIT necesita "calentar" el código para optimizarlo.

Esto implica:

* Mayor consumo inicial de memoria.
* Mejor rendimiento sostenido posteriormente.

Recomendaciones:

* Evitar dependencias innecesarias.
* Minimizar el número de gemas.
* Mantener el footprint de memoria bajo.

Objetivo:

> Menos de 250 MB por worker Puma.

### Evitar Alocación Masiva de Objetos

En exportaciones de reportes o grandes listados:

Utilizar:

```ruby
Model.find_each
```

o

```ruby
Model.pluck(:id, :name)
```

o

```ruby
Model.pick(:name)
```

Evitar:

```ruby
Model.all.each
```

cuando existan miles de registros.

---

# 3. Estrategia de Conexiones (El Punto Crítico)

Con Rails operando:

* La aplicación.
* Solid Cache.
* Solid Queue.
* Solid Cable.

El número de conexiones a PostgreSQL puede crecer rápidamente.

## Fórmula del Connection Pool

Cada uno de los siguientes componentes puede requerir conexiones:

* Threads de Puma.
* Threads de Solid Queue.
* Conexiones de Solid Cable.
* Procesos auxiliares.

## Recomendación Inicial

Configurar el `database.yml` con un pool estricto:

```yaml
pool: 15
```

## Cuándo Introducir PgBouncer

Si la concurrencia supera aproximadamente:

* 50 a 60 conexiones simultáneas activas.

Implementar inmediatamente:

**PgBouncer en modo Transaction Pooling.**

Beneficios:

* Reutilización eficiente de conexiones.
* Menor consumo de memoria en PostgreSQL.
* Mayor estabilidad bajo carga.

---

# Resumen para el Equipo de Desarrollo

> Tenemos un Ferrari de desarrollo: Rails 8 + PostgreSQL 18 nativo.
>
> No dependemos de Redis, Sidekiq, ElasticSearch ni infraestructura compleja.
>
> Para mantenerlo funcionando de manera eficiente en un servidor económico:
>
> * Toda la lógica de filtrado, ordenamiento y búsqueda debe ejecutarse en PostgreSQL.
> * La seguridad multi-tenant debe apoyarse en RLS eficiente.
> * Los procesos Ruby deben mantenerse ligeros en memoria.
> * Las tareas pesadas deben ejecutarse de forma asíncrona.
> * El número de conexiones debe controlarse cuidadosamente.
>
> Si seguimos estas reglas, una única instancia correctamente configurada puede soportar cómodamente la carga inicial del producto mientras mantenemos una arquitectura simple, económica y fácil de operar.
