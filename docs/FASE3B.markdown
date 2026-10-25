# Fase 3B — Pagos, aplicaciones y recibos internos

La Fase 3A fue revisada y aprobada. Continúa sobre el repositorio existente:

- Backend: `app/backend`
- Frontend: `app/frontend`

Mantén la arquitectura modular, los submódulos Git, el aislamiento multiinstitución y la plantilla Berry.

## Alcance exclusivo

Implementa únicamente:

- Registro de pagos.
- Verificación de transferencias.
- Aplicación de pagos a obligaciones.
- Pagos parciales.
- Pagos aplicados a varias obligaciones.
- Recibos internos.
- Anulación autorizada de pagos.
- Reversión de aplicaciones.
- Auditoría financiera.

No implementes todavía egresos, caja, comunicaciones ni reportes avanzados.

## Entidades mínimas

Implementa y relaciona:

- `Payment`
- `PaymentAllocation`
- `Receipt`
- `PaymentHistory` o una estructura equivalente de historial
- `AuditEvent`

Conserva las entidades existentes:

- `Institution`
- `Student`
- `Enrollment`
- `Charge`
- `ChargeItem`

Todas las entidades financieras deben incluir `institution_id` cuando corresponda y deben utilizar claves foráneas compuestas o una estrategia equivalente para impedir referencias cruzadas.

## Estados de pago

Utiliza inicialmente:

- `PENDING_VERIFICATION`
- `CONFIRMED`
- `VOID`

Reglas:

- Los pagos en efectivo pueden registrarse directamente como `CONFIRMED` si el rol tiene autorización.
- Las transferencias deben poder registrarse como `PENDING_VERIFICATION`.
- Un pago pendiente no cuenta como dinero recibido.
- Solo un pago `CONFIRMED` puede aplicarse a obligaciones.
- Un pago confirmado no puede editarse libremente.
- Un pago anulado debe conservarse y quedar auditado.

## Registro de pagos

Un pago debe registrar:

- Institución.
- Estudiante.
- Importe.
- Moneda.
- Medio de pago.
- Referencia.
- Fecha de recepción.
- Estado.
- Usuario que lo registró.
- Usuario que lo confirmó, si corresponde.
- Fecha de confirmación.
- Observaciones.
- Clave de idempotencia.

Medios iniciales:

- `CASH`
- `BANK_TRANSFER`

Deja el diseño preparado para agregar otros medios posteriormente.

El importe debe ser mayor que cero. Usa `NUMERIC(12,2)` en PostgreSQL y `BigDecimal` en Java.

## Aplicaciones de pagos

Un pago confirmado puede aplicarse a una o varias obligaciones.

Reglas obligatorias:

1. La suma de aplicaciones no puede superar el importe del pago.
2. Una aplicación no puede superar el saldo disponible de la obligación.
3. Una aplicación debe ser mayor que cero.
4. El pago y sus aplicaciones deben ejecutarse dentro de una transacción.
5. No se pueden mezclar obligaciones de distintas instituciones.
6. No se pueden aplicar pagos pendientes de verificación.
7. No se puede aplicar un pago anulado.
8. No se puede generar una aplicación duplicada por reintento.
9. Si alguna aplicación falla, debe revertirse toda la operación.
10. El saldo actualizado debe ser consistente después de confirmar la transacción.

Una operación puede recibir varias aplicaciones en una sola solicitud:

```json
{
  "allocations": [
    {
      "chargeId": "uuid",
      "amount": 100.00
    },
    {
      "chargeId": "uuid",
      "amount": 75.00
    }
  ]
}
