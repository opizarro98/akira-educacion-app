# Fase 2 — Gestión escolar, catálogo y matrículas

La Fase 1 fue revisada y aprobada con pendientes técnicos no bloqueantes. Continúa sobre el repositorio existente:

- Backend: `app/backend`
- Frontend: `app/frontend`

Mantén la estructura de submódulos y la plantilla Berry. No crees repositorios nuevos ni reemplaces la arquitectura implementada.

## Decisiones ya confirmadas

- Cada usuario pertenece a una sola institución.
- Existe `PLATFORM_ADMIN`.
- La autenticación usa JWT.
- Los recibos son internos y no tributarios.
- La moneda inicial es USD.
- El IVA es configurable por institución.
- Solo el administrador institucional puede anular pagos; los pagos todavía no se implementan en esta fase.
- Las comunicaciones futuras podrán utilizar enlaces `wa.me`.
- El desarrollo y las pruebas se ejecutan contra PostgreSQL local.
- No se debe utilizar la base externa compartida.
- El aislamiento institucional implementado en la Fase 1 debe mantenerse en todas las nuevas entidades y endpoints.

## Alcance del backend

Implementa los módulos:

1. `students`
2. `representatives`
3. `catalog`
4. `enrollment`

### Estudiantes

Implementa:

- Crear estudiante.
- Editar estudiante.
- Consultar estudiante.
- Listar con paginación.
- Buscar por nombres, apellidos e identificación.
- Filtrar por estado.
- Fecha de nacimiento opcional.
- Fecha de ingreso obligatoria.
- Identificación opcional.
- Estados:
  - `PRE_REGISTERED`
  - `ACTIVE`
  - `WITHDRAWN`
  - `GRADUATED`
- Observaciones protegidas por permisos.
- Protección contra eliminación física cuando existan matrículas o información histórica.

La identificación, si existe, debe ser única dentro de la institución, no necesariamente a nivel global.

### Representantes

Implementa:

- Crear y editar representantes.
- Nombre completo.
- Identificación opcional.
- Teléfono.
- Correo.
- Varios representantes por estudiante.
- Un representante asociado a varios estudiantes.
- Contacto principal.
- Contacto autorizado para comunicaciones.
- Contacto autorizado para asuntos de cobro.

No asumas que todos los representantes tienen las mismas responsabilidades.

### Catálogo

Implementa entidades y endpoints para:

- Niveles educativos.
- Períodos lectivos.
- Servicios.
- Planes.
- Servicios incluidos en cada plan.
- Tarifas.
- Vigencia de tarifas.
- Estado activo/inactivo.

Todos los registros deben pertenecer a una institución cuando corresponda.

Permite períodos lectivos opcionales. Debe ser posible crear una matrícula sin período lectivo.

No codifiques precios en Angular ni en reglas fijas del backend.

Cuando una tarifa se utilice en una matrícula, conserva el precio acordado en la matrícula. Cambiar posteriormente el catálogo no debe alterar matrículas existentes.

El IVA debe tomarse de la configuración institucional vigente al momento de confirmar la operación y debe conservarse como información histórica cuando corresponda.

### Matrículas

Implementa:

- Crear matrícula.
- Editar matrícula mientras esté en estado editable.
- Confirmar matrícula.
- Cancelar matrícula con motivo.
- Consultar historial.
- Asociar estudiante.
- Asociar nivel.
- Asociar plan.
- Asociar servicios adicionales.
- Fecha de inicio.
- Fecha de finalización opcional.
- Período lectivo opcional.
- Precio acordado.
- Estado.

Usa los estados:

- `DRAFT`
- `CONFIRMED`
- `CANCELLED`
- `COMPLETED`

Una matrícula confirmada no debe modificarse libremente. Los cambios relevantes deben registrarse en auditoría o historial.

No implementes todavía la generación completa de obligaciones ni el registro de pagos. Si se prepara la generación del cobro inicial, deja únicamente una interfaz o servicio bien delimitado y no inventes reglas financieras no confirmadas.

## Reglas de seguridad

- El contexto institucional debe provenir del usuario autenticado.
- Nunca aceptes `institutionId` como mecanismo de autorización.
- Todas las consultas deben filtrar por institución.
- Prueba el acceso cruzado entre dos instituciones.
- `PLATFORM_ADMIN` puede realizar operaciones globales explícitas y auditadas.
- Los usuarios institucionales solo pueden acceder a los datos de su institución.
- Mantén DTOs, validaciones y errores consistentes.
- No expongas entidades JPA directamente.
- No registres datos personales innecesarios en logs.

## Alcance del frontend

Mantén la plantilla Berry y crea módulos bajo `features`:

- `features/students`
- `features/representatives`
- `features/catalog`
- `features/enrollments`

Implementa:

- Listado de estudiantes.
- Búsqueda y filtros.
- Formulario de creación y edición.
- Vista de expediente.
- Gestión de representantes.
- Listado y formularios de niveles.
- Listado y formularios de períodos.
- Servicios, planes y tarifas.
- Listado de matrículas.
- Formulario de nueva matrícula.
- Vista de detalle de matrícula.
- Estados de carga, error, éxito y vacío.
- Confirmaciones para cancelar una matrícula.
- Guards y permisos según el rol.
- Navegación desde estudiante hacia representantes y matrículas.

No implementes todavía pagos, obligaciones, egresos, comunicaciones ni reportes avanzados.

## Persistencia y migraciones

- Crea migraciones Flyway nuevas y ordenadas.
- Usa `institution_id` en las entidades de negocio.
- Agrega claves foráneas, restricciones e índices adecuados.
- Evita referencias entre instituciones mediante claves compuestas o estrategia equivalente.
- Usa `NUMERIC` y `BigDecimal` para precios.
- No utilices `ddl-auto=update`.
- No borres migraciones ya aplicadas.
- No modifiques datos históricos mediante cambios de catálogo.

## Pruebas obligatorias

Implementa y ejecuta pruebas para:

1. Crear estudiante.
2. Editar estudiante.
3. Buscar y filtrar estudiantes.
4. Crear representantes.
5. Asociar varios representantes a un estudiante.
6. Asociar un representante a varios estudiantes.
7. Rechazar acceso de una institución a los estudiantes de otra.
8. Crear nivel educativo.
9. Crear período lectivo.
10. Crear plan, servicios y tarifa.
11. Crear matrícula con período lectivo.
12. Crear matrícula sin período lectivo.
13. Confirmar matrícula.
14. Cancelar matrícula con motivo.
15. Evitar referencias cruzadas entre instituciones.
16. Mantener el precio acordado de una matrícula aunque cambie la tarifa del catálogo.
17. Verificar que las reglas de permisos funcionen por rol.

Ejecuta las pruebas reales y no declares una prueba aprobada si no fue ejecutada.

## Verificación final

Al finalizar informa:

- Archivos creados y modificados.
- Migraciones Flyway agregadas.
- Endpoints implementados.
- Pantallas implementadas.
- Pruebas ejecutadas y resultados.
- Estado de compilación backend y frontend.
- Cambios en cada submódulo.
- Pendientes técnicos de la Fase 1 que siguen abiertos.
- Funcionalidades que deliberadamente no fueron implementadas.
