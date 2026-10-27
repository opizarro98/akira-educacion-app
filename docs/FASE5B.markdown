# Fase 5B — Validación integral, endurecimiento y preparación de despliegue

La Fase 5A fue revisada y aprobada. Continúa sobre el repositorio existente:

- Backend: `app/backend`
- Frontend: `app/frontend`

Mantén los submódulos Git, la arquitectura modular, el aislamiento multiinstitución y la plantilla Berry.

Esta fase no debe agregar nuevos módulos de negocio importantes. Su objetivo es validar, endurecer, documentar y preparar el sistema para un despliegue controlado.

## 1. Selector de institución para PLATFORM_ADMIN

Implementa en el frontend un selector de institución para `PLATFORM_ADMIN`.

Debe:

- Cargar las instituciones disponibles.
- Permitir seleccionar una institución activa.
- Mostrar claramente la institución seleccionada.
- Aplicar el contexto a las pantallas de estudiantes, catálogo, matrículas, cobros, pagos, caja, reportes, comunicaciones e importaciones.
- Evitar acciones si no existe una institución seleccionada.
- Solicitar confirmación al cambiar de institución si hay una operación en curso.
- Mantener el contexto de forma segura durante la sesión.
- No convertir el selector del frontend en el mecanismo de seguridad principal.
- Mantener la validación final en el backend.
- Registrar los accesos globales en auditoría.

No permitas que un `institutionId` manipulado sustituya la autorización del backend.

## 2. Gestión de usuarios

Completa la administración de usuarios:

- Listado por institución.
- Crear usuario.
- Editar datos básicos.
- Activar y desactivar usuario.
- Asignar y retirar roles.
- Cambiar contraseña.
- Restablecer contraseña mediante flujo administrativo.
- Impedir que un usuario desactivado inicie sesión.
- Validar que un administrador institucional solo gestione usuarios de su institución.
- Permitir que `PLATFORM_ADMIN` gestione usuarios mediante contexto explícito y auditado.

Registra auditoría de:

- Creación.
- Edición.
- Activación.
- Desactivación.
- Cambio de roles.
- Restablecimiento de contraseña.

No mostrar ni registrar contraseñas.

## 3. Seguridad financiera

Revisa y endurece los permisos:

- Separar, si es necesario:
  - `EXPENSE_CREATE`
  - `EXPENSE_UPDATE`
  - `EXPENSE_CONFIRM`
  - `EXPENSE_VOID`
  - `PAYMENT_APPLY`
  - `PAYMENT_REVERSE`
  - `PAYMENT_VOID`
- Confirmar qué roles pueden registrar, confirmar, aplicar, revertir y anular operaciones.
- Verificar que una persona no pueda ejecutar acciones no autorizadas desde un endpoint aunque el frontend oculte el botón.
- Exigir motivo en anulaciones y reversiones.
- Confirmar que recibos, pagos, obligaciones y movimientos de caja sean inmutables históricamente.

Si el negocio todavía no ha definido segregación de funciones, documenta la decisión actual y no inventes permisos nuevos sin justificarla.

## 4. Comunicaciones

Revisar el módulo de comunicaciones:

- `OPENED` nunca significa enviado ni entregado.
- Mantener el mensaje y teléfono históricos.
- No regenerar comunicaciones históricas con plantillas actuales.
- Devolver errores de validación como 400/403/404 sin crear registros innecesarios.
- Mostrar advertencia clara antes de incluir información financiera.
- No incluir detalles financieros automáticamente.
- Registrar cada apertura del enlace `wa.me`.
- Confirmar que solo representantes autorizados puedan recibir comunicaciones.

## 5. Importación de estudiantes

Revisar el flujo de importación:

- Vista previa sin persistencia.
- Confirmación explícita.
- Idempotencia al reintentar.
- Detección de duplicados internos y existentes.
- No sobrescribir por defecto.
- La opción `allowUpdateExisting` debe requerir confirmación explícita.
- Si se permite actualizar existentes, registrar valores anteriores y nuevos en auditoría.
- No modificar matrículas, obligaciones, pagos ni datos históricos financieros.
- Mantener límites de tamaño y filas.
- Validar archivos malformados y archivos potencialmente peligrosos.
- No almacenar archivos temporales innecesariamente.
- No mostrar documentos personales completos en logs.

## 6. Pruebas frontend

Incorpora un runner de pruebas frontend compatible con Angular 22 y el proyecto actual.

Implementa pruebas para:

- Login.
- Guard de autenticación.
- Guard por rol.
- Interceptor JWT.
- Interceptor de errores.
- Selector de institución.
- Formulario de estudiante.
- Vista previa de comunicación.
- Generación del enlace `wa.me`.
- Vista previa de Excel.
- Confirmación de importación.
- Manejo de errores y estados vacíos.

No sustituyas la infraestructura existente sin documentar la razón.

## 7. Pruebas funcionales de extremo a extremo

Ejecuta y documenta una prueba manual o automatizada de estos flujos:

1. Login como `PLATFORM_ADMIN`.
2. Selección de una institución.
3. Login como `INSTITUTION_ADMIN`.
4. Crear estudiante.
5. Crear representante autorizado.
6. Crear matrícula.
7. Generar obligación.
8. Registrar y confirmar pago.
9. Aplicar pago.
10. Verificar recibo.
11. Registrar egreso.
12. Confirmar egreso.
13. Verificar caja.
14. Generar comunicación.
15. Abrir enlace `wa.me`.
16. Importar estudiantes mediante Excel.
17. Revisar duplicados.
18. Confirmar importación.
19. Consultar dashboard y reportes.
20. Verificar aislamiento usando una segunda institución.

Documenta cada resultado real. No declares éxito si no se ejecutó.

## 8. Docker y reproducibilidad

Prepara:

- `docker-compose.yml` o `compose.yaml`.
- PostgreSQL.
- Backend.
- Frontend si corresponde al flujo de despliegue.
- Healthchecks.
- Variables de entorno.
- `.env.example`.
- Volúmenes persistentes.
- Red interna.
- Instrucciones de arranque y detención.

No incluir secretos reales.

Si Docker no está disponible en el entorno, prepara los archivos y documenta que no pudieron ejecutarse. No declares Compose verificado si no se ejecutó.

## 9. Backups y recuperación

Documenta:

- Respaldo lógico de PostgreSQL.
- Frecuencia recomendada.
- Retención.
- Ubicación segura.
- Restauración en una base separada.
- Verificación de integridad.
- Procedimiento de recuperación ante fallo.
- Qué archivos y variables deben respaldarse.
- Qué datos no deben incluirse en logs o repositorios.

No afirmes que la restauración fue probada si no se ejecutó.

## 10. Reportes y exportación

Revisa los reportes financieros:

- Definir período.
- Aplicar zona horaria de la institución.
- Diferenciar devengado y cobrado.
- Excluir o incluir anulaciones explícitamente.
- Evitar sumar obligaciones como dinero recibido.
- Agregar paginación o límites para períodos grandes.
- Si se implementa PDF o Excel, proteger el acceso y documentar el formato.

Si la exportación todavía no está confirmada como requisito, documentarla como pendiente en lugar de implementarla por iniciativa propia.

## 11. Verificación de repositorios

Antes y después de los cambios:

- Revisar el repositorio principal.
- Revisar `app/backend`.
- Revisar `app/frontend`.
- Conservar cambios locales.
- Informar archivos modificados.
- No hacer commits automáticos sin informar.
- No cambiar referencias de submódulos sin revisar sus cambios.

## 12. Resultado esperado

Entregar:

- Resumen de cambios.
- Archivos creados y modificados.
- Permisos finales.
- Flujos manuales ejecutados.
- Pruebas backend ejecutadas.
- Pruebas frontend ejecutadas.
- Build de backend y frontend.
- Lint.
- Estado real de Docker.
- Estado real de backups y restauración.
- Problemas encontrados.
- Limitaciones restantes.
- Decisiones pendientes antes de producción.
- Guía de despliegue.
- Guía de operación inicial.
- Checklist de aceptación del MVP.
