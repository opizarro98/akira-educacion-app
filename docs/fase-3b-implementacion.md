# Fase 3B — Pagos, aplicaciones y recibos internos

Implementación sobre el repositorio de la Fase 3A, manteniendo la arquitectura modular,
el aislamiento multiinstitución, los submódulos Git y la plantilla Berry.

**Alcance respetado:** pagos, verificación de transferencias, aplicaciones, pagos parciales,
aplicaciones múltiples, recibos internos, anulación autorizada, reversión de aplicaciones y
auditoría financiera. No se implementaron egresos, caja, comunicaciones ni reportes avanzados.

## Modelo implementado

### Entidades (`com.akira.educacion.billing.domain`)

| Entidad | Descripción |
|---|---|
| `Payment` | Pago con institución, estudiante, importe, moneda, medio, referencia, fecha de recepción, estado, usuarios de registro/confirmación, observaciones, clave de idempotencia y datos de anulación. |
| `PaymentAllocation` | Aplicación de un pago confirmado a una obligación. Se revierte sin eliminar y conserva motivo, actor y fecha. |
| `Receipt` | Recibo interno emitido al confirmar el pago, con numeración secuencial por institución. |
| `PaymentHistory` | Historial append-only de registro, confirmación, aplicaciones, reversiones y anulación. |
| `AuditEvent` | Auditoría transversal existente; se añadieron eventos financieros específicos. |

Migraciones:

- `V7__payments_schema.sql`: `payment`, `payment_allocation`, `receipt`, `receipt_counter` y
  `payment_history`. Incluye:
  - `NUMERIC(12,2)` y checks de importes positivos.
  - FKs compuestas `(institution_id, id)` para impedir referencias cruzadas.
  - `applied_amount` en `payment` con check `0 <= aplicado <= importe`.
  - Índice único parcial que impide dos aplicaciones vigentes del mismo pago a la misma obligación.
  - Recibo único por pago y numeración única por institución.
- `V8__phase3b_permissions.sql`: `PAYMENT_READ`, `PAYMENT_WRITE`, `PAYMENT_VERIFY`,
  `PAYMENT_APPLY`, `PAYMENT_VOID`, `RECEIPT_READ`, asignados por rol.

### Estados y medios

- Estados de pago: `PENDING_VERIFICATION`, `CONFIRMED`, `VOID`.
- Medios: `CASH`, `BANK_TRANSFER`. El enum queda abierto a nuevos medios.
- Los estados de obligación `PARTIAL` y `PAID` de la Fase 3A ahora se ejercitan realmente.

## Reglas implementadas

### Registro y verificación

1. El importe debe ser mayor que cero.
2. El efectivo se registra como `CONFIRMED` únicamente si el usuario tiene `PAYMENT_VERIFY`;
   en caso contrario queda `PENDING_VERIFICATION`.
3. Las transferencias quedan `PENDING_VERIFICATION` y exigen referencia.
4. Un pago pendiente no expone dinero disponible (`availableAmount = 0`).
5. La confirmación registra usuario y fecha, emite el recibo y deja historial y auditoría.
6. No existe edición libre de pagos. Solo se confirman o anulan.
7. La anulación exige motivo, conserva el pago y anula su recibo. Si tiene aplicaciones vigentes,
   primero deben revertirse.

### Aplicaciones

1. Solo un pago `CONFIRMED` puede aplicarse.
2. No se aplican pagos pendientes ni anulados.
3. La suma de aplicaciones no supera el importe disponible del pago.
4. Cada aplicación es mayor que cero y no supera el saldo de la obligación.
5. Toda la operación ocurre en una transacción; cualquier fallo revierte el lote completo.
6. No se mezclan obligaciones de otras instituciones ni de otro estudiante.
7. No se aplican pagos a obligaciones anuladas.
8. No se duplican aplicaciones:
   - Índice único de aplicación vigente por pago/obligación.
   - `idempotencyKey` de operación: un reintento devuelve el mismo resultado.
9. Los saldos se actualizan dentro de la transacción y se recalculan:
   - `PENDING` si no hay pagos.
   - `PARTIAL` si hay pagos y saldo pendiente.
   - `PAID` si el saldo llega a cero.
10. Pago y obligaciones se bloquean con `PESSIMISTIC_WRITE` para evitar carreras concurrentes.

### Reversión

- La reversión restaura el saldo de la obligación y reduce `applied_amount` del pago.
- La aplicación no se elimina: queda marcada como revertida con motivo, actor y fecha.
- Una aplicación revertida no puede revertirse de nuevo.

### Recibos

- Un recibo interno por pago confirmado.
- Numeración atómica por institución mediante `INSERT ... ON CONFLICT ... RETURNING`.
- Al anular el pago, el recibo queda anulado con el mismo motivo.
- No es un comprobante fiscal.

## API

| Método | Ruta | Permiso |
|---|---|---|
| GET | `/api/v1/billing/payments` | `PAYMENT_READ` |
| GET | `/api/v1/billing/payments/{id}` | `PAYMENT_READ` |
| GET | `/api/v1/billing/payments/{id}/history` | `PAYMENT_READ` |
| POST | `/api/v1/billing/payments` | `PAYMENT_WRITE` |
| POST | `/api/v1/billing/payments/{id}/confirm` | `PAYMENT_VERIFY` |
| POST | `/api/v1/billing/payments/{id}/void` | `PAYMENT_VOID` |
| POST | `/api/v1/billing/payments/{id}/allocations` | `PAYMENT_APPLY` |
| POST | `/api/v1/billing/payments/{id}/allocations/{allocationId}/reverse` | `PAYMENT_APPLY` |
| GET | `/api/v1/billing/receipts` | `RECEIPT_READ` |
| GET | `/api/v1/billing/receipts/{id}` | `RECEIPT_READ` |
| GET | `/api/v1/billing/receipts/by-payment/{paymentId}` | `RECEIPT_READ` |

Todos los endpoints están documentados con OpenAPI. Los errores mantienen `ProblemDetail`
con códigos `VALIDATION_ERROR`, `NOT_FOUND`, `CONFLICT`, `BAD_REQUEST` y `ACCESS_DENIED`.

## Frontend

Rutas nuevas:

- `/billing/payments`: listado con filtros por estado, medio, estudiante y fecha de recepción.
- `/billing/payments/new`: registro de efectivo o transferencia con idempotencia automática.
- `/billing/payments/{id}`: detalle con aplicaciones, recibo, historial, confirmación, anulación,
  aplicación a una o varias obligaciones y reversión de aplicaciones.
- `/billing/receipts`: listado de recibos internos.
- `/billing/receipts/{id}`: recibo imprimible con estado de anulación.

El menú lateral incorpora **Pagos** y **Recibos**. Las acciones sensibles usan confirmación y
las pantallas incluyen estados de carga, error y vacío.

## Pruebas

Comando ejecutado:

```sh
cd app/backend
env DB_URL=jdbc:postgresql://localhost:5432/db_red_new \
    DB_USER=usr_app_red_new DB_PASSWORD=red_new DB_SCHEMA=akira_test \
    ./mvnw -B test
```

Resultado exacto:

```text
Tests run: 77, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

Nueva suite `PaymentIntegrationTest`: **14 pruebas, 0 fallos**. Cubre:

1. Pago en efectivo confirmado con recibo e historial.
2. Transferencia pendiente que no cuenta como dinero disponible.
3. Confirmación de transferencia con emisión de recibo.
4. Aplicación parcial y actualización de saldo de la obligación.
5. Aplicación de un pago a varias obligaciones en una sola operación.
6. Rechazo de aplicaciones que superan el pago o el saldo de la obligación.
7. Reintento idempotente y rechazo de aplicaciones duplicadas.
8. Rechazo de referencias cruzadas entre instituciones.
9. Rechazo de aplicación de pagos anulados.
10. Reversión de aplicación y restauración del saldo.
11. Anulación autorizada con historial y anulación del recibo.
12. Permisos por rol.
13. Prohibición de aplicar a obligaciones de otro estudiante.
14. Consulta de recibos internos y numeración secuencial.

Verificación del frontend:

```sh
npm --prefix app/frontend run build:dev   # OK
npm --prefix app/frontend run lint        # OK
```

## Notas técnicas

- La verificación de un pago y la emisión del recibo comparten la misma transacción.
- La comprobación de idempotencia de aplicaciones se realiza con el pago bloqueado, permitiendo
  que varios reintentos concurrentes converjan sin duplicar el lote.
- La clave de operación se comparte entre las aplicaciones de un mismo lote; por ello se usa un
  índice no único y la validación se hace en el servicio.
- El dinero disponible se calcula solo para pagos `CONFIRMED`; pendientes y anulados reportan cero.
- Anular un pago no elimina ninguna fila: pago, aplicaciones revertidas, recibo y historial se
  conservan para auditoría.

## Pendiente para fases posteriores

- Egresos, caja y conciliaciones.
- Comunicaciones y reportes avanzados.
- Otros medios de pago con reglas propias de verificación.
