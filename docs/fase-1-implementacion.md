# Fase 1 — Implementación: fundamentos, autenticación y configuración institucional

**Fecha:** 2026-10-21
**Alcance:** backend `app/backend` y frontend `app/frontend`, sin crear repositorios nuevos ni reemplazar la plantilla Berry.

---

## 1. Resumen

Se implementó la Fase 1 completa:

- Perfiles `dev`, `test` y `prod`.
- PostgreSQL por variables de entorno, Flyway con soporte real para PostgreSQL y `ddl-auto=validate`.
- API versionada bajo `/api/v1` con DTOs, Bean Validation, paginación y errores `ProblemDetail`.
- Spring Security stateless con JWT HS256, BCrypt y permisos por rol.
- Entidades `Institution`, `AppUser`, `Role`, `Permission`, módulos habilitados y auditoría.
- Endpoints de login, perfil, instituciones (global y propia) y usuarios de institución.
- Frontend con `HttpClient`, interceptores JWT/errores, guards, login real, rutas por rol y pantallas iniciales de `PLATFORM_ADMIN` e `INSTITUTION_ADMIN`.
- OpenAPI/Swagger funcionando con esquema `bearerAuth`.

**Resultado real:** 22 pruebas ejecutadas, 0 fallos; backend y frontend compilan; flujo completo verificado en navegador.

---

## 2. Alcance backend (punto por punto)

| # | Requisito | Estado |
|---|---|---|
| 1 | Perfiles `dev`, `test`, `prod` | Implementado (`application-{dev,test,prod}.properties`) |
| 2 | Configuración PostgreSQL por variables de entorno | Implementado (`DB_URL`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA`) |
| 3 | `.env.example` sin secretos reales | Implementado (`app/backend/.env.example`) |
| 4 | Flyway para PostgreSQL | Implementado (`flyway-database-postgresql` + `spring.flyway.*`) |
| 5 | Migración inicial del esquema | `V1__initial_schema.sql` |
| 6 | API bajo `/api/v1` | Implementado en todos los controladores |
| 7 | Configuración base de Spring Security | `SecurityConfig` stateless, CORS, CSRF off, 401/403 en `ProblemDetail` |
| 8 | Autenticación JWT | `JwtService` (HS256), login y validación de issuer/expiración |
| 9 | Entidad `Institution` | Implementada con configuración editable |
| 10 | Entidad `AppUser` | Implementada, pertenece a una institución (salvo plataforma) |
| 11 | Entidades de roles y permisos | `Role`, `Permission`, `app_user_role`, `role_permission` |
| 12 | `PLATFORM_ADMIN` | Rol y permisos globales; sin institución |
| 13 | `INSTITUTION_ADMIN` | Rol con lectura/edición de su institución y gestión de usuarios |
| 14 | Creación y edición de instituciones | `POST /institutions`, `PUT /institutions/{id}`, `PUT /institutions/me` |
| 15 | Configuración institucional editable | Nombre legal/comercial, RUC, contacto, logo/colores, país/ciudad/zona/idioma, moneda, IVA y módulos |
| 16 | Contexto institucional desde la sesión | Claim `inst` del JWT + `CurrentUser.requiredInstitutionId()` |
| 17 | Aislamiento entre instituciones | Verificación en servicio + pruebas de acceso cruzado |
| 18 | Auditoría básica | `audit_event` en alta/edición de instituciones y alta de usuarios |
| 19 | Errores uniformes | `ApiExceptionHandler` con RFC 9457 |
| 20 | DTOs, validaciones, paginación, OpenAPI | Implementado (springdoc 3.1.1, compatible con Boot 4.1.1) |

**No implementado en esta fase (por alcance):** estudiantes, representantes, matrículas, obligaciones, pagos, egresos, comunicaciones y reportes.

---

## 3. Migraciones Flyway

- `V1__initial_schema.sql`
  - `institution`, `institution_module`, `app_user`, `role`, `permission`, `role_permission`, `app_user_role`, `audit_event`.
  - Índices: `uk_institution_tax_id` (parcial), `uk_app_user_email`, `ix_app_user_institution`, `ix_audit_institution`, `ix_audit_entity`.
- `V2__seed_roles_and_permissions.sql`
  - Roles: `PLATFORM_ADMIN`, `INSTITUTION_ADMIN`, `SECRETARY`, `TREASURY`, `DIRECTOR`.
  - Permisos: `PLATFORM_INSTITUTION_MANAGE`, `INSTITUTION_READ`, `INSTITUTION_WRITE`, `USER_READ`, `USER_WRITE`.

---

## 4. Endpoints disponibles

| Método | Ruta | Autorización |
|---|---|---|
| POST | `/api/v1/auth/login` | pública |
| GET | `/api/v1/auth/me` | autenticado |
| GET | `/api/v1/institutions?search=&page=&size=` | `PLATFORM_INSTITUTION_MANAGE` |
| POST | `/api/v1/institutions` | `PLATFORM_INSTITUTION_MANAGE` |
| GET | `/api/v1/institutions/me` | `INSTITUTION_READ` |
| PUT | `/api/v1/institutions/me` | `INSTITUTION_WRITE` |
| GET | `/api/v1/institutions/{id}` | `INSTITUTION_READ` + aislamiento |
| PUT | `/api/v1/institutions/{id}` | `PLATFORM_INSTITUTION_MANAGE` |
| GET | `/api/v1/users` | `USER_READ` |
| POST | `/api/v1/users` | `USER_WRITE` |

- Documentación: `/v3/api-docs` y `/swagger-ui.html` (solo en `dev`; deshabilitado en `prod` por defecto).
- Errores: `application/problem+json` con `title`, `status`, `detail`, `code` y `errors`.

---

## 5. Seguridad y aislamiento

- JWT firmado con HS256; `JWT_SECRET` obligatorio de al menos 32 bytes (falla al arrancar si no cumple).
- Contraseñas con BCrypt; nunca se registran en logs.
- Autoridades del token: `ROLE_<código>` + códigos de permiso.
- `@PreAuthorize` en controladores y verificación adicional de institución en `InstitutionService`.
- `GET /institutions/{id}`: un usuario institucional solo puede consultar su propia institución.
- `PUT /institutions/{id}`: solo `PLATFORM_ADMIN`; el administrador institucional usa `/me`.
- Listado de usuarios siempre filtrado por la institución del token.
- No se acepta `institutionId` desde el cliente en ningún endpoint.
- CORS limitado a `http://localhost:4200` por defecto (`CORS_ALLOWED_ORIGINS`).

---

## 6. Frontend implementado

- `HttpClient` con `jwtInterceptor` y `errorInterceptor`.
- `AuthService` con señales de token/usuario, persistencia en `localStorage` y cierre de sesión.
- Guards: `authGuard` y `roleGuard`.
- Rutas:
  - `/login` (layout guest, conectado al backend)
  - `/dashboard`
  - `/platform/institutions` (solo `PLATFORM_ADMIN`)
  - `/institution/settings` (solo `INSTITUTION_ADMIN`)
- Menú lateral construido según roles; se retiraron los ítems demo (Dashboard demo, Typography, Colors, Sample Page, Register).
- Header con nombre, rol, institución y cierre de sesión.
- Se retiró el panel flotante de personalización de la plantilla y se reemplazó el logo Berry por un logo propio (`assets/images/akira-logo.svg`).
- Se conservaron estilos, componentes y estructura de Berry.

---

## 7. Usuarios de prueba

Creados solo en perfil `dev` con `APP_SEED_ENABLED=true`:

| Correo | Rol | Contraseña |
|---|---|---|
| `admin@akira.local` | `PLATFORM_ADMIN` | `APP_SEED_ADMIN_PASSWORD` (valor por defecto solo dev) |
| `admin@demo.local` | `INSTITUTION_ADMIN` | `APP_SEED_DEMO_PASSWORD` (valor por defecto solo dev) |

Durante la verificación manual se creó además, mediante la interfaz, la institución `Unidad Educativa Norte` y su administradora `rectora@uen.test`. Esos datos viven únicamente en el esquema local `akira_dev`.

**No se revelan contraseñas de producción porque no existen;** los valores por defecto están en `application-dev.properties` y deben cambiarse o desactivarse.

---

## 8. Archivos creados y modificados

### Backend — modificados
- `pom.xml` (Flyway PostgreSQL, resource server JWT, JOSE, springdoc).
- `src/main/resources/application.properties` (perfiles, Base de datos, Flyway, JWT, CORS, OpenAPI).
- `src/test/java/com/akira/educacion/EducacionApplicationTests.java` (perfil test + Flyway limpio).
- `.gitignore` (excluye `.env`).

### Backend — creados
- `.env.example`, `README.md`.
- `application-dev.properties`, `application-test.properties`, `application-prod.properties`.
- `db/migration/V1__initial_schema.sql`, `V2__seed_roles_and_permissions.sql`.
- `common/domain/AuditableEntity.java`
- `common/api/{BadRequestException,ConflictException,NotFoundException,PageResponse,ApiExceptionHandler}.java`
- `common/config/{JwtProperties,OpenApiConfig}.java`
- `common/security/{CurrentUser,JwtService,SecurityConfig}.java`
- `audit/{AuditEvent,AuditEventRepository,AuditService}.java`
- `identity/domain/{AppUser,Role,Permission,RoleCodes,PermissionCodes}.java`
- `identity/repository/{AppUserRepository,RoleRepository}.java`
- `identity/api/{AuthController,UserController,LoginRequest,LoginResponse,UserProfile,CreateUserRequest,UserResponse}.java`
- `identity/service/{AuthService,UserService}.java`
- `institution/domain/{Institution,InstitutionModuleCode}.java`
- `institution/repository/InstitutionRepository.java`
- `institution/api/{InstitutionController,CreateInstitutionRequest,UpdateInstitutionRequest,InstitutionResponse}.java`
- `institution/service/InstitutionService.java`
- `config/DevDataSeeder.java`
- Pruebas: `support/{AbstractIntegrationTest,TestFlywayConfig}.java`, `security/{AuthIntegrationTest,InstitutionAccessIntegrationTest}.java`, `institution/InstitutionManagementIntegrationTest.java`.

### Frontend — modificados
- `src/main.ts`, `src/environments/environment.ts`, `src/environments/environment.prod.ts`.
- `src/app/app-routing.module.ts`.
- Login: `login.component.ts` / `.html`.
- Layout: `admin.component.ts/.html`, `nav-right`, `nav-left`, `nav-logo`, `navigation.component.html`, `navigation.ts`, `nav-content`, `breadcrumbs`.
- `README.md`.

### Frontend — creados
- `src/app/core/models/auth.models.ts`
- `src/app/core/services/{auth.service,institution-api.service}.ts`
- `src/app/core/interceptors/{jwt,error}.interceptor.ts`
- `src/app/core/guards/{auth,role}.guard.ts`
- `src/app/features/dashboard/*`
- `src/app/features/platform/institutions/*`
- `src/app/features/institution/settings/*`
- `src/assets/images/akira-logo.svg`

---

## 9. Comandos ejecutados y resultados reales

| Comando | Resultado |
|---|---|
| `./mvnw -B clean compile` | **BUILD SUCCESS** |
| `env DB_URL=jdbc:postgresql://localhost:5432/db_red_new DB_USER=usr_app_red_new DB_PASSWORD=*** DB_SCHEMA=akira_test ./mvnw -B clean test` | **22 pruebas, 0 fallos, BUILD SUCCESS** |
| `env DB_URL=... DB_SCHEMA=akira_dev ./mvnw spring-boot:run` | **Arrancó** en 3.8 s; Flyway aplicó V1 y V2; seed dev ejecutado |
| `curl /api/v1/auth/login` (platform y demo) | **200** con JWT |
| `curl /api/v1/auth/me`, `/institutions/me`, `PUT /institutions/me` | **200**; IVA persistido |
| `curl /api/v1/institutions` como `INSTITUTION_ADMIN` | **403** (alcance global denegado) |
| `curl /v3/api-docs` | **200**; `bearerAuth` presente; 6 rutas documentadas |
| `npm run build:dev` | **OK** |
| `npm run build` (producción) | **OK** (inicial 1.15 MB, 188.86 kB transferidos) |
| `npm run lint` | **OK** — "All files pass linting" |
| `npm start -- --port 4200` | **OK**; login, dashboard, configuración, lista y alta de institución verificados en navegador |

---

## 10. Pruebas obligatorias (mapeo)

| # | Prueba requerida | Test implementado | Resultado |
|---|---|---|---|
| 1 | Login exitoso | `AuthIntegrationTest.loginExitosoDevuelveTokenYPerfil` | Pasa |
| 2 | Login fallido | `AuthIntegrationTest.loginFallidoDevuelveProblemDetail` | Pasa |
| 3 | Contraseña no almacenada en texto plano | `AuthIntegrationTest.contrasenaSeAlmacenaConHash` | Pasa |
| 4 | Acceso autorizado `INSTITUTION_ADMIN` | `InstitutionAccessIntegrationTest.institutionAdminAccedeASuInstitucion` | Pasa |
| 5 | Rechazo entre instituciones | `...institutionAdminNoPuedeConsultarOtraInstitucion` (+ edición y listados) | Pasa |
| 6 | Acceso global controlado `PLATFORM_ADMIN` | `...platformAdminAccedeAlcanceGlobal` | Pasa |
| 7 | Creación y edición de institución | `InstitutionManagementIntegrationTest` (crear con admin, editar propia/global) | Pasa |
| 8 | Configuración de IVA | `...configuracionDeIvaSePersiste`, `...ivaHabilitadoSinTasaEsRechazado` | Pasa |
| 9 | Auditoría de cambios | `...auditoriaRegistraCreacionYEdicion` | Pasa |
| 10 | JWT inválido/expirado | `AuthIntegrationTest.tokenInvalidoEsRechazado`, `tokenExpiradoEsRechazado` | Pasa |

Además: `contextLoads`, perfil sin token, listados de usuarios por institución y conflicto de RUC duplicado.

---

## 11. Problemas encontrados y solución

1. **Flyway no reconocía PostgreSQL 18/17** (`Unsupported Database`): faltaba `flyway-database-postgresql`. Se agregó la dependencia.
2. **Dependencia duplicada en `pom.xml`**: existía una segunda declaración de `flyway-database-postgresql`; se eliminó.
3. **Base externa y `ddl-auto=update`**: se sustituyeron por variables de entorno y `validate`; no se arrancó nunca contra la base externa.
4. **Esquema no visible para SQL nativo**: `JdbcTemplate` no encontraba las tablas porque el `search_path` no incluía el esquema. Se configuró `spring.datasource.hikari.connection-init-sql=SET search_path TO ${DB_SCHEMA}`.
5. **Error `lower(bytea)`** en la búsqueda de instituciones: la consulta con `:search is null` no tipaba el parámetro en PostgreSQL. Se separó en `findAll` y una consulta con parámetro obligatorio.
6. **Compilación incremental engañosa**: Maven no recompiló tras agregar `modules()` a un DTO y las pruebas fallaron con "Unresolved compilation problem". Se corrigió con `clean` y se añadió el campo que faltaba.
7. **Acentos corruptos en datos semilla** (`Institución` → `InstituciÃ³n`): `application.properties` se lee como ISO-8859-1. Se usó el escape `\u00f3` y se recreó el esquema de desarrollo.
8. **Docker no disponible** (daemon detenido y sin plugin `compose`): las pruebas usan un esquema PostgreSQL aislado en la base local; las dependencias de Testcontainers quedan preparadas para cuando Docker esté disponible.
9. **El rol local de PostgreSQL no puede crear bases** (`CREATEDB` denegado, sin `sudo` no interactivo): se usaron esquemas dedicados en la base local.

---

## 12. Limitaciones y pendientes

- **Base de datos:** no se pudo crear una base dedicada `akira_educacion` por permisos del rol local. Se usó `db_red_new` (local) con esquemas `akira_dev` / `akira_test`. Para el entorno definitivo, crear la base y el usuario indicados en `.env.example`; solo hay que cambiar variables de entorno.
- **Gestión de usuarios parcial:** existen alta y listado; no hay edición, desactivación ni restablecimiento de contraseña (no exigido explícitamente en Fase 1).
- **Sin refresh token, bloqueo por intentos fallidos ni recuperación de contraseña.**
- **Módulos habilitados:** se almacenan y muestran, pero aún no condicionan endpoints porque los módulos de fases posteriores no existen.
- **Frontend sin pruebas automatizadas:** la plantilla no traía runner de pruebas; queda pendiente definirlo.
- **Docker Compose** no se agregó ni verificó por falta de Docker operativo.
- **Auditoría:** se registra alta/edición institucional y alta de usuarios; la consulta de auditoría por API queda para una fase posterior.
- **OpenAPI:** disponible y con esquema Bearer; en producción está deshabilitado por defecto.

---

## 13. Uso de bases de datos (confirmación)

- **No se utilizó la base externa compartida** (`172.16.1.72:5434`).
- Todo el desarrollo y las pruebas se ejecutaron contra **PostgreSQL local en `localhost:5432`**.
- El esquema `akira_test` se limpia y migra en cada ejecución de pruebas; es independiente del esquema de desarrollo `akira_dev`.
- No se ejecutó `ddl-auto=update` en ningún perfil.
