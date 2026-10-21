# Fase 2 — Implementación: gestión escolar, catálogo y matrículas

Fecha: 2026-10-21
Repositorio: `akira-educacion-app` (submódulos `app/backend` y `app/frontend`)

## 1. Resumen

Se implementaron los módulos `students`, `representatives`, `catalog` y `enrollment`
sobre la arquitectura de la Fase 1, sin crear repositorios nuevos ni reemplazar la
plantilla Berry. El aislamiento institucional se mantiene en la capa de servicio, en
las consultas y, además, en la base de datos mediante claves foráneas compuestas.

Decisiones relevantes:

- **Contexto institucional:** `InstitutionScope` resuelve la institución siempre desde
  el token. Un usuario institucional que envíe otro `institutionId` recibe `403`;
  `PLATFORM_ADMIN` debe indicarlo de forma explícita y cada acceso queda auditado
  (`PLATFORM_GLOBAL_ACCESS`).
- **Integridad entre instituciones:** las referencias usan claves foráneas compuestas
  `(institution_id, id)`, por lo que una referencia cruzada es rechazada por PostgreSQL
  incluso si fallara la validación de la aplicación.
- **Precios históricos:** la matrícula copia el precio acordado y, al confirmarse, la
  tasa de IVA vigente de la institución. Cambios posteriores de catálogo o de
  configuración no alteran matrículas existentes.
- **Observaciones:** `notes` solo se devuelve con `STUDENT_NOTES_READ`; en otro caso
  llega `null` y `notesRestricted = true`.

## 2. Migraciones Flyway agregadas

| Versión | Archivo | Contenido |
|---|---|---|
| V3 | `V3__school_management_schema.sql` | `educational_level`, `academic_period`, `catalog_service`, `plan`, `plan_service`, `service_rate`, `student`, `representative`, `student_representative`, `enrollment`, `enrollment_service`, `enrollment_history`, índices y restricciones |
| V4 | `V4__phase2_permissions.sql` | 9 permisos nuevos y su asignación por rol |

No se modificaron V1 ni V2. Se mantiene `ddl-auto=validate`; el esquema es propiedad de
Flyway.

Restricciones destacadas:

- `UNIQUE (institution_id, document_number)` parcial en `student` y `representative`.
- `UNIQUE (institution_id, name)` en niveles, períodos, servicios y planes.
- `UNIQUE (plan_id, service_id)` y `UNIQUE (enrollment_id, service_id)`.
- `CHECK` de estados (`student`, `enrollment`), precios no negativos y rangos de fechas.
- Claves foráneas compuestas `(institution_id, ...)` en todas las referencias cruzadas.

## 3. Endpoints implementados

### Estudiantes
- `GET /api/v1/students` (paginado, `search`, `status`)
- `POST /api/v1/students`
- `GET /api/v1/students/{id}`
- `PUT /api/v1/students/{id}`
- `DELETE /api/v1/students/{id}` (409 si tiene matrículas)
- `GET/POST /api/v1/students/{id}/representatives`
- `PUT/DELETE /api/v1/students/{id}/representatives/{representativeId}`

### Representantes
- `GET /api/v1/representatives` (paginado, `search`)
- `POST /api/v1/representatives`
- `GET/PUT /api/v1/representatives/{id}`
- `GET /api/v1/representatives/{id}/students`

### Catálogo
- `GET/POST /api/v1/catalog/levels`, `PUT /levels/{id}`
- `GET/POST /api/v1/catalog/periods`, `PUT /periods/{id}`
- `GET/POST /api/v1/catalog/services`, `PUT /services/{id}`
- `GET/POST /api/v1/catalog/plans`, `PUT /plans/{id}`
- `GET/POST /api/v1/catalog/rates`, `PUT /rates/{id}`

### Matrículas
- `GET /api/v1/enrollments` (`status`, `studentId`, `academicPeriodId`, paginado)
- `POST /api/v1/enrollments` (estado inicial `DRAFT`)
- `GET /api/v1/enrollments/{id}`
- `PUT /api/v1/enrollments/{id}` (solo `DRAFT`)
- `POST /api/v1/enrollments/{id}/confirm`
- `POST /api/v1/enrollments/{id}/cancel`
- `POST /api/v1/enrollments/{id}/complete`
- `GET /api/v1/enrollments/{id}/history`

## 4. Pantallas implementadas

| Ruta | Componente | Descripción |
|---|---|---|
| `/students` | `StudentListComponent` | Listado, búsqueda por nombres/apellidos/identificación, filtro por estado, paginación, estados de carga/error/vacío |
| `/students/new` | `StudentFormComponent` | Alta de estudiante |
| `/students/:id` | `StudentDetailComponent` | Expediente, representantes y matrículas del estudiante |
| `/students/:id/edit` | `StudentFormComponent` | Edición de estudiante |
| `/representatives` | `RepresentativeListComponent` | Listado, búsqueda, alta/edición y estudiantes asociados |
| `/catalog` | `CatalogComponent` | Pestañas de niveles, períodos, servicios, planes y tarifas con formularios |
| `/enrollments` | `EnrollmentListComponent` | Listado con filtros por estado y período |
| `/enrollments/new` | `EnrollmentFormComponent` | Nueva matrícula con servicios adicionales |
| `/enrollments/:id` | `EnrollmentDetailComponent` | Detalle, totales, acciones e historial |
| `/enrollments/:id/edit` | `EnrollmentFormComponent` | Edición mientras la matrícula es `DRAFT` |

Además:

- Navegación lateral nueva para usuarios institucionales.
- Guards por rol en todas las rutas nuevas; el backend valida los permisos.
- Confirmaciones al eliminar un estudiante, quitar un representante y cancelar una
  matrícula (con motivo obligatorio).
- Navegación desde el estudiante hacia representantes y matrículas.

## 5. Cambios en cada submódulo

### `app/backend`

Archivos creados (principales):

```text
common/api/SearchPatterns.java
institution/service/InstitutionScope.java
students/domain/{Student,StudentStatus,StudentRepresentative}.java
students/repository/{StudentRepository,StudentRepresentativeRepository}.java
students/api/{CreateStudentRequest,UpdateStudentRequest,StudentResponse,
              LinkRepresentativeRequest,StudentRepresentativeResponse,StudentController}.java
students/service/{StudentService,StudentRepresentativeService}.java
representatives/domain/Representative.java
representatives/repository/RepresentativeRepository.java
representatives/api/{CreateRepresentativeRequest,UpdateRepresentativeRequest,
                      RepresentativeResponse,RepresentativeStudentResponse,
                      RepresentativeController}.java
representatives/service/RepresentativeService.java
catalog/domain/{EducationalLevel,AcademicPeriod,CatalogServiceItem,Plan,PlanService,ServiceRate}.java
catalog/repository/{EducationalLevelRepository,AcademicPeriodRepository,
                    CatalogServiceItemRepository,PlanRepository,ServiceRateRepository}.java
catalog/api/{EducationalLevelRequest/Response,AcademicPeriodRequest/Response,
             CatalogServiceRequest/Response,PlanRequest/Response,
             ServiceRateRequest/Response,CatalogController}.java
catalog/service/CatalogService.java
enrollment/domain/{Enrollment,EnrollmentStatus,EnrollmentServiceLine,EnrollmentHistory}.java
enrollment/repository/{EnrollmentRepository,EnrollmentHistoryRepository}.java
enrollment/api/{EnrollmentRequest,CancelEnrollmentRequest,EnrollmentResponse,
                EnrollmentHistoryResponse,EnrollmentController}.java
enrollment/service/{EnrollmentService,InitialChargeGenerator,NoOpInitialChargeGenerator}.java
```

Archivos modificados:

- `identity/domain/PermissionCodes.java`: permisos de la Fase 2.
- `common/api/ApiExceptionHandler.java`: `MethodArgumentTypeMismatchException` → 400.
- `README.md`: endpoints, estructura y resultado de pruebas.

### `app/frontend`

Archivos creados:

```text
core/models/school.models.ts
core/services/{student-api,representative-api,catalog-api,enrollment-api}.service.ts
features/students/{student-list,student-form,student-detail}.component.{ts,html}
features/representatives/representative-list.component.{ts,html}
features/catalog/catalog.component.{ts,html}
features/enrollments/{enrollment-list,enrollment-form,enrollment-detail}.component.{ts,html}
```

Archivos modificados:

- `core/services/auth.service.ts`: helper `hasPermission`.
- `app-routing.module.ts`: rutas nuevas con guards por rol.
- `theme/layout/admin/navigation/navigation.ts`: entradas de menú.

## 6. Pruebas ejecutadas y resultados

Comando real:

```sh
env DB_URL=jdbc:postgresql://localhost:5432/db_red_new \
    DB_USER=usr_app_red_new DB_PASSWORD=red_new DB_SCHEMA=akira_test \
    ./mvnw -B test
```

Resultado: **49 pruebas, 0 fallos, 0 errores** (incluye las 22 de la Fase 1).

| Requisito | Prueba |
|---|---|
| 1. Crear estudiante | `StudentManagementIntegrationTest.creaUnEstudiante` |
| 2. Editar estudiante | `...editaUnEstudiante` |
| 3. Buscar y filtrar | `...buscaYFiltraEstudiantes` |
| 4. Crear representantes | `...creaRepresentantes` |
| 5. Varios representantes por estudiante | `...asociaVariosRepresentantesAUnEstudiante` |
| 6. Un representante con varios estudiantes | `...asociaUnRepresentanteAVariosEstudiantes` |
| 7. Rechazo de acceso entre instituciones | `Phase2IsolationIntegrationTest.unaInstitucionNoAccedeAEstudiantesDeOtra` |
| 8. Crear nivel educativo | `CatalogIntegrationTest.creaUnNivelEducativo` |
| 9. Crear período lectivo | `...creaUnPeriodoLectivo` |
| 10. Plan, servicios y tarifa | `...creaPlanServiciosYTarifa` |
| 11. Matrícula con período | `EnrollmentIntegrationTest.creaMatriculaConPeriodoLectivo` |
| 12. Matrícula sin período | `...creaMatriculaSinPeriodoLectivo` |
| 13. Confirmar matrícula | `...confirmaMatriculaYCongelaElIva` |
| 14. Cancelar con motivo | `...cancelaMatriculaConMotivo` |
| 15. Referencias cruzadas | `Phase2IsolationIntegrationTest.noPermiteReferenciasCruzadasEnLaApi` y `laBaseDeDatosRechazaReferenciasCruzadas` |
| 16. Precio acordado inmutable | `EnrollmentIntegrationTest.mantieneElPrecioAcordadoAunqueCambieLaTarifa` |
| 17. Permisos por rol | `secretariaGestionaEstudiantesYTesoreriaNo`, `lasObservacionesDelEstudianteEstanProtegidas`, `tesoreriaYDireccionNoAdministranElCatalogo`, `soloQuienTienePermisoDeMatriculaPuedeCrear`, `platformAdminRequiereInstitucionExplicitaYDejaAuditoria` |

Pruebas adicionales: matrícula confirmada no editable (409), identificación duplicada
(409), tarifa con vigencia inválida (400), contacto principal único por estudiante,
eliminación de estudiante con matrículas (409).

## 7. Estado de compilación

| Verificación | Comando | Resultado |
|---|---|---|
| Backend compile | `./mvnw -B compile` | OK |
| Backend tests | `./mvnw -B test` (con variables de BD local) | 49/49 OK |
| Frontend build dev | `npm --prefix app/frontend run build:dev` | OK |
| Frontend build prod | `npm --prefix app/frontend run build` | OK |
| Frontend lint | `npm --prefix app/frontend run lint` | OK, sin advertencias |

## 8. Pendientes técnicos de la Fase 1 que siguen abiertos

- Base dedicada `akira_educacion`: se sigue usando `db_red_new` local con esquemas
  `akira_dev` / `akira_test` por permisos del rol local.
- Edición, desactivación y restablecimiento de contraseña de usuarios.
- Refresh token, bloqueo por intentos fallidos y recuperación de contraseña.
- Los módulos habilitados por institución aún no condicionan endpoints.
- Frontend sin pruebas automatizadas (no hay runner configurado en la plantilla).
- Docker Compose sin verificar (daemon no operativo en el entorno).
- Consulta de auditoría por API.

## 9. Funcionalidades deliberadamente no implementadas

- **Pagos, obligaciones, egresos, comunicaciones y reportes avanzados** (fuera del
  alcance de la Fase 2).
- **Generación del cobro inicial:** solo existe la interfaz
  `InitialChargeGenerator` con una implementación no operativa
  (`NoOpInitialChargeGenerator`). No se inventaron reglas financieras.
- **Anulación de pagos por el administrador:** no aplica todavía porque los pagos no
  existen.
- **Enlaces `wa.me`:** previstos para una fase posterior.
- **Períodos lectivos obligatorios:** son opcionales por decisión del alcance.

## 10. Bases de datos

- Desarrollo y pruebas contra **PostgreSQL local** (`localhost:5432`).
- **No se utilizó la base externa compartida** (`172.16.1.72`).
- Esquema de pruebas `akira_test`, aislado y migrado desde cero en cada ejecución.
