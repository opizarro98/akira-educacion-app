# Respaldo y recuperación — PostgreSQL

> Estado real en esta fase: se generó un respaldo lógico y se verificó el archivo. **No se
> ejecutó una restauración completa** en una base separada porque el rol local no tiene
> `CREATEDB`. El procedimiento queda documentado para ejecutarlo en el entorno real.

## 1. Qué respaldar

| Elemento | ¿Respaldo? | Notas |
|---|---|---|
| Base de datos PostgreSQL (esquema de la aplicación) | Sí | Contiene estudiantes, cobros, pagos, caja, comunicaciones e importaciones |
| `JWT_SECRET` y credenciales | Sí, en gestor de secretos | Sin ellos los tokens emitidos quedan inválidos |
| `.env` / variables de entorno | Sí, cifrado | Nunca en el repositorio |
| Volumen de PostgreSQL | Opcional | Complementa, no sustituye, al respaldo lógico |
| Archivos Excel originales | No | Se procesan en memoria; solo se guardan nombre, tamaño y hash |
| Logs | No por defecto | Evitar datos personales; no son fuente de recuperación |

No incluya en el repositorio ni en logs: contraseñas, `JWT_SECRET`, documentos personales
completos, contenido de mensajes con datos financieros.

## 2. Respaldo lógico

Formato custom (recomendado, comprimido y restaurable por partes):

```bash
PGPASSWORD='***' pg_dump \
  -h HOST -p 5432 -U USUARIO -d BASE \
  -n ESQUEMA \
  -Fc -f /respaldos/akira_$(date +%Y%m%d_%H%M).dump
```

- `-n ESQUEMA` respalda solo el esquema de la aplicación (por defecto `akira`).
- Para respaldar todo el clúster, omita `-n` y use `pg_dumpall -g` aparte para roles.
- Verifique el archivo:

```bash
pg_restore --list /respaldos/akira_YYYYMMDD_HHMM.dump | head
```

Un archivo válido lista objetos (tablas, secuencias, índices). Un archivo vacío o truncado debe
descartarse.

### Ejecución real en esta fase

```text
pg_dump -Fc -n akira_e2e -f /tmp/akira_e2e_backup.dump   → 146 KB
pg_restore --list ... | wc -l                            → 278 entradas
```

## 3. Frecuencia y retención recomendadas

| Tipo | Frecuencia | Retención | Ubicación |
|---|---|---|---|
| Diario automático | 02:00 hora local | 30 días | Servidor de respaldos cifrado |
| Semanal | Domingos | 12 semanas | Almacenamiento externo |
| Mensual | Primer día del mes | 12 meses | Almacenamiento externo inmutable |
| Antes de cada despliegue | Manual | Hasta validar la versión | Servidor de respaldos |

Ajuste según volumen y requisitos legales aplicables. Los archivos deben cifrarse en reposo y
transferirse por canales seguros (SFTP/objeto con TLS).

## 4. Restauración en base separada (verificación)

Requiere un rol con `CREATEDB` o un administrador que cree la base:

```bash
createdb -h HOST -U ADMIN akira_restore_test
pg_restore -h HOST -U ADMIN -d akira_restore_test \
  --no-owner --no-privileges --exit-on-error \
  /respaldos/akira_YYYYMMDD_HHMM.dump
```

Verificación de integridad mínima:

```sql
-- Debe devolver un número coherente con el entorno original
select count(*) from student;
select count(*) from payment where status = 'CONFIRMED';
select count(*) from charge;
select max(occurred_at) from audit_event;
-- Flyway debe estar en la última versión
select version, success from flyway_schema_history order by installed_rank desc limit 5;
```

Nunca restaure sobre la base productiva sin antes respaldarla y detener la aplicación.

## 5. Recuperación ante fallo

1. Detener backend/frontend para evitar escrituras.
2. Conservar el estado actual (si es posible, tome un respaldo del daño).
3. Crear una base nueva o limpiar el esquema afectado.
4. Restaurar el último respaldo verificado.
5. Verificar conteos y `flyway_schema_history`.
6. Arrancar el backend (Flyway valida el esquema) y comprobar `/actuator/health`.
7. Revisar `audit_event` del período para detectar operaciones posteriores al respaldo.
8. Comunicar a los usuarios el punto de recuperación (RPO) y las operaciones perdidas.

## 6. Prueba pendiente

La restauración completa en base separada **no se ejecutó** en este entorno. Antes de producción
debe realizarse al menos una prueba documentada de:

- creación de base de restauración,
- `pg_restore --exit-on-error`,
- verificación de conteos,
- arranque del backend contra la base restaurada,
- login y consulta de un estudiante y un pago.

Registre fecha, responsable y resultado en este documento.
