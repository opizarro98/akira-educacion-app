# Fase 5A — Comunicaciones asistidas e importación de estudiantes

Implementación sobre las fases 1 a 4, manteniendo la arquitectura modular, el aislamiento
multiinstitución y la plantilla Berry.

## 1. Comunicaciones asistidas

### Modelo

- `message_template`: plantilla institucional con código opcional, nombre, cuerpo y estado.
- `communication`: instantánea de la comunicación preparada. Guarda institución, estudiante,
  representante, plantilla utilizada, teléfono, mensaje renderizado, enlace `wa.me`, estado,
  usuario creador, fechas y, si aplica, detalle financiero y motivo de fallo.

### Estados

- `DRAFT`: borrador guardado por el usuario.
- `READY`: comunicación preparada para abrir WhatsApp.
- `OPENED`: el usuario abrió el enlace `wa.me`. **No confirma envío ni entrega.**
- `FAILED`: la comunicación no pudo completarse; exige motivo.

### Validaciones

- El representante debe pertenecer a la institución.
- El vínculo `student_representative` debe tener `authorized_for_communications = true`.
- El representante debe tener un teléfono normalizable (8 a 15 dígitos).
- El estudiante debe pertenecer a la misma institución.
- La plantilla debe existir en la institución y estar activa.
- Solo se aceptan los marcadores `{{estudiante}}`, `{{representante}}`, `{{institucion}}`,
  `{{fecha}}` y `{{detalle_financiero}}`.
- La información financiera solo se incluye con `includeFinancialInfo = true` y un
  `financialNote` no vacío. La vista previa devuelve el mensaje exacto que se abrirá.

### Enlace wa.me

- Se normaliza el teléfono: se eliminan espacios, guiones y paréntesis; los números locales
  ecuatorianos de 10 dígitos que empiezan por `0` se convierten a `593...`.
- El mensaje se codifica con UTF-8 y se codifican los espacios como `%20`.
- La respuesta incluye `waLink`, `waPhone`, `messageBody` y advertencias.
- La plataforma nunca muestra “enviado”; la interfaz usa “Abierta en WhatsApp”.

### Endpoints

| Método | Ruta | Permiso |
|---|---|---|
| GET/POST | `/api/v1/communications/templates` | `MESSAGE_TEMPLATE_READ` / `MESSAGE_TEMPLATE_WRITE` |
| GET/PUT | `/api/v1/communications/templates/{id}` | `MESSAGE_TEMPLATE_READ` / `MESSAGE_TEMPLATE_WRITE` |
| GET | `/api/v1/communications?status=&studentId=&page=&size=` | `COMMUNICATION_READ` |
| GET | `/api/v1/communications/{id}` | `COMMUNICATION_READ` |
| POST | `/api/v1/communications/preview` | `COMMUNICATION_WRITE` |
| POST | `/api/v1/communications` | `COMMUNICATION_WRITE` |
| POST | `/api/v1/communications/{id}/opened` | `COMMUNICATION_WRITE` |
| POST | `/api/v1/communications/{id}/failed` | `COMMUNICATION_WRITE` |

## 2. Importación de estudiantes desde Excel

### Etapa 1: carga y prevalidación

- Se aceptan archivos `.xlsx` de hasta 5 MB y 2 000 filas de datos.
- El archivo se procesa en memoria: no se escribe en disco ni se expone públicamente.
- Se leen encabezados con alias en español e inglés.
- Columnas obligatorias: `Nombres`, `Apellidos`, `Fecha de ingreso`.
- Se validan formatos de fecha, correo, longitudes, estado y fecha de nacimiento.
- **No se crea ningún estudiante** en esta etapa.

### Etapa 2: vista previa

La respuesta incluye todas las filas con:

- `VALID`: se creará al confirmar.
- `ERROR`: errores de formato o campos obligatorios.
- `DUPLICATE_FILE`: identificación o nombre+fecha de nacimiento repetidos dentro del archivo.
- `DUPLICATE_EXISTING`: coincide con un estudiante existente por identificación o por
  nombre+apellido+fecha de nacimiento (este último criterio se aplica cuando no hay identificación).

La previsualización se guarda como lote (`student_import` + `student_import_row`) para poder
confirmarla después. No crea estudiantes.

### Etapa 3: confirmación

- Se bloquea el lote y se importan solo las filas `VALID`.
- Los duplicados y errores se omiten.
- Con `allowUpdateExisting = true` se actualizan explícitamente las coincidencias
  `DUPLICATE_EXISTING`; sin esa opción nunca se sobrescribe un estudiante.
- La operación es transaccional.
- Reintentar la confirmación del mismo lote devuelve el resultado existente sin duplicar.
- Se registra auditoría `STUDENT_IMPORT_PREVIEWED` y `STUDENT_IMPORT_CONFIRMED` con usuario,
  fecha, archivo, hash, resumen y conteos.

### Seguridad

- La institución proviene del usuario autenticado o del contexto explícito de `PLATFORM_ADMIN`;
  nunca del archivo.
- Se valida el acceso cruzado en todas las operaciones.
- No se guarda ni se registra el contenido del archivo ni documentos personales completos en logs.
- Solo se conserva nombre, tamaño y hash SHA-256 del archivo.

### Endpoints

| Método | Ruta | Permiso |
|---|---|---|
| POST | `/api/v1/imports/students/preview` (multipart, campo `file`) | `STUDENT_IMPORT_WRITE` |
| POST | `/api/v1/imports/students/{id}/confirm` | `STUDENT_IMPORT_WRITE` |
| GET | `/api/v1/imports/students` | `STUDENT_IMPORT_READ` |
| GET | `/api/v1/imports/students/{id}` | `STUDENT_IMPORT_READ` |

## 3. Migraciones y permisos

- `V11__communications_and_student_import_schema.sql`: plantillas, comunicaciones y lotes de
  importación con FK compuestas e índices.
- `V12__phase5a_permissions.sql`:
  - `COMMUNICATION_READ/WRITE`
  - `MESSAGE_TEMPLATE_READ/WRITE`
  - `STUDENT_IMPORT_READ/WRITE`

Asignación:

| Rol | Comunicaciones | Plantillas | Importación |
|---|---|---|---|
| `PLATFORM_ADMIN` | lectura y escritura | lectura y escritura | lectura y escritura |
| `INSTITUTION_ADMIN` | lectura y escritura | lectura y escritura | lectura y escritura |
| `SECRETARY` | lectura y escritura | lectura | lectura y escritura |
| `TREASURY` | lectura y escritura | lectura | lectura |
| `DIRECTOR` | lectura | lectura | lectura |

## 4. Frontend

- `/communications`: historial con filtros por estado y estudiante; acción para reabrir `wa.me`.
- `/communications/new`: selección de estudiante y representante autorizado, plantilla,
  información financiera opcional, vista previa del mensaje exacto y apertura de WhatsApp.
- `/communications/templates`: administración de plantillas y marcadores disponibles.
- `/imports/students`: carga del archivo, vista previa con tablas de válidas, errores y
  duplicados, confirmación con opción explícita de actualización y resultado final.
- Menú lateral actualizado con “Comunicaciones” e “Importar estudiantes”.
- Se mantiene la plantilla Berry y sus componentes visuales.

## 5. Ejemplos incluidos

- `docs/ejemplos/plantilla-estudiantes.xlsx`: solo encabezados.
- `docs/ejemplos/estudiantes-importacion.xlsx`: filas válidas, un duplicado interno y una fila con errores.
- `docs/ejemplos/README.md`: columnas y reglas.
- `docs/ejemplos/plantillas-comunicacion.md`: plantillas de pago, citación y bienvenida con JSON de ejemplo.
- En desarrollo, `DevDataSeeder` crea las tres plantillas para la institución demo si aún no existen.

## 6. Pruebas

`CommunicationIntegrationTest` (8 pruebas):

1. Crear plantilla y rechazar marcadores no permitidos.
2. Generar enlace `wa.me` correctamente codificado.
3. Rechazar representante no autorizado.
4. Rechazar teléfono ausente o inválido.
5. Rechazar acceso cruzado entre instituciones.
6. Controlar información financiera sensible.
7. Registrar la comunicación y sus transiciones de estado.
8. Verificar permisos por rol.

`StudentImportIntegrationTest` (11 pruebas):

1. Validar Excel correcto sin persistir estudiantes.
2. Rechazar extensión no permitida.
3. Detectar columnas obligatorias faltantes.
4. Detectar duplicados dentro del archivo por identificación y por nombre+fecha.
5. Detectar coincidencia con estudiante existente por identificación.
6. Detectar coincidencia por nombre y fecha de nacimiento.
7. Importar solo tras confirmar, con reintento idempotente y auditoría.
8. Mantener filas inválidas sin importar.
9. No sobrescribir estudiantes existentes sin opción explícita.
10. Rechazar acceso cruzado y exigir contexto de `PLATFORM_ADMIN`.
11. Verificar permisos por rol.

### Resultados exactos

```text
Tests run: 114, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

```text
npm --prefix app/frontend run build:dev   → Application bundle generation complete
npm --prefix app/frontend run build       → Application bundle generation complete
npm --prefix app/frontend run lint        → All files pass linting
```

## 7. Limitaciones y pendientes

- No hay integración con WhatsApp Business API ni confirmación real de envío o entrega.
- Solo se admite `.xlsx`; no se admite `.xls` ni CSV.
- La importación se limita a 5 MB y 2 000 filas por archivo.
- No se importan teléfonos o correos de representantes desde el Excel; el alcance es estudiantes.
- Las pantallas de comunicaciones e importación están disponibles para roles institucionales.
  `PLATFORM_ADMIN` puede usar los endpoints indicando `institutionId`, pero la interfaz aún no
  incluye un selector explícito de institución para estas pantallas.
- No se implementaron contabilidad formal, conciliación bancaria, integración bancaria ni
  facturación tributaria, conforme al alcance.
