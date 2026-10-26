# Fase 5A — Comunicaciones asistidas e importación de estudiantes

La Fase 4 fue revisada y aprobada con pendientes técnicos no bloqueantes. Continúa sobre el repositorio existente:

- Backend: `app/backend`
- Frontend: `app/frontend`

Mantén los submódulos Git, la arquitectura modular, el aislamiento multiinstitución y la plantilla Berry.

No implementes todavía contabilidad formal, conciliación bancaria, integración bancaria ni facturación tributaria.

## Módulo de comunicaciones

Implementa comunicaciones asistidas sin integración directa con WhatsApp Business API.

Debe ser posible:

1. Crear plantillas de mensajes.
2. Seleccionar un representante autorizado.
3. Verificar que tenga número de teléfono.
4. Generar un enlace `wa.me`.
5. Codificar correctamente el mensaje.
6. Mostrar vista previa antes de abrir WhatsApp.
7. Registrar la comunicación como preparada o iniciada.
8. Registrar usuario, fecha, estudiante, representante y plantilla utilizada.
9. Registrar estado:
   - `DRAFT`
   - `READY`
   - `OPENED`
   - `FAILED`
10. No afirmar que el mensaje fue enviado, porque `wa.me` no confirma el envío.

No incluyas automáticamente información financiera sensible sin mostrarla y confirmarla previamente.

El backend debe validar:

- Que el representante pertenezca a la institución.
- Que esté autorizado para comunicaciones.
- Que tenga teléfono válido.
- Que el estudiante pertenezca a la misma institución.
- Que el usuario tenga permisos suficientes.

## Importación de estudiantes desde Excel

Implementa un flujo de tres etapas:

### 1. Carga y prevalidación

- Recibir archivo Excel.
- Validar extensión y tamaño.
- Leer encabezados.
- Validar columnas obligatorias.
- Validar formatos.
- No persistir todavía los registros válidos.

### 2. Vista previa

Mostrar:

- Filas válidas.
- Filas con errores.
- Posibles duplicados.
- Campos que serán creados.
- Campos que requieren corrección.

Detectar duplicados por:

1. Identificación dentro de la institución, cuando exista.
2. Nombre y apellido más fecha de nacimiento, cuando no exista identificación.
3. Coincidencias con estudiantes existentes.
4. Duplicados dentro del archivo.

### 3. Confirmación e importación

Solo después de la confirmación del usuario:

- Crear estudiantes válidos.
- Mantener errores sin importar.
- Registrar usuario, fecha, archivo y resumen.
- Ejecutar la importación dentro de una transacción controlada.
- Evitar duplicaciones si se reintenta la misma operación.
- No sobrescribir estudiantes existentes sin una opción explícita.
- Generar reporte final de importación.

## Seguridad y aislamiento

- Nunca aceptar la institución desde el archivo Excel.
- La institución debe provenir del usuario autenticado o de un contexto explícito de `PLATFORM_ADMIN`.
- No permitir importar datos hacia otra institución.
- Validar permisos en backend.
- No registrar documentos personales completos en logs.
- No exponer archivos cargados públicamente.
- Eliminar o proteger archivos temporales después de procesarlos.

## Frontend

Crear:

- Pantalla de plantillas.
- Pantalla de preparación de comunicación.
- Vista previa del mensaje.
- Acción para abrir `wa.me`.
- Historial de comunicaciones.
- Pantalla de carga de Excel.
- Vista previa de importación.
- Tabla de errores.
- Tabla de posibles duplicados.
- Confirmación de importación.
- Resultado final.

Mantener la plantilla Berry y reutilizar sus componentes visuales.

## Pruebas obligatorias

Implementa y ejecuta pruebas para:

1. Crear plantilla.
2. Generar enlace `wa.me`.
3. Rechazar representante no autorizado.
4. Rechazar teléfono inválido.
5. Rechazar acceso cruzado entre instituciones.
6. Validar archivo Excel correcto.
7. Rechazar extensión no permitida.
8. Detectar columnas obligatorias faltantes.
9. Detectar duplicados en el archivo.
10. Detectar coincidencias con estudiantes existentes.
11. Mostrar vista previa sin persistir.
12. Importar solo después de confirmar.
13. No duplicar estudiantes al reintentar.
14. Mantener filas inválidas sin importar.
15. Registrar auditoría de la importación.
16. Verificar permisos por rol.

## Verificación final

Entrega:

- Migraciones Flyway.
- Entidades y endpoints.
- Pantallas frontend.
- Ejemplos de archivo Excel.
- Plantillas incluidas.
- Pruebas ejecutadas.
- Resultado de compilación y lint.
- Limitaciones.
- Funcionalidades que aún no se implementaron.
