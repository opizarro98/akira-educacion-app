# Akira Educación

Sistema de gestión escolar multiinstitución. Permite administrar instituciones, usuarios y roles,
estudiantes, representantes, catálogo académico, matrículas, obligaciones de cobro, pagos, recibos
internos, egresos, caja, reportes financieros, comunicaciones asistidas e importación de estudiantes
desde Excel.

El repositorio es un monorepo con dos submódulos Git:

- `app/backend`: API REST con Spring Boot y PostgreSQL.
- `app/frontend`: aplicación web con Angular y la plantilla Berry.

## Cómo funciona

```text
Navegador (http://localhost:4200)
        │
        │  HTTP + JWT
        ▼
API REST (http://localhost:8080/api/v1)
        │
        │  JPA / Flyway
        ▼
PostgreSQL (localhost:5432)
```

- El frontend consume la API en `http://localhost:8080/api/v1`.
- El login devuelve un token JWT que el frontend guarda y envía en cada petición.
- Cada usuario institucional solo puede operar con datos de su propia institución.
- `PLATFORM_ADMIN` no pertenece a una institución: debe indicar explícitamente sobre cuál operar.
- Flyway crea y actualiza el esquema de base de datos automáticamente al arrancar el backend.
- Los datos de demostración se crean solo con el perfil `dev`.

### Flujo funcional principal

1. Configurar la institución (datos generales e IVA).
2. Crear niveles educativos, períodos, servicios, tarifas y planes.
3. Registrar estudiantes y, opcionalmente, representantes.
4. Crear una matrícula y confirmarla. Al confirmar se congelan el precio acordado y la tasa de IVA.
5. Generar el cobro inicial de la matrícula o crear obligaciones manuales.
6. Registrar un pago:
   - Efectivo: se confirma de inmediato si el usuario tiene permiso de verificación.
   - Transferencia: queda pendiente de verificación.
7. Aplicar el pago confirmado a una o varias obligaciones.
8. Consultar o imprimir el recibo interno generado.
9. Si hay un error, revertir aplicaciones y anular el pago con motivo.
10. Registrar egresos por categoría, confirmarlos para generar la salida de caja y anularlos con motivo si es necesario.
11. Consultar la caja, los reportes financieros y el dashboard institucional.
12. Preparar una comunicación asistida: elegir estudiante, representante autorizado y plantilla, revisar el mensaje y abrir el enlace `wa.me`. El sistema no confirma el envío.
13. Importar estudiantes desde Excel en tres pasos: validación, vista previa con errores y duplicados, y confirmación explícita.

### Roles

| Rol | Alcance |
|---|---|
| `PLATFORM_ADMIN` | Administra instituciones de toda la plataforma. No pertenece a una institución. |
| `INSTITUTION_ADMIN` | Administración completa de su institución. |
| `SECRETARY` | Estudiantes, representantes, matrículas, comunicaciones y consulta financiera. Puede previsualizar y confirmar importaciones de estudiantes. |
| `TREASURY` | Operación financiera: cobros, conceptos, pagos, aplicaciones, anulaciones, recibos, egresos y caja. Puede preparar comunicaciones y consultar importaciones. |
| `DIRECTOR` | Consulta académica y financiera, comunicaciones e importaciones, sin modificar datos. |

## Requisitos

| Herramienta | Versión verificada | Nota |
|---|---|---|
| Java JDK | 25 | El backend está compilado para Java 25. |
| Node.js | 24.22.0 | El frontend incluye `.nvmrc`. |
| npm | 11 | Se instala con Node. |
| PostgreSQL | 16 o superior | Verificado con PostgreSQL 18.6. |
| Git | Cualquier versión reciente | Necesario para los submódulos. |

No hace falta instalar Maven: el backend incluye `./mvnw`.

Puertos necesarios:

- `4200`: frontend.
- `8080`: backend. El frontend está configurado para este puerto.
- `5432`: PostgreSQL.

## Inicio rápido

Sigue los pasos en orden. Necesitarás **dos terminales** abiertas al final: una para el backend y
otra para el frontend.

### 1. Descargar el proyecto

```sh
git clone --recurse-submodules https://github.com/opizarro98/akira-educacion-app.git
cd akira-educacion-app
```

Si ya lo descargaste sin submódulos y `app/backend` o `app/frontend` están vacíos:

```sh
git submodule update --init --recursive
```

### 2. Preparar PostgreSQL

Elige **una** de las dos opciones.

#### Opción A: PostgreSQL con Docker

Requiere Docker instalado y su daemon en ejecución. Compruébalo con:

```sh
docker info
```

Si ese comando falla, usa la opción B.

```sh
docker run -d \
  --name akira-postgres \
  -e POSTGRES_USER=akira_app \
  -e POSTGRES_PASSWORD=akira_app \
  -e POSTGRES_DB=akira_educacion \
  -p 5432:5432 \
  -v akira_pgdata:/var/lib/postgresql/data \
  postgres:17
```

En arranques posteriores:

```sh
docker start akira-postgres
```

Para detenerlo:

```sh
docker stop akira-postgres
```

#### Opción B: PostgreSQL instalado en el equipo

**Ubuntu / Debian:**

```sh
sudo apt update
sudo apt install -y postgresql
sudo systemctl enable --now postgresql
```

**macOS con Homebrew:**

```sh
brew install postgresql@18
brew services start postgresql@18
```

**Windows:** instala PostgreSQL desde el instalador oficial y abre **SQL Shell (psql)**.

Después crea el usuario y la base. Ejecuta estos comandos como superusuario de PostgreSQL.
Si el rol `akira_app` o la base `akira_educacion` ya existen, omite el comando correspondiente.

En Ubuntu / Debian:

```sh
sudo -u postgres psql -c "CREATE ROLE akira_app LOGIN PASSWORD 'akira_app';"
sudo -u postgres psql -c "CREATE DATABASE akira_educacion OWNER akira_app;"
```

En macOS:

```sh
psql postgres -c "CREATE ROLE akira_app LOGIN PASSWORD 'akira_app';"
psql postgres -c "CREATE DATABASE akira_educacion OWNER akira_app;"
```

En Windows, desde SQL Shell:

```sql
CREATE ROLE akira_app LOGIN PASSWORD 'akira_app';
CREATE DATABASE akira_educacion OWNER akira_app;
```

#### Verificar la base de datos

```sh
PGPASSWORD=akira_app psql -h localhost -U akira_app -d akira_educacion -c "SELECT current_database(), current_user;"
```

Debe mostrar `akira_educacion` y `akira_app`.

El usuario es dueño de la base, por lo que Flyway puede crear el esquema `akira_dev`
automáticamente en el primer arranque.

### 3. Arrancar el backend

Abre una terminal en la raíz del proyecto y ejecuta:

```sh
chmod +x app/backend/mvnw
cd app/backend
env DB_URL=jdbc:postgresql://localhost:5432/akira_educacion \
    DB_USER=akira_app \
    DB_PASSWORD=akira_app \
    DB_SCHEMA=akira_dev \
    JWT_SECRET=dev-only-secret-change-me-0123456789abcdef \
    ./mvnw spring-boot:run
```

Espera hasta ver mensajes similares a:

```text
Successfully applied ... migrations
Tomcat started on port 8080
Started EducacionApplication
```

En el primer arranque se crean todas las tablas y los usuarios de demostración.

Comprueba que la API responde:

```sh
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/v3/api-docs
```

Debe responder `200`.

- Swagger UI: <http://localhost:8080/swagger-ui.html>
- OpenAPI JSON: <http://localhost:8080/v3/api-docs>

**Windows (PowerShell):**

```powershell
cd app\backend
$env:DB_URL="jdbc:postgresql://localhost:5432/akira_educacion"
$env:DB_USER="akira_app"
$env:DB_PASSWORD="akira_app"
$env:DB_SCHEMA="akira_dev"
$env:JWT_SECRET="dev-only-secret-change-me-0123456789abcdef"
.\mvnw.cmd spring-boot:run
```

Deja esta terminal abierta mientras uses el sistema. Para detener el backend pulsa `Ctrl+C`.

### 4. Arrancar el frontend

Abre una **segunda terminal** en la raíz del proyecto:

```sh
cd app/frontend
npm ci
npm start
```

Si usas NVM y quieres fijar la versión de Node del proyecto:

```sh
cd app/frontend
nvm install
nvm use
npm ci
npm start
```

Cuando aparezca `Local: http://localhost:4200`, abre:

<http://localhost:4200>

Deja esta terminal abierta. Para detener el frontend pulsa `Ctrl+C`.

### 5. Iniciar sesión

Usuarios creados automáticamente en desarrollo:

| Correo | Contraseña | Rol | Uso |
|---|---|---|---|
| `admin@demo.local` | `Demo1234!` | `INSTITUTION_ADMIN` | Administrar la institución de demostración. |
| `admin@akira.local` | `Admin1234!` | `PLATFORM_ADMIN` | Crear y administrar instituciones. |

Para recorrer el flujo completo, entra con **`admin@demo.local`**.

> Los usuarios de demostración solo se crean con el perfil `dev` y `APP_SEED_ENABLED=true`.
> No se crean en producción.

## Primer uso del sistema

Con el usuario `admin@demo.local`:

1. **Mi institución**: revisa los datos y configura el IVA si corresponde.
2. **Catálogo**: crea al menos un nivel educativo, un servicio y su tarifa.
3. **Estudiantes**: registra un estudiante.
4. **Matrículas**: crea una matrícula y pulsa **Confirmar matrícula**.
5. **Cobros**:
   - Desde la matrícula confirmada, usa **Generar cobro inicial**.
   - Para obligaciones manuales, primero crea conceptos en **Cobros → Conceptos**.
6. **Pagos**:
   - Registra un pago en efectivo (se confirma automáticamente si tienes permiso).
   - Registra una transferencia y confírmala desde el detalle del pago.
7. **Aplicar pago**: en el detalle del pago, selecciona una o varias obligaciones e indica los importes.
8. **Recibos**: el sistema genera un recibo interno al confirmar el pago. Puedes consultarlo e imprimirlo.

Orden importante:

- Un concepto debe existir antes de crear una obligación manual.
- Una matrícula debe estar confirmada antes de generar su cobro inicial.
- Un pago debe estar confirmado antes de aplicarse.
- Para anular un pago, primero revierte sus aplicaciones.

## Configuración

El backend toma estos valores del entorno:

| Variable | Valor por defecto en desarrollo | Descripción |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/akira_educacion` | Cadena JDBC de PostgreSQL. |
| `DB_USER` | `akira_app` | Usuario de base de datos. |
| `DB_PASSWORD` | `akira_app` | Contraseña de base de datos. |
| `DB_SCHEMA` | `akira_dev` en el perfil dev | Esquema usado por Flyway e Hibernate. |
| `DB_POOL_SIZE` | `5` | Conexiones del pool. |
| `JWT_SECRET` | Secreto solo de desarrollo | Debe tener al menos 32 bytes. |
| `JWT_TTL` | `PT1H` | Vigencia del token. |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:4200` | Orígenes permitidos. |
| `SERVER_PORT` | `8080` | Puerto del backend. |

Datos de demostración:

| Variable | Valor por defecto |
|---|---|
| `APP_SEED_ENABLED` | `true` (solo perfil `dev`) |
| `APP_SEED_ADMIN_EMAIL` | `admin@akira.local` |
| `APP_SEED_ADMIN_PASSWORD` | `Admin1234!` |
| `APP_SEED_DEMO` | `true` |
| `APP_SEED_DEMO_EMAIL` | `admin@demo.local` |
| `APP_SEED_DEMO_PASSWORD` | `Demo1234!` |

Si cambias el puerto del backend, también debes actualizar `apiUrl` en
`app/frontend/src/environments/environment.ts`.

## Estructura del proyecto

```text
akira-educacion-app/
├── app/
│   ├── backend/                 # Spring Boot + PostgreSQL
│   │   ├── src/main/java/com/akira/educacion/
│   │   │   ├── audit/           # auditoría transversal
│   │   │   ├── billing/         # cobros, pagos, aplicaciones y recibos
│   │   │   ├── catalog/         # niveles, períodos, servicios, planes y tarifas
│   │   │   ├── common/          # errores, paginación y seguridad
│   │   │   ├── enrollment/      # matrículas
│   │   │   ├── identity/        # usuarios, roles y permisos
│   │   │   ├── institution/     # instituciones y aislamiento
│   │   │   ├── representatives/ # representantes
│   │   │   └── students/        # estudiantes
│   │   └── src/main/resources/db/migration/   # migraciones Flyway V1..V8
│   └── frontend/                # Angular + Bootstrap + plantilla Berry
│       └── src/app/features/    # pantallas por módulo
├── docs/                        # documentación por fase
└── README.md
```

## Pruebas

### Backend

Las pruebas usan el esquema aislado `akira_test` y lo limpian en cada ejecución.
**No apuntes `DB_SCHEMA` a un esquema con datos reales.**

```sh
cd app/backend
env DB_URL=jdbc:postgresql://localhost:5432/akira_educacion \
    DB_USER=akira_app \
    DB_PASSWORD=akira_app \
    DB_SCHEMA=akira_test \
    ./mvnw -B test
```

Resultado verificado: **77 pruebas, 0 fallos**.

### Frontend

```sh
cd app/frontend
npm run build
npm run lint
```

## Problemas frecuentes

### `permission denied: ./mvnw`

```sh
chmod +x app/backend/mvnw
```

### `invalid target release: 25` o error de compilación de Java

```sh
java -version
```

Debe ser Java 25. Configura `JAVA_HOME` con un JDK 25 y abre una terminal nueva.

### `Connection refused` al conectar a PostgreSQL

Comprueba que PostgreSQL esté activo:

```sh
pg_isready -h localhost -p 5432
```

- Instalación local en Linux: `sudo systemctl status postgresql`
- Docker: `docker ps` y `docker start akira-postgres`

### `password authentication failed for user "akira_app"`

Verifica las credenciales:

```sh
PGPASSWORD=akira_app psql -h localhost -U akira_app -d akira_educacion -c "SELECT 1;"
```

Si falla, vuelve a crear el rol y la base de datos con los comandos del paso 2.

### `Port 8080 is already in use`

```sh
lsof -i :8080
```

Cierra el proceso que ocupa el puerto. El frontend está configurado para `8080`; si cambias el
puerto del backend, actualiza `apiUrl` en el frontend.

### El frontend no conecta con la API

- Confirma que el backend esté en <http://localhost:8080/v3/api-docs>.
- Confirma que abriste el frontend en `http://localhost:4200`.
- Si usas otro puerto para el frontend, añade ese origen a `CORS_ALLOWED_ORIGINS`.

### `npm ci` falla

Comprueba la versión de Node:

```sh
node --version
```

Debe ser Node 24. Si el problema persiste:

```sh
cd app/frontend
rm -rf node_modules
npm ci
```

### Flyway detecta una migración modificada o un esquema incompatible

En desarrollo puedes reiniciar el esquema **solo si no necesitas sus datos**:

```sh
PGPASSWORD=akira_app psql -h localhost -U akira_app -d akira_educacion -c "DROP SCHEMA IF EXISTS akira_dev CASCADE;"
```

Después vuelve a arrancar el backend. Flyway recreará el esquema y las tablas.

### `app/backend` o `app/frontend` están vacíos

```sh
git submodule update --init --recursive
```

## Seguridad

- Los secretos y contraseñas por defecto son **solo para desarrollo local**.
- Antes de publicar el sistema, cambia `JWT_SECRET`, las contraseñas de base de datos y los usuarios
  de demostración, o desactiva `APP_SEED_ENABLED`.
- El perfil `prod` no ejecuta los datos de demostración.
- No guardes secretos en `app/frontend`: todo lo que llega al navegador es público.
- No edites migraciones Flyway ya aplicadas en un entorno compartido.
- Realiza copias de seguridad de PostgreSQL antes de operar con datos reales.

## Documentación

- `docs/fase-0-analisis.md`
- `docs/fase-1-implementacion.md`
- `docs/fase-2-implementacion.md`
- `docs/fase-3-implementacion.md`
- `docs/fase-3b-implementacion.md`
- `docs/fase-4-implementacion.md`
- `docs/fase-5a-implementacion.md`
- `docs/ejemplos/README.md` (columnas y reglas de importación)
- `docs/ejemplos/plantillas-comunicacion.md`
