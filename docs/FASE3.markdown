# Fase 3A — Obligaciones de cobro y conceptos financieros

La Fase 2 fue revisada y aprobada con pendientes técnicos no bloqueantes. Continúa sobre el repositorio existente:

- Backend: `app/backend`
- Frontend: `app/frontend`

Mantén la arquitectura modular, los submódulos Git, el aislamiento multiinstitución y la plantilla Berry.

## Alcance de esta fase

Implementa únicamente obligaciones de cobro y conceptos financieros. No implementes todavía el registro de pagos ni los recibos.

Crea el módulo `billing`.

## Modelo funcional

Implementa, como mínimo:

- `Charge`
- `ChargeItem`
- Catálogo de conceptos de cobro
- Reglas básicas de generación
- Historial o auditoría de cambios de obligaciones
- Configuración de períodos de cobro cuando sea necesaria

Una obligación debe contener:

- Institución.
- Estudiante.
- Matrícula opcional.
- Fecha de emisión.
- Fecha de vencimiento.
- Estado.
- Subtotal.
- Impuesto.
- Total.
- Saldo.
- Moneda.
- Descripción.
- Usuario responsable.
- Fecha de creación.

Cada detalle debe contener:

- Concepto.
- Descripción.
- Cantidad.
- Precio unitario.
- Descuento si está soportado.
- Base imponible.
- Tasa de IVA aplicada.
- Importe de IVA.
- Total.

## Reglas iniciales confirmadas

1. Los importes deben utilizar `NUMERIC` en PostgreSQL y `BigDecimal` en Java.
2. Las obligaciones no pueden tener importes negativos.
3. Una matrícula confirmada puede generar un cobro inicial.
4. Las obligaciones también pueden crearse manualmente.
5. La generación mensual será asistida por un usuario.
6. La frecuencia de cobro será configurable.
7. La fecha de emisión y vencimiento serán configurables.
8. No implementar todavía recargos por mora.
9. No implementar todavía prorrateo automático.
10. Las peticiones repetidas no deben crear obligaciones duplicadas.
11. Las obligaciones históricas no deben cambiar por modificaciones posteriores del catálogo.
12. No se deben generar obligaciones automáticamente mediante procesos no solicitados.
13. No registrar todavía pagos ni aplicaciones de pagos.

## IVA

El IVA es configurable por institución.

Para una obligación generada desde una matrícula confirmada:

- Utiliza el precio acordado de la matrícula.
- Utiliza la tasa de IVA congelada en la matrícula.
- Guarda en el detalle la tasa y el importe aplicados.

Para una obligación manual:

- Utiliza la configuración vigente de la institución en el momento de crearla.
- Guarda una instantánea de la tasa aplicada.

Cambiar posteriormente la configuración de IVA no debe alterar obligaciones existentes.

## Estados

Utiliza inicialmente:

- `PENDING`
- `PARTIAL`
- `PAID`
- `VOID`

En esta fase se utilizarán principalmente `PENDING` y, si resulta necesario para pruebas, `VOID`. Los estados `PARTIAL` y `PAID` se preparan para la Fase 3B, cuando existan pagos.

## Seguridad

- Todas las obligaciones pertenecen a una institución.
- Nunca aceptes `institutionId` como mecanismo de autorización.
- Los usuarios institucionales solo pueden operar dentro de su institución.
- `PLATFORM_ADMIN` debe indicar explícitamente la institución objetivo.
- Los accesos globales deben quedar auditados.
- No permitas editar libremente una obligación histórica.
- No elimines físicamente obligaciones que ya tengan relaciones financieras.
- Usa DTOs y validaciones.
- No expongas entidades JPA directamente.

## Endpoints mínimos

Define y documenta endpoints para:

- Listar obligaciones con paginación.
- Buscar por estudiante.
- Filtrar por estado.
- Filtrar por fecha de emisión.
- Filtrar por vencimiento.
- Consultar detalle de una obligación.
- Crear una obligación manual.
- Generar el cobro inicial de una matrícula confirmada.
- Anular una obligación con motivo, si el negocio lo permite.
- Consultar el saldo.

Documenta todos los endpoints con OpenAPI.

## Frontend

Adapta la plantilla existente y crea:

- Listado de obligaciones.
- Filtros por estado y fechas.
- Formulario de obligación manual.
- Detalle de obligación.
- Vista de conceptos, IVA, total y saldo.
- Acción para generar el cobro inicial desde una matrícula confirmada.
- Confirmaciones para acciones sensibles.
- Estados de carga, error y vacío.

No implementes todavía pantallas de pagos ni recibos.

## Pruebas obligatorias

Implementa y ejecuta pruebas para:

1. Crear obligación manual.
2. Generar obligación desde una matrícula confirmada.
3. Calcular subtotal, IVA y total.
4. Aplicar IVA desactivado.
5. Aplicar IVA configurado.
6. Conservar la tasa histórica aunque cambie la configuración institucional.
7. Conservar el precio acordado aunque cambie la tarifa.
8. Rechazar importes negativos.
9. Rechazar referencias cruzadas entre instituciones.
10. Evitar duplicación al reintentar la generación.
11. Consultar obligaciones por institución.
12. Impedir acceso de una institución a obligaciones de otra.
13. Verificar permisos por rol.
14. Confirmar que no se crean pagos en esta fase.

Ejecuta las pruebas reales e informa el resultado exacto.
