# Fase 5B — Implementación, validación integral y preparación de despliegue

Fecha de ejecución: 2026-10-27
Rama: `master` (repositorio raíz + submódulos `app/backend` y `app/frontend`)

Esta fase no agrega módulos de negocio nuevos: valida, endurece, prueba y prepara el
despliegue del MVP construido en las fases 1–5A.

## 1. Resumen de lo implementado

| Área | Resultado |
|---|---|
| Selector de institución | Contexto de sesión para `PLATFORM_ADMIN`, interceptor que agrega `institutionId`, guard de ruta, selector en la barra superior y menú institucional habilitado |
| Gestión de usuarios | Listado, alta, edición, activación/desactivación, roles, cambio y restablecimiento de contraseña, con auditoría y bloqueo inmediato de usuarios desactivados |
| Seguridad financiera | Permisos separados para egresos y reversión de aplicaciones; pruebas que demuestran el rechazo en backend aunque el botón no exista en el frontend |
| Comunicaciones | Auditoría de cada apertura del enlace; se mantuvo la garantía de que `OPENED` no significa enviado |
| Importación | Auditoría de valores anteriores/nuevos al actualizar existentes; un lote obsoleto ya no aborta la importación completa |
| Pruebas frontend | Vitest + jsdom integrados con `@angular/build:unit-test`; 43 pruebas |
| Pruebas E2E | Script reproducible contra API real; 56 verificaciones, 0 fallos |
| Docker | `compose.yaml`, Dockerfiles, `nginx.conf`, `.env.example`, healthchecks; **no ejecutado** (falta Compose) |
| Respaldo | Respaldo lógico real generado y verificado; restauración en base separada **no ejecutada** |

## 2. Selector de institución para PLATFORM_ADMIN

- `InstitutionContextService`: carga instituciones activas, restaura la selección desde
  `sessionStorage` (vive solo lo que dura la pestaña) y la descarta al cerrar sesión o cambiar a
  un usuario institucional.
- `institutionContextInterceptor`: agrega `institutionId` a las peticiones de la API cuando el
  usuario es `PLATFORM_ADMIN` y hay selección. Excluye `/auth` e `/institutions`.
- `institutionContextGuard`: impide navegar a pantallas institucionales sin selección y redirige
  al listado de instituciones. El listado es la única excepción.
- `institution-selector.component`: selector en la barra superior que muestra la institución
  activa y pide confirmación si hay peticiones en curso (`ApiActivityService`).
- Al cambiar de institución se recarga la vista para que ninguna pantalla conserve datos del
  contexto anterior.
- El selector **no es** un mecanismo de autorización: el backend resuelve la institución desde el
  token o desde un `institutionId` explícito validado y auditado (`PLATFORM_GLOBAL_ACCESS`).

## 3. Gestión de usuarios

Endpoints (`/api/v1/users`):

| Método | Ruta | Permiso |
|---|---|---|
| GET | `/users?institutionId=&search=&page=&size=` | `USER_READ` |
| GET | `/users/roles` | `USER_READ` |
| GET | `/users/{id}` | `USER_READ` |
| POST | `/users` | `USER_WRITE` |
| PUT | `/users/{id}` | `USER_WRITE` |
| PATCH | `/users/{id}/status` | `USER_WRITE` |
| PUT | `/users/{id}/roles` | `USER_WRITE` |
| POST | `/users/{id}/password-reset` | `USER_WRITE` |
| PUT | `/users/me/password` | autenticado |

Reglas aplicadas:

- La institución siempre proviene del backend; un administrador institucional no puede operar
  sobre usuarios de otra institución (404/403).
- No se puede asignar `PLATFORM_ADMIN` a un usuario institucional.
- Un administrador no puede desactivarse a sí mismo ni cambiar sus propios roles.
- `ACTIVE_USER_FILTER` invalida de inmediato los tokens de usuarios desactivados, no solo el
  login.
- Auditoría: `USER_CREATED`, `USER_UPDATED`, `USER_ACTIVATED`, `USER_DEACTIVATED`,
  `USER_ROLES_CHANGED`, `USER_PASSWORD_RESET`, `USER_PASSWORD_CHANGED`. Nunca se registra la
  contraseña.
- `PLATFORM_ADMIN` recibe `USER_READ`/`USER_WRITE` en la migración V13 y opera con contexto
  explícito auditado.

## 4. Permisos financieros finales (migración V13)

| Permiso | PLATFORM_ADMIN | INSTITUTION_ADMIN | TREASURY | SECRETARY | DIRECTOR |
|---|---|---|---|---|---|
| `EXPENSE_CREATE` | ✔ | ✔ | ✔ | — | — |
| `EXPENSE_UPDATE` | ✔ | ✔ | ✔ | — | — |
| `EXPENSE_CONFIRM` | ✔ | ✔ | ✔ | — | — |
| `EXPENSE_VOID` | ✔ | ✔ | ✔ | — | — |
| `PAYMENT_REVERSE` | ✔ | ✔ | ✔ | — | — |
| `EXPENSE_WRITE` (obsoleto) | — | — | — | — | — |

Decisión documentada: el negocio todavía no definió segregación de funciones. Los permisos se
separaron técnicamente para poder asignarlos por rol en el futuro, pero se conceden a los mismos
roles que antes tenían `EXPENSE_WRITE` / `PAYMENT_APPLY`. No se agregaron capacidades nuevas.
`EXPENSE_WRITE` quedó sin concesiones y marcado como obsoleto en `PermissionCodes`.

Endpoints afectados:

- `POST /finance/expenses` → `EXPENSE_CREATE`
- `PUT /finance/expenses/{id}` → `EXPENSE_UPDATE`
- `POST /finance/expenses/{id}/confirm` → `EXPENSE_CONFIRM`
- `POST /finance/expenses/{id}/void` → `EXPENSE_VOID`
- `POST /billing/payments/{id}/allocations/{allocationId}/reverse` → `PAYMENT_REVERSE`

El frontend usa estos permisos para mostrar u ocultar acciones, pero el backend es la última
línea de defensa (verificado en `FinancialPermissionIntegrationTest`).

## 5. Comunicaciones e importación

Comunicaciones:

- `OPENED` sigue significando únicamente "se abrió el enlace"; los mensajes de advertencia y la
  auditoría lo indican explícitamente.
- Cada apertura se audita (`COMMUNICATION_OPENED` y `COMMUNICATION_OPENED_AGAIN`).
- La comunicación conserva mensaje, teléfono y nombre de plantilla históricos; no se regenera.
- Errores de validación se devuelven como 400/403/404 sin crear registros.

Importación:

- La confirmación dejó de abortar todo el lote cuando una fila que era válida en la vista previa
  ya no lo es al confirmar (por ejemplo, otro lote creó el mismo estudiante).
- Esa fila se conserva como `ERROR` con el motivo visible y el resto se importa dentro de la
  misma transacción.
- Al actualizar existentes con `allowUpdateExisting=true` se audita
  `STUDENT_IMPORT_ROW_UPDATED` con valores anteriores y nuevos; la identificación se enmascara
  (`***1234`) y nunca se registra completa.
- Se mantienen los límites: solo `.xlsx`, 5 MB, 2 000 filas, procesamiento en memoria y hash
  SHA-256.

## 6. Archivos creados y modificados

### Raíz del repositorio

Creados: `compose.yaml`, `.env.example`, `.gitignore`,
`docs/ejemplos/e2e-fase-5b.sh`, `docs/fase-5b-implementacion.md`, `docs/despliegue.md`,
`docs/operacion.md`, `docs/backups.md`, `docs/checklist-mvp.md`.

### Backend (`app/backend`)

Creados:

- `src/main/resources/db/migration/V13__phase5b_financial_permissions.sql`
- `identity/api/UpdateUserRequest.java`, `UpdateUserStatusRequest.java`,
  `UpdateUserRolesRequest.java`, `ResetPasswordRequest.java`, `ChangePasswordRequest.java`
- `common/security/ActiveUserFilter.java`
- `src/test/java/com/akira/educacion/identity/UserManagementIntegrationTest.java`
- `src/test/java/com/akira/educacion/finance/FinancialPermissionIntegrationTest.java`
- `Dockerfile`, `.dockerignore`

Modificados:

- `identity/service/UserService.java`, `identity/api/UserController.java`,
  `identity/repository/AppUserRepository.java`, `identity/domain/PermissionCodes.java`
- `common/security/SecurityConfig.java` (filtro nuevo y `/actuator/health` público)
- `finance/api/ExpenseController.java`, `billing/api/PaymentController.java`
- `studentimport/service/StudentImportService.java`
- `communication/service/CommunicationService.java`
- `src/test/.../studentimport/StudentImportIntegrationTest.java`
- `pom.xml` (Actuator), `src/main/resources/application.properties` (health), `README.md`

### Frontend (`app/frontend`)

Creados:

- `core/services/api-activity.service.ts`, `core/services/institution-context.service.ts`,
  `core/services/user-api.service.ts`, `core/models/user.models.ts`
- `core/interceptors/activity.interceptor.ts`, `core/interceptors/institution-context.interceptor.ts`
- `core/guards/institution-context.guard.ts`
- `features/users/user-list.component.ts|html`
- `theme/layout/admin/nav-bar/nav-right/institution-selector.component.ts|html`
- Pruebas: `auth.service.spec.ts`, `auth.guard.spec.ts`, `role.guard.spec.ts`,
  `jwt.interceptor.spec.ts`, `error.interceptor.spec.ts`,
  `institution-context.service.spec.ts`, `institution-context.guard.spec.ts`,
  `student-form.component.spec.ts`, `communication-new.component.spec.ts`,
  `student-import.component.spec.ts`
- `Dockerfile`, `nginx.conf`, `.dockerignore`

Modificados:

- `app-routing.module.ts` (guard de contexto y ruta `/users`), `core/guards/role.guard.ts`
- `navigation.ts` (Usuarios y módulos institucionales para plataforma)
- `admin.component.ts` (inicialización del contexto), `nav-right.component.ts|html`
- `main.ts` (nuevos interceptores)
- `finance/expense-list`, `finance/expense-detail`, `billing/payment-detail` (permisos granulares)
- `angular.json` (target `test`), `tsconfig.spec.json`, `package.json` (script `test`,
  `vitest`, `jsdom`), `package-lock.json`

## 7. Pruebas ejecutadas

### Backend

```bash
env DB_URL=jdbc:postgresql://localhost:5432/db_red_new DB_USER=usr_app_red_new \
    DB_PASSWORD=red_new DB_SCHEMA=akira_test ./mvnw -B clean test
```

Resultado real: **138 pruebas, 0 fallos** (BUILD SUCCESS). Nuevas: 16 de usuarios, 6 de permisos
financieros y 1 de importación con lote obsoleto.

Cobertura de los puntos obligatorios (extracto):

- Crear plantilla, `wa.me`, representante no autorizado, teléfono inválido y acceso cruzado:
  `CommunicationIntegrationTest` (8).
- Excel correcto/incorrecto, columnas faltantes, duplicados, vista previa sin persistir,
  confirmación explícita, idempotencia, filas inválidas y auditoría: `StudentImportIntegrationTest` (12 → 13).
- Permisos por rol y acciones no autorizadas por endpoint: `FinancialPermissionIntegrationTest` (6),
  `UserManagementIntegrationTest` (16).

### Frontend

```bash
npm --prefix app/frontend test -- --watch=false
```

Resultado real: **43 pruebas en 10 archivos, 0 fallos** (Vitest 4.1.12, jsdom).

Cubre: login, guard de autenticación, guard por rol, interceptor JWT, interceptor de errores,
selector de institución (servicio y guard), formulario de estudiante, vista previa de
comunicación, enlace `wa.me`, vista previa de Excel, confirmación de importación, errores y
estado vacío.

### Funcionales de extremo a extremo

```bash
bash docs/ejemplos/e2e-fase-5b.sh
```

Resultado real sobre backend en `:8090` con esquema `akira_e2e`: **56 verificaciones, 0 fallos**.
Los 20 flujos solicitados se ejecutaron; la selección de institución y la apertura de `wa.me` se
verificaron contra el mismo endpoint que usa la pantalla (no mediante clics en un navegador).

| # | Flujo | Resultado |
|---|---|---|
| 1 | Login `PLATFORM_ADMIN` | OK |
| 2 | Contexto de institución (con y sin `institutionId`) | OK (200 / 400) |
| 3 | Login `INSTITUTION_ADMIN` | OK |
| 4-5 | Estudiante y representante autorizado | OK |
| 6-7 | Matrícula y obligación | OK (total 100.00) |
| 8-10 | Pago, confirmación, aplicación y recibo | OK (`REC-2026-000001`) |
| 11-13 | Egreso, confirmación y caja | OK |
| 14-15 | Comunicación y enlace `wa.me` + apertura | OK |
| 16-18 | Excel, duplicados y confirmación idempotente | OK |
| 19 | Dashboard y reportes | OK |
| 20 | Aislamiento con segunda institución | OK (404 / 403) |
| Extra | Rol `DIRECTOR` bloqueado en egresos; usuario desactivado sin login ni token válido | OK |

## 8. Compilación y lint

| Comando | Resultado |
|---|---|
| `./mvnw -B clean test` (backend) | BUILD SUCCESS, 138/138 |
| `npm --prefix app/frontend run build` | OK |
| `npm --prefix app/frontend run lint` | All files pass linting |
| `npm --prefix app/frontend test` | 43/43 |

## 9. Estado real de Docker

- Docker 29.9.2 y Compose 5.6.1 disponibles; daemon activo.
- `docker compose config` valida correctamente con un `.env` real.
- `docker compose up -d --build` **no puede levantar la red bridge en este host**:
  `failed to create endpoint ... failed to add the host (veth...) <=> sandbox (veth...) pair
  interfaces: operation not supported`. Un `docker run` simple falla igual.
- Causa comprobada: el kernel en ejecución es `7.3.0-2-cachyos`, pero solo existen módulos
  instalados para `7.3.0-4-cachyos`; sin el módulo `veth` no se pueden crear interfaces de red
  para contenedores. `--network host` sí funciona.
- Verificación alternativa ejecutada: se construyeron las imágenes reales
  (`akira-educacion-backend:test`, `akira-educacion-frontend:test`) con `--network host` y se
  levantó el stack con red host (PostgreSQL en 5433, backend en 8090, nginx en 80). Resultado:
  los tres contenedores quedaron `healthy`, el SPA respondió 200, `/actuator/health` respondió
  `UP`, el login devolvió un JWT de `PLATFORM_ADMIN` y un endpoint protegido devolvió la
  institución demo. Flyway aplicó la versión **13**.
- Corrección derivada: los healthchecks usan `127.0.0.1` en lugar de `localhost` para no
  depender de la resolución IPv6 (`:::1`), que dejaba el frontend `unhealthy` aunque nginx
  respondiera.
- `compose.yaml` con red bridge queda **pendiente de verificación** hasta reiniciar en el kernel
  cuyos módulos están instalados (7.3.0-4) o instalar los módulos del kernel en ejecución.

## 10. Estado real de respaldos

- Se generó un respaldo lógico real:
  `pg_dump -Fc -n akira_e2e -f /tmp/akira_e2e_backup.dump` (146 KB).
- Integridad del archivo verificada con `pg_restore --list` (278 entradas).
- La restauración en una base separada **no se ejecutó**: el rol local no tiene `CREATEDB` y no
  se quiso alterar el esquema del usuario. Procedimiento documentado en `docs/backups.md`.

## 11. Problemas encontrados y corregidos

1. **Lote de importación obsoleto abortaba todo**: si una fila válida pasaba a duplicada entre
   la vista previa y la confirmación, el 409 marcaba la transacción como rollback-only. Se
   reemplazó por una comprobación previa y la fila se reporta como error sin abortar el lote.
2. **`PLATFORM_ADMIN` sin `USER_READ`/`USER_WRITE`**: el endpoint de usuarios le devolvía 403. Se
   agregaron los permisos en V13 con contexto explícito.
3. **Botones financieros desalineados**: el frontend seguía comprobando `EXPENSE_WRITE`. Se
   actualizó a los permisos granulares.
4. **Capturas reales del flujo E2E**: los pagos en efectivo se confirman al registrarse (por
   diseño); el script ahora usa transferencia para ejercitar confirmación y el campo de recibo
   correcto es `receiptNumber`.

## 12. Limitaciones y decisiones pendientes

- No hay segregación de funciones definida por negocio: los permisos granulares existen pero se
  asignan a los mismos roles actuales.
- El selector de institución recarga la vista al cambiar de contexto (se prioriza no conservar
  datos cruzados en memoria).
- `PLATFORM_ADMIN` no tiene pantallas de plataforma para todas las operaciones institucionales
  (usa el selector y los mismos listados); el backend ya lo soporta.
- Reportes sin exportación PDF/Excel: se documenta como pendiente, no se implementó por
  iniciativa propia.
- Docker/Compose sin ejecutar por falta de plugin.
- Restauración de respaldo no ejecutada (ver `docs/backups.md`).
- Los tokens no se revocan en servidor al cambiar contraseña; el usuario desactivado sí queda
  bloqueado de inmediato por `ActiveUserFilter`.
- No se probó la interfaz con clics reales en navegador para los 20 flujos; la evidencia E2E es a
  nivel API más las pruebas de componentes.

## 13. Documentos relacionados

- `docs/despliegue.md` — guía de despliegue.
- `docs/operacion.md` — operación inicial.
- `docs/backups.md` — respaldo y recuperación.
- `docs/checklist-mvp.md` — checklist de aceptación.
- `docs/ejemplos/e2e-fase-5b.sh` — prueba E2E reproducible.
