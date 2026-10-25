# Fase 3A — Obligaciones de cobro y conceptos financieros

Implementación sobre el repositorio de la Fase 2. Se mantuvieron la arquitectura modular,
los submódulos Git, el aislamiento multiinstitución y la plantilla Berry.

**Alcance respetado:** solo obligaciones de cobro y conceptos financieros. No se registran
pagos ni se emiten recibos.

## Modelo implementado

### Backend (`com.akira.educacion.billing`)

| Elemento | Descripción |
|---|---|
| `Charge` | Obligación: institución, estudiante, matrícula opcional, emisión, vencimiento, estado, subtotal, impuesto, total, pagado, saldo, moneda, descripción, usuario responsable y fechas de auditoría. |
| `ChargeItem` | Detalle: concepto (referencia + instantánea de código/nombre), descripción, cantidad, precio unitario, descuento, base imponible, tasa de IVA, importe de IVA y total. |
| `BillingConcept` | Catálogo de conceptos de cobro por institución, con importe sugerido para la generación mensual. |
| `BillingSettings` | Configuración de períodos de cobro: frecuencia, día de emisión (1-28), días hasta el vencimiento (0-120) y habilitación. |
| `ChargeHistory` | Historial append-only de creación y anulación. |
| `ChargeStatus` | `PENDING`, `PARTIAL`, `PAID`, `VOID`. `PARTIAL` y `PAID` quedan preparados para la Fase 3B. |
| `ChargeOrigin` | `MANUAL`, `ENROLLMENT`, `MONTHLY`. |

Migraciones:

- `V5__billing_schema.sql`: tablas, claves foráneas compuestas `(institution_id, id)`, checks de
  importes no negativos, coherencia `total = subtotal + IVA`, `saldo = total - pagado` e índices
  únicos de idempotencia.
- `V6__phase3_permissions.sql`: permisos `CHARGE_READ/WRITE`, `BILLING_CONCEPT_READ/WRITE` y
  `BILLING_SETTINGS_READ/WRITE` asignados por rol.

### Reglas de negocio

1. **NUMERIC(12,2) + BigDecimal** en todos los importes y en el cálculo de IVA.
2. **Importes no negativos** validados en DTOs, servicio y restricciones de base de datos.
3. **Cobro inicial** desde matrícula `CONFIRMED`, usando el precio acordado y la tasa de IVA
   congelada en la matrícula. Cada servicio adicional de la matrícula se copia como detalle.
4. **Obligaciones manuales** con conceptos del catálogo, IVA vigente de la institución y
   descuentos por línea. La tasa aplicada se guarda en cada detalle.
5. **Generación mensual asistida** mediante `POST /generate-monthly`; no existen procesos
   automáticos ni tareas programadas.
6. **Frecuencia y fechas configurables** en `billing_settings`; la emisión usa el día configurado
   y el vencimiento suma los días de gracia.
7. **Sin recargos por mora ni prorrateo** en esta fase.
8. **Idempotencia**:
   - Cobro inicial: `ENROLLMENT_INITIAL:{enrollmentId}` + índice único parcial por matrícula.
   - Mensual: `MONTHLY:{studentId}:{conceptId}:{YYYY-MM}`.
   - Manual: `idempotencyKey` opcional protegida por índice único `(institution_id, idempotency_key)`.
9. **Histórico inmutable**: no existe endpoint de edición. La anulación exige motivo, no permite
   obligaciones con pagos y deja registro en `charge_history` y `audit_event`.
10. **Sin eliminación física**: la base protege las referencias financieras con FK y no se expone
    un borrado de obligaciones.
11. **Aislamiento**: la institución proviene de `InstitutionScope`; `PLATFORM_ADMIN` debe indicar
    `?institutionId=` y el acceso global queda auditado. Nunca se acepta `institutionId` en el cuerpo
    como autorización.
12. **Sin pagos**: `paid_amount` permanece en cero y no se crean tablas de pagos ni recibos.

### IVA

- Institucional por defecto: si `vat_enabled = false`, la tasa es `0.00`; si la vigencia es futura,
  también `0.00`.
- Matrícula confirmada: se usa la tasa congelada en `enrollment.vat_rate`.
- Obligación manual: se usa la configuración vigente y se guarda la instantánea en el detalle.
- Cambiar la configuración de IVA o las tarifas del catálogo no altera obligaciones existentes.

## API

| Método | Ruta | Permiso |
|---|---|---|
| GET | `/api/v1/billing/charges` | `CHARGE_READ` |
| GET | `/api/v1/billing/charges/{id}` | `CHARGE_READ` |
| GET | `/api/v1/billing/charges/{id}/balance` | `CHARGE_READ` |
| GET | `/api/v1/billing/charges/{id}/history` | `CHARGE_READ` |
| POST | `/api/v1/billing/charges` | `CHARGE_WRITE` |
| POST | `/api/v1/billing/charges/from-enrollment/{enrollmentId}` | `CHARGE_WRITE` |
| POST | `/api/v1/billing/charges/generate-monthly` | `CHARGE_WRITE` |
| POST | `/api/v1/billing/charges/{id}/void` | `CHARGE_WRITE` |
| GET | `/api/v1/billing/concepts` | `BILLING_CONCEPT_READ` |
| POST/PUT | `/api/v1/billing/concepts[/{id}]` | `BILLING_CONCEPT_WRITE` |
| GET | `/api/v1/billing/settings` | `BILLING_SETTINGS_READ` |
| PUT | `/api/v1/billing/settings` | `BILLING_SETTINGS_WRITE` |

Todos los endpoints están documentados con OpenAPI (springdoc). Los errores usan `ProblemDetail`
con `code` (`VALIDATION_ERROR`, `NOT_FOUND`, `CONFLICT`, `BAD_REQUEST`, `ACCESS_DENIED`).

## Frontend

Rutas nuevas:

- `/billing/charges`: listado con filtros por estado, estudiante, fecha de emisión y vencimiento.
- `/billing/charges/new`: formulario manual con conceptos, descuentos, vista previa de subtotal,
  IVA y total, y clave de idempotencia generada automáticamente.
- `/billing/charges/:id`: detalle con conceptos, IVA, total, pagado, saldo, responsable e historial;
  anulación con motivo y confirmación.
- `/billing/concepts`: catálogo de conceptos y configuración de períodos de cobro.

Además, el detalle de una matrícula `CONFIRMED` incluye la acción **Generar cobro inicial**, con
confirmación previa y redirección al detalle de la obligación.

Se implementaron estados de carga, error y vacío en todas las pantallas. El menú lateral incorpora
**Cobros** para los roles institucionales.

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
Tests run: 63, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

Nueva suite `ChargeIntegrationTest`: **14 pruebas, 0 fallos**. Cubre:

1. Crear obligación manual.
2. Generar obligación desde matrícula confirmada.
3. Calcular subtotal, IVA y total.
4. Aplicar IVA desactivado.
5. Aplicar IVA configurado.
6. Conservar la tasa histórica aunque cambie la configuración institucional.
7. Conservar el precio acordado aunque cambie la tarifa.
8. Rechazar importes negativos y descuentos inválidos.
9. Rechazar referencias cruzadas entre instituciones.
10. Evitar duplicados al reintentar la generación.
11. Consultar obligaciones por institución con filtros.
12. Impedir acceso de una institución a obligaciones de otra.
13. Verificar permisos por rol.
14. Confirmar que no se crean pagos ni tablas de pagos en esta fase.

Pruebas adicionales: anulación con motivo e historial, y generación mensual asistida idempotente.

Verificación del frontend:

```sh
npm --prefix app/frontend run build:dev   # OK
npm --prefix app/frontend run lint        # OK
```

## Pendiente para la Fase 3B

- Registro de pagos, aplicaciones y recibos.
- Transiciones reales a `PARTIAL` y `PAID`, con recálculo de saldo.
- Reversos y conciliaciones.

## Notas técnicas

- Se mantiene `InitialChargeGenerator` sin acción: la confirmación de matrícula **no** emite
  obligaciones. La emisión es siempre explícita desde el endpoint correspondiente.
- `ChargeItem` guarda referencia al concepto y su instantánea. Si un concepto se modifica o
  desactiva, las obligaciones existentes no cambian.
- La consulta de listado pagina solo datos de la cabecera y evita cargar detalles; el detalle carga
  los ítems mediante `EntityGraph`.
