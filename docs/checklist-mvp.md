# Checklist de aceptación del MVP — Fase 5B

Marcar solo con evidencia ejecutada. Fecha de la verificación: 2026-10-27.

## A. Seguridad y aislamiento

- [x] El backend resuelve la institución desde el token para usuarios institucionales.
- [x] `PLATFORM_ADMIN` exige `institutionId` explícito y audita `PLATFORM_GLOBAL_ACCESS`.
- [x] Un usuario de la institución A no puede leer datos de B (404).
- [x] Un usuario de la institución A no puede forzar `institutionId` de B (403).
- [x] Usuario desactivado no inicia sesión y su token deja de valer (401).
- [x] Contraseñas nunca se registran en auditoría ni en respuestas.
- [x] Importación no acepta institución desde el archivo.

## B. Permisos y roles

- [x] `EXPENSE_CREATE/UPDATE/CONFIRM/VOID` y `PAYMENT_REVERSE` existen y se aplican en backend.
- [x] `DIRECTOR` recibe 403 al crear/confirmar/anular egresos.
- [x] `SECRETARY` recibe 403 al registrar pagos o confirmar egresos.
- [x] `TREASURY` puede crear, confirmar y anular egresos.
- [x] `INSTITUTION_ADMIN` gestiona usuarios; `DIRECTOR` no.
- [x] `PLATFORM_ADMIN` gestiona usuarios solo con contexto explícito.

## C. Funcionalidad de negocio

- [x] Estudiante, representante autorizado y vínculo.
- [x] Matrícula, confirmación y obligación inicial (100.00).
- [x] Pago por transferencia, confirmación, aplicación y recibo (`REC-2026-000001`).
- [x] Egreso registrado, confirmado y reflejado en caja.
- [x] Reportes y dashboard responden.
- [x] Comunicación con enlace `wa.me` y apertura auditada.
- [x] Importación con vista previa sin persistencia, duplicados y confirmación idempotente.
- [x] Lote obsoleto no aborta la importación completa.

## D. Frontend

- [x] Build de producción (`npm run build`).
- [x] Lint (`npm run lint`).
- [x] 43 pruebas unitarias (login, guards, interceptores, contexto, estudiante, comunicación,
      `wa.me`, Excel, confirmación, errores y vacío).
- [x] Selector de institución visible para `PLATFORM_ADMIN`.
- [x] Guard impide operar sin institución seleccionada.
- [x] Pantalla de usuarios con alta, edición, roles, activación y contraseña.
- [ ] Verificación visual completa de los 20 flujos en navegador (no ejecutada; la evidencia
      E2E es a nivel API).

## E. Backend

- [x] Compila (`mvnw clean test`).
- [x] 138 pruebas, 0 fallos.
- [x] Migración V13 aplicada en esquema limpio (`akira_test`, `akira_e2e`).
- [x] Healthcheck `/actuator/health` responde `UP`.

## F. Despliegue

- [x] `compose.yaml`, Dockerfiles, `nginx.conf`, `.env.example`, volúmenes y red definidos.
- [x] `docker compose config` validado con Compose 5.6.1 y un `.env` real.
- [x] Imágenes backend y frontend construidas correctamente.
- [x] Stack levantado y verificado con red host (healthchecks `healthy`, SPA 200, login real,
      Flyway V13) como alternativa al bridge.
- [ ] `docker compose up` con red bridge en este host: bloqueado por kernel sin módulo `veth`
      (`7.3.0-2-cachyos` sin módulos instalados). Requiere reiniciar al kernel 7.3.0-4.
- [ ] TLS y dominio productivos (fuera del alcance del repositorio).

## G. Respaldo

- [x] Respaldo lógico generado y verificado (`pg_restore --list`, 278 entradas).
- [ ] Restauración completa en base separada verificada (no ejecutada: sin `CREATEDB`).
- [ ] Restauración documentada y firmada por el responsable de operaciones.

## H. Documentación

- [x] `docs/fase-5b-implementacion.md`
- [x] `docs/despliegue.md`
- [x] `docs/operacion.md`
- [x] `docs/backups.md`
- [x] `docs/checklist-mvp.md`
- [x] Script E2E reproducible `docs/ejemplos/e2e-fase-5b.sh`
- [x] README del backend con endpoints de la fase

## Pendientes antes de producción

1. Definir segregación de funciones con negocio y reasignar permisos si corresponde.
2. Ejecutar Compose en un entorno con el plugin instalado.
3. Probar restauración completa y documentar el resultado.
4. Verificar los 20 flujos con clics reales en navegador.
5. Definir política de exportación de reportes (PDF/Excel) o dejar explícito que no aplica.
6. Configurar TLS, dominio, monitoreo y alertas.
