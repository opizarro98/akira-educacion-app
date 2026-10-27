# Operación inicial — Akira Educación

Guía para el equipo que administra el sistema después del despliegue.

## 1. Primer acceso

1. Confirmar que `/actuator/health` responde `UP`.
2. Iniciar sesión con el `PLATFORM_ADMIN` creado en el arranque (ver `docs/despliegue.md`).
3. Cambiar la contraseña inicial en el menú de usuario o con
   `PUT /api/v1/users/me/password`.
4. Crear las instituciones desde **Instituciones**, indicando administrador, zona horaria,
   moneda e IVA si aplica.

## 2. Alta de una institución

1. **Instituciones → Nueva**: datos legales, zona horaria (`America/Guayaquil` por defecto),
   moneda, configuración de IVA y módulos.
2. Entregar al administrador institucional su usuario y contraseña temporal por un canal seguro.
3. El administrador institucional debe cambiar la contraseña en el primer ingreso.

## 3. Configuración institucional

Con el rol `INSTITUTION_ADMIN`:

1. **Mi institución**: datos, logo, colores y módulos.
2. **Usuarios**: crear secretaría, tesorería y dirección; asignar solo los roles necesarios.
3. **Catálogo**: niveles, períodos, servicios, tarifas y planes.
4. **Cobros → Conceptos**: conceptos y configuración de IVA cuando corresponda.

## 4. Operación diaria

| Tarea | Pantalla | Rol habitual |
|---|---|---|
| Registrar estudiantes | Estudiantes | Secretaría |
| Registrar representantes y vínculos | Expediente del estudiante | Secretaría |
| Matricular y confirmar | Matrículas | Secretaría |
| Generar obligación inicial | Matrícula confirmada → Generar cobro | Secretaría/Tesorería |
| Registrar y confirmar pagos | Pagos | Tesorería |
| Aplicar pagos y emitir recibo | Detalle del pago | Tesorería |
| Registrar y confirmar egresos | Egresos | Tesorería |
| Revisar caja y reportes | Caja / Reportes | Tesorería / Dirección |
| Enviar comunicaciones asistidas | Comunicaciones | Secretaría / Tesorería |
| Importar estudiantes | Importar estudiantes | Secretaría |

### Comunicaciones

- El sistema **no envía mensajes**: abre WhatsApp con un enlace `wa.me`.
- El estado `OPENED` significa que se abrió el enlace; **no confirma envío ni entrega**.
- La información financiera solo se incluye si el usuario la escribe y confirma la vista previa.

### Importación de estudiantes

1. Descargar la plantilla de `docs/ejemplos/plantilla-estudiantes.xlsx`.
2. Cargar el archivo y revisar válidas, errores y duplicados.
3. Solo después de revisar, confirmar la importación.
4. Si se permite actualizar existentes, hacerlo de forma explícita: queda auditado con valores
   anteriores y nuevos.
5. Revisar el reporte final; las filas con error no se importan.

## 5. PLATFORM_ADMIN

- Debe seleccionar una institución en la barra superior antes de operar en pantallas
  institucionales.
- Cada acceso global queda auditado (`PLATFORM_GLOBAL_ACCESS`).
- El selector es una ayuda de navegación; el backend sigue validando permisos.

## 6. Monitoreo mínimo

- Healthcheck: `GET /actuator/health`.
- Errores 5xx en logs del backend (sin datos sensibles).
- Crecimiento de la base y duración de respaldos.
- Espacio en disco del volumen de PostgreSQL.

## 7. Incidentes frecuentes

| Síntoma | Revisión |
|---|---|
| 401 al navegar | Token expirado o usuario desactivado; volver a iniciar sesión |
| 403 en una acción | El rol no tiene el permiso; revisar con el administrador |
| 400 al importar | Extensión distinta de `.xlsx`, tamaño > 5 MB, columnas faltantes |
| Pantalla vacía para PLATFORM_ADMIN | Falta seleccionar institución |
| Frontend sin API | Backend caído, CORS o proxy nginx mal configurado |

## 8. Cierre de período

1. Conciliar pagos confirmados contra caja.
2. Revisar obligaciones pendientes y anulaciones.
3. Generar reportes del período y archivarlos fuera del sistema si se requiere.
4. Tomar respaldo antes de operaciones masivas.
