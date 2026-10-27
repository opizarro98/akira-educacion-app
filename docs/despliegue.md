# Guía de despliegue — Akira Educación

> Estado verificado en esta fase: los archivos de despliegue existen, pero **Compose no se
> ejecutó** porque el entorno de trabajo no tiene el plugin/binario de Docker Compose. La
> compilación de backend y frontend sí se ejecutó y pasó.

## 1. Requisitos

- Docker Engine 24+ y Docker Compose v2 (`docker compose`), o despliegue manual.
- PostgreSQL 17+ (el proyecto se probó contra PostgreSQL 17 y 18).
- Java 25 si se despliega el JAR fuera de Docker.
- Node 22 solo para compilar el frontend fuera de Docker.

## 2. Variables de entorno

Copie `.env.example` a `.env` y cambie todos los valores. Nunca versione `.env`.

| Variable | Obligatoria | Descripción |
|---|---|---|
| `POSTGRES_DB` | Sí | Base de datos |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Sí | Credenciales de base de datos |
| `DB_SCHEMA` | Sí | Esquema propietario de Flyway (por defecto `akira`) |
| `JWT_SECRET` | Sí | HS256, mínimo 32 bytes. Genere con `openssl rand -base64 48` |
| `JWT_ISSUER` | No | Por defecto `akira-educacion` |
| `JWT_TTL` | No | Duración del token (ISO-8601, por defecto `PT1H`) |
| `CORS_ALLOWED_ORIGINS` | Sí en despliegue separado | Origen exacto del frontend, separado por comas |
| `OPENAPI_ENABLED` | No | `false` en producción |
| `FRONTEND_PORT` | No | Puerto publicado del frontend (por defecto 8081) |

## 3. Despliegue con Compose

```bash
cp .env.example .env
# editar .env con valores reales
docker compose up -d --build
docker compose ps
curl -fsS http://localhost:8081/actuator/health
```

- `db`: volumen persistente `db_data`, healthcheck `pg_isready`.
- `backend`: espera a `db` saludable, healthcheck `/actuator/health`, corre las migraciones
  Flyway al arrancar.
- `frontend`: nginx sirve el SPA y hace proxy de `/api/` y `/actuator/` al backend.
- Detener: `docker compose down` (conserva `db_data`).
- Destruir datos: `docker compose down -v` (**irreversible**).

Si el entorno no tiene Compose, instale el plugin (`docker-compose-plugin`) y valide con
`docker compose config` antes de levantar.

## 4. Despliegue manual

### Backend

```bash
cd app/backend
./mvnw -B clean package -DskipTests
SPRING_PROFILES_ACTIVE=prod \
DB_URL=jdbc:postgresql://HOST:5432/DB \
DB_USER=... DB_PASSWORD=... DB_SCHEMA=akira \
JWT_SECRET='...' \
java -jar target/educacion-0.0.1-SNAPSHOT.jar
```

El backend escucha en `SERVER_PORT` (8080 por defecto) y expone `GET /actuator/health`.

### Frontend

```bash
cd app/frontend
npm ci
npm run build
```

Publique `dist/` con nginx y replique `nginx.conf`: fallback a `index.html` y proxy de `/api/`
hacia el backend. El build de producción usa `environment.prod.ts` con `apiUrl: '/api/v1'`, por
lo que el frontend y la API deben compartir origen (o configurar CORS).

## 5. Primer arranque y administrador de plataforma

En producción `app.seed.*` está desactivado y no existe auto-registro. Para el primer
administrador, ejecute **una sola vez**:

```bash
SPRING_PROFILES_ACTIVE=dev \
APP_SEED_ENABLED=true \
APP_SEED_ADMIN_EMAIL='admin@su-dominio' \
APP_SEED_ADMIN_PASSWORD='ClaveInicialSegura123!' \
APP_SEED_DEMO=false \
DB_URL=... DB_USER=... DB_PASSWORD=... DB_SCHEMA=akira JWT_SECRET='...' \
java -jar target/educacion-0.0.1-SNAPSHOT.jar
```

Detenga el proceso, reinicie con `SPRING_PROFILES_ACTIVE=prod` y cambie la contraseña desde
`PUT /api/v1/users/me/password` con el usuario recién creado. Verifique que `APP_SEED_ENABLED`
no quede activo.

## 6. Migraciones y actualizaciones

1. Respalde la base antes de actualizar (ver `docs/backups.md`).
2. Despliegue la nueva versión; Flyway aplica `V13__phase5b_financial_permissions.sql` y las
   migraciones pendientes.
3. Verifique `flyway_schema_history` y `/actuator/health`.
4. Si falla el arranque, restaure el respaldo y vuelva a la imagen anterior.

No edite migraciones ya aplicadas: agregue una nueva.

## 7. Endurecimiento mínimo

- TLS terminado en un proxy inverso (no se incluye en compose).
- PostgreSQL no publicado al exterior; solo red interna.
- `JWT_SECRET` distinto por entorno y rotación planificada.
- `OPENAPI_ENABLED=false`.
- Usuario de base de datos con permisos solo sobre su base y esquema.
- Copias de seguridad cifradas fuera del servidor.
- Revisar logs sin datos personales completos: la aplicación enmascara identificaciones en
  auditoría de importación y nunca registra contraseñas.

## 8. Problemas conocidos

- **`failed to add the host (veth...) <=> sandbox (veth...) pair interfaces: operation not
  supported`**: el daemon no puede crear redes bridge. En el host de prueba ocurría porque el
  kernel en ejecución (`7.3.0-2-cachyos`) no tenía módulos instalados (solo `7.3.0-4-cachyos`).
  Solución: reiniciar en el kernel con módulos instalados o instalar los módulos del kernel
  activo. Mientras tanto, `--network host` funciona.
- El frontend compilado apunta a `/api/v1`; si se sirve en otro origen, ajuste CORS.
- Healthcheck del backend depende de Actuator; no lo deshabilite.
- Los healthchecks usan `127.0.0.1` a propósito: `localhost` puede resolverse a IPv6 y fallar
  aunque el servicio escuche en IPv4.
