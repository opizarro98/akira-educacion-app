# Fase 4 — Egresos, caja y reportes financieros

La Fase 3B fue revisada y aprobada con observaciones no bloqueantes. Antes de iniciar, conserva las reglas actuales de pagos, aplicaciones, recibos e instituciones.

Si el flujo actual de anulación de pagos exige revertir aplicaciones previamente, documenta esta decisión o evalúa convertir la anulación en una operación atómica que revierta automáticamente todas las aplicaciones vigentes.

Verifica también cómo se representa en el recibo la relación entre el pago y sus aplicaciones.

## Alcance

Implementa:

1. Categorías de egreso.
2. Registro de egresos.
3. Movimientos de caja.
4. Entradas derivadas de pagos confirmados.
5. Salidas derivadas de egresos confirmados.
6. Anulación o reversión de egresos.
7. Dashboard y reportes financieros básicos.

No implementes todavía contabilidad formal, conciliación bancaria completa, integración bancaria ni comunicaciones.

## Egresos

Un egreso debe registrar:

- Institución.
- Categoría.
- Importe.
- Moneda.
- Fecha.
- Descripción.
- Medio de pago.
- Beneficiario o proveedor si corresponde.
- Usuario responsable.
- Estado.
- Motivo de anulación, si aplica.
- Auditoría.

Estados sugeridos:

- `DRAFT`
- `CONFIRMED`
- `VOID`

Un egreso confirmado no debe editarse libremente. Una modificación debe realizarse mediante anulación auditada y nuevo registro, si el negocio lo permite.

## Movimientos de caja

Implementa `CashMovement` como registro derivado y auditable.

Tipos mínimos:

- `PAYMENT_IN`
- `EXPENSE_OUT`
- `PAYMENT_VOID_REVERSAL`
- `EXPENSE_VOID_REVERSAL`

Reglas:

- Un pago confirmado genera una entrada de caja.
- Un pago pendiente no genera movimiento de caja.
- Un pago anulado genera una reversión.
- Un egreso confirmado genera una salida de caja.
- Un egreso anulado genera una reversión.
- No registres manualmente como ingreso el mismo pago escolar confirmado.
- Cada operación financiera debe generar como máximo el movimiento correspondiente, protegido por idempotencia.

## Aislamiento

- Todas las operaciones deben filtrarse por institución.
- No aceptar `institutionId` desde el cuerpo como mecanismo de autorización.
- `PLATFORM_ADMIN` debe seleccionar explícitamente la institución.
- Las referencias entre instituciones deben ser rechazadas por aplicación y base de datos.
- Los reportes globales deben quedar auditados.

## Reportes mínimos

Implementa endpoints y pantallas para:

- Cobros confirmados por período.
- Pagos pendientes de verificación.
- Pagos anulados.
- Obligaciones pendientes.
- Cartera vencida.
- Egresos por período.
- Entradas y salidas de caja.
- Resumen de caja por institución.
- Totales por medio de pago.
- Totales por categoría de egreso.

Cada reporte debe indicar:

- Institución.
- Período consultado.
- Fecha y zona horaria utilizada.
- Moneda.
- Si incluye o excluye anulaciones.
- Diferencia entre devengado y cobrado.

No sumes obligaciones como si fueran dinero recibido.

## Dashboard

Actualiza el dashboard con:

- Estudiantes activos.
- Matrículas.
- Obligaciones pendientes.
- Cartera vencida.
- Cobros confirmados.
- Egresos.
- Saldo de caja.
- Pagos por medio de pago.

Los gráficos deben cargarse desde endpoints reales. No mantengas datos demo en las visualizaciones funcionales.

## Pruebas obligatorias

Implementa y ejecuta pruebas para:

1. Crear categoría de egreso.
2. Registrar egreso.
3. Confirmar egreso.
4. Generar salida de caja.
5. Confirmar pago y generar entrada de caja.
6. Verificar que pago pendiente no genere entrada.
7. Anular pago y generar reversión.
8. Anular egreso y generar reversión.
9. Evitar movimientos de caja duplicados.
10. Separar obligaciones generadas de dinero recibido.
11. Filtrar reportes por institución.
12. Rechazar acceso cruzado.
13. Consultar cartera vencida correctamente.
14. Conciliar dashboard con operaciones confirmadas.
15. Verificar reportes después de anulaciones.
16. Verificar importes con `BigDecimal` y `NUMERIC`.
17. Verificar la zona horaria y los límites de fechas.
18. Verificar permisos por rol.

Ejecuta las pruebas reales y documenta resultados exactos.

## Entregables

Entrega:

- Migraciones Flyway.
- Entidades y relaciones.
- Servicios y transacciones.
- Endpoints documentados.
- Pantallas frontend.
- Reportes.
- Pruebas.
- Resultado de compilación y lint.
- Decisiones pendientes.
- Limitaciones conocidas.
