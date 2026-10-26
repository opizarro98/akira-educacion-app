# Fase 4 — Egresos, caja y reportes financieros

Implementación realizada sobre las fases 1, 2, 3A y 3B, conservando las reglas de pagos,
aplicaciones, recibos e instituciones.

## 1. Decisiones previas solicitadas

### Anulación de pagos

La anulación de un pago era una operación que exigía revertir manualmente las aplicaciones
vigentes. En la Fase 4 se convirtió en una **operación atómica**: al anular un pago el
servicio, dentro de la misma transacción,

1. bloquea el pago,
2. revierte todas sus aplicaciones vigentes y restaura el saldo de cada obligación,
3. deja el pago con `applied_amount = 0`,
4. lo marca como `VOID` con motivo, actor y fecha,
5. anula el recibo interno,
6. genera la reversión de caja `PAYMENT_VOID_REVERSAL` si el pago estaba confirmado,
7. registra historial y auditoría.

Con esto no puede quedar un pago anulado con dinero aplicado ni un movimiento de caja
huérfano. La prueba `PaymentIntegrationTest.anulaPagoAutorizadoConservandoHistorialYAnulandoRecibo`
se actualizó para verificar la reversión atómica en lugar del antiguo `409`.

### Relación recibo ↔ aplicaciones

Se verificó el modelo existente: el recibo interno referencia **un pago** (`payment_id`) y
conserva el importe y la moneda del pago. Las aplicaciones viven en `payment_allocation` y
se consultan en el detalle del pago y en los reportes. No se duplican aplicaciones dentro
del recibo; el recibo es el comprobante del dinero recibido y el detalle del pago es la
trazabilidad de cómo se distribuyó. Esta decisión se mantiene y queda documentada.

## 2. Esquema y migraciones

- `V9__finance_schema.sql`
  - `expense_category` (única por institución y nombre; código opcional único).
  - `expense` (importes `NUMERIC(12,2)`, estados `DRAFT|CONFIRMED|VOID`, FK compuesta a la categoría).
  - `expense_history` append-only.
  - `cash_movement` con tipos `PAYMENT_IN|EXPENSE_OUT|PAYMENT_VOID_REVERSAL|EXPENSE_VOID_REVERSAL`,
    importe positivo, origen polimórfico (`PAYMENT|EXPENSE`) y **índice único**
    `(institution_id, source_type, source_id, movement_type)`.
- `V10__phase4_permissions.sql`
  - Permisos: `EXPENSE_CATEGORY_READ/WRITE`, `EXPENSE_READ/WRITE`, `CASH_MOVEMENT_READ`,
    `FINANCE_REPORT_READ`.
  - Asignación: administración y tesorería con escritura; secretaría y dirección con consulta.

## 3. Egresos

- Registro en `DRAFT`; edición solo en borrador.
- Confirmación: `DRAFT → CONFIRMED`, genera `EXPENSE_OUT` en la misma transacción y bloquea la edición.
- Anulación: `DRAFT|CONFIRMED → VOID` con motivo obligatorio; si estaba confirmado genera
  `EXPENSE_VOID_REVERSAL`.
- Historial `REGISTERED`, `UPDATED`, `CONFIRMED`, `VOIDED` y auditoría con acciones
  `EXPENSE_REGISTERED`, `EXPENSE_UPDATED`, `EXPENSE_CONFIRMED`, `EXPENSE_VOIDED`.
- La moneda debe coincidir con la de la institución; los importes se normalizan a escala 2.

## 4. Movimientos de caja

- `PAYMENT_IN`: pago confirmado (efectivo confirmado al registrar o transferencia verificada).
- `EXPENSE_OUT`: egreso confirmado.
- `PAYMENT_VOID_REVERSAL`: pago confirmado que se anula.
- `EXPENSE_VOID_REVERSAL`: egreso confirmado que se anula.
- Un pago pendiente no genera movimiento.
- La creación es idempotente en servicio y en base de datos. Confirmar dos veces devuelve
  `409` y no duplica el movimiento.
- El saldo de caja se calcula con importes con signo; las reversiones compensan la operación original.

## 5. Reportes y dashboard

Endpoints en `/api/v1/finance`:

- Cobros confirmados por período, con totales por medio de pago.
- Pagos pendientes de verificación.
- Pagos anulados (período según fecha de anulación).
- Obligaciones pendientes y cartera vencida.
- Egresos confirmados por período, con totales por categoría.
- Entradas y salidas de caja (`cash-flow`) y resumen de caja (`cash-summary`).
- Dashboard institucional.

Cada reporte devuelve una cabecera con institución, período, zona horaria, moneda, fecha de
generación, si incluye anulaciones y los importes **devengado**, **cobrado** y **diferencia**.
Las obligaciones pendientes nunca se suman al dinero cobrado.

Los documentos con fecha de negocio (`payment.received_date`, `charge.issue_date`,
`expense.expense_date`) se filtran por fecha inclusiva. Los movimientos y anulaciones con
`TIMESTAMPTZ` se filtran con un rango semiabierto en la zona horaria de la institución
(`America/Guayaquil` por defecto).

### Dashboard

Indicadores reales: estudiantes activos, matrículas confirmadas, obligaciones pendientes,
cartera vencida, cobros confirmados, egresos, entradas/salidas y saldo de caja, pagos por
medio de pago, egresos por categoría y serie de caja de los últimos seis meses. No se
mantienen datos demo en las visualizaciones.

## 6. Aislamiento y seguridad

- Todas las rutas resuelven la institución con `InstitutionScope`.
- Un `institutionId` del cuerpo o query no autoriza nada: un usuario institucional que envíe
  otra institución recibe `403`.
- `PLATFORM_ADMIN` debe indicar `?institutionId=` explícitamente; el acceso queda auditado.
- Las FK compuestas impiden referencias cruzadas entre instituciones.
- Cada consulta de reporte registra `FINANCE_REPORT_VIEWED`.

## 7. Pruebas

`FinanceIntegrationTest` implementa 18 pruebas:

1. Crear categoría de egreso y rechazar duplicados.
2. Registrar egreso y editarlo en borrador.
3. Confirmar egreso y bloquear la edición.
4. Confirmar egreso genera salida de caja.
5. Confirmar pago genera entrada de caja.
6. Pago pendiente no genera entrada.
7. Anular pago genera reversión y restaura el saldo.
8. Anular egreso confirmado genera reversión.
9. Evitar movimientos de caja duplicados.
10. Separar obligaciones generadas de dinero recibido.
11. Filtrar reportes por institución.
12. Rechazar acceso cruzado entre instituciones.
13. Consultar cartera vencida correctamente.
14. Conciliar dashboard con operaciones confirmadas.
15. Verificar reportes después de anulaciones.
16. Verificar importes con `BigDecimal` y `NUMERIC` (0.10 + 0.20 = 0.30).
17. Verificar zona horaria y límites de fechas.
18. Verificar permisos por rol.

### Resultados exactos

```text
Tests run: 95, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

Comando ejecutado:

```sh
env DB_URL=jdbc:postgresql://localhost:5432/db_red_new \
    DB_USER=usr_app_red_new DB_PASSWORD=red_new DB_SCHEMA=akira_test \
    ./mvnw -B clean test
```

Compilación y lint del frontend:

```text
npm --prefix app/frontend run build:dev   → Application bundle generation complete
npm --prefix app/frontend run build       → Application bundle generation complete
npm --prefix app/frontend run lint        → All files pass linting
```

## 8. Frontend

- `/finance/expenses` (lista, alta y detalle con confirmación/anulación).
- `/finance/expense-categories` (alta, edición y activación/desactivación).
- `/finance/cash-movements` (filtros por tipo y período, totales y detalle).
- `/finance/reports` (cobros, pendientes, anulados, cartera, egresos y caja).
- `/dashboard` con indicadores y gráficos alimentados por el endpoint real.
- Menú lateral: Egresos, Caja y Reportes.

## 9. Decisiones pendientes

- Definir si se requerirán roles y permisos separados para confirmar vs. registrar egresos.
- Definir el tratamiento de notas de crédito y devoluciones parciales de egresos.
- Definir si los reportes deben exportarse (PDF/Excel) y con qué numeración interna.
- Definir la política de retención de movimientos de caja y su cierre mensual.

## 10. Limitaciones conocidas

- No se implementó contabilidad formal, conciliación bancaria, integración bancaria ni comunicaciones.
- Los reportes no paginan: devuelven todas las filas del período consultado.
- Los medios de pago siguen siendo `CASH` y `BANK_TRANSFER`; no hay tarjeta ni otros medios.
- El dashboard y las pantallas financieras están disponibles para roles institucionales. Un
  `PLATFORM_ADMIN` puede operar los endpoints indicando `institutionId`, pero la interfaz aún
  no incluye un selector de institución para esas pantallas.
- La serie de caja del dashboard muestra seis meses; no es un reporte histórico arbitrario.
