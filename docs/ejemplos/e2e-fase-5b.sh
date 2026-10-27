#!/usr/bin/env bash
# Prueba funcional de extremo a extremo de la Fase 5B (nivel API real).
# Requiere el backend en ejecución y una base PostgreSQL accesible.
#
# Uso:
#   BASE_URL=http://localhost:8090/api/v1 bash docs/ejemplos/e2e-fase-5b.sh
#
# No sustituye la verificación visual del frontend: los pasos que en la
# interfaz son clics (seleccionar institución, abrir wa.me) aquí se ejercitan
# contra el mismo endpoint que usa la pantalla.

set -uo pipefail

BASE="${BASE_URL:-http://localhost:8090/api/v1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXCEL="$ROOT_DIR/docs/ejemplos/estudiantes-importacion.xlsx"
TODAY="$(date +%F)"
SUFFIX="$(date +%s)"
PASS=0
FAIL=0
BODY=""
CODE=""

say() { printf '\n%s\n' "$*"; }
ok() { PASS=$((PASS + 1)); printf '  OK   %s\n' "$*"; }
bad() {
  FAIL=$((FAIL + 1))
  printf '  FALLO %s (HTTP %s) %s\n' "$1" "$2" "${3:0:400}"
}
field() { printf '%s' "$BODY" | jq -r "$1"; }

call() {
  local method="$1" path="$2" token="${3:-}" body="${4:-}"
  local args=(-s -m 30 -w '\n%{http_code}' -X "$method" "$BASE$path")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' -d "$body")
  fi
  curl "${args[@]}"
}

expect() {
  local method="$1" path="$2" token="$3" body="$4" expected="$5" label="$6"
  local raw
  raw="$(call "$method" "$path" "$token" "$body")"
  CODE="${raw##*$'\n'}"
  BODY="${raw%$'\n'*}"
  if [ "$CODE" = "$expected" ]; then
    ok "$label"
    return 0
  fi
  bad "$label" "$CODE" "$BODY"
  return 1
}

upload() {
  local path="$1" token="$2" file="$3" expected="$4" label="$5"
  local raw
  raw="$(curl -s -m 60 -w '\n%{http_code}' -X POST "$BASE$path" \
    -H "Authorization: Bearer $token" -F "file=@$file")"
  CODE="${raw##*$'\n'}"
  BODY="${raw%$'\n'*}"
  if [ "$CODE" = "$expected" ]; then
    ok "$label"
  else
    bad "$label" "$CODE" "$BODY"
  fi
}

say "== 1-2. Login PLATFORM_ADMIN y contexto global =="
expect POST /auth/login "" '{"email":"admin@akira.local","password":"Admin1234!"}' 200 "Login PLATFORM_ADMIN"
PTOKEN="$(field .accessToken)"
[ -n "$PTOKEN" ] && [ "$PTOKEN" != "null" ] && ok "Token de plataforma emitido" || bad "Token de plataforma" "$CODE" "$BODY"

INST_A_JSON="{\"legalName\":\"Colegio E2E A $SUFFIX\",\"country\":\"Ecuador\",\"timezone\":\"America/Guayaquil\",\"language\":\"es\",\"currency\":\"USD\",\"admin\":{\"email\":\"admin.a.$SUFFIX@test.local\",\"fullName\":\"Admin A\",\"password\":\"E2eClave123!\"}}"
expect POST /institutions "$PTOKEN" "$INST_A_JSON" 201 "Crear institución A con administrador"
INST_A="$(field .id)"

INST_B_JSON="{\"legalName\":\"Colegio E2E B $SUFFIX\",\"country\":\"Ecuador\",\"timezone\":\"America/Guayaquil\",\"language\":\"es\",\"currency\":\"USD\",\"admin\":{\"email\":\"admin.b.$SUFFIX@test.local\",\"fullName\":\"Admin B\",\"password\":\"E2eClave123!\"}}"
expect POST /institutions "$PTOKEN" "$INST_B_JSON" 201 "Crear institución B con administrador"
INST_B="$(field .id)"

expect GET "/users?institutionId=$INST_A" "$PTOKEN" "" 200 "PLATFORM_ADMIN lista usuarios con contexto explícito"
expect GET "/users" "$PTOKEN" "" 400 "PLATFORM_ADMIN sin contexto es rechazado"

say "== 3. Login INSTITUTION_ADMIN =="
expect POST /auth/login "" "{\"email\":\"admin.a.$SUFFIX@test.local\",\"password\":\"E2eClave123!\"}" 200 "Login administrador institucional A"
TOKEN="$(field .accessToken)"

say "== 4-5. Estudiante y representante autorizado =="
expect POST /students "$TOKEN" "{\"firstName\":\"Ana\",\"lastName\":\"E2E\",\"documentNumber\":\"E2E$SUFFIX\",\"admissionDate\":\"$TODAY\",\"status\":\"ACTIVE\"}" 201 "Crear estudiante"
STUDENT="$(field .id)"

expect POST /representatives "$TOKEN" "{\"fullName\":\"María E2E\",\"documentNumber\":\"REP$SUFFIX\",\"phone\":\"0999999999\",\"email\":\"rep.$SUFFIX@test.local\",\"relationship\":\"Madre\"}" 201 "Crear representante"
REP="$(field .id)"

expect POST "/students/$STUDENT/representatives" "$TOKEN" "{\"representativeId\":\"$REP\",\"primaryContact\":true,\"authorizedForCommunications\":true,\"authorizedForBilling\":false}" 201 "Vincular representante autorizado"

say "== 6-7. Matrícula y obligación =="
expect POST /catalog/levels "$TOKEN" '{"name":"Nivel E2E","code":"L-E2E","sortOrder":1}' 201 "Crear nivel"
LEVEL="$(field .id)"
expect POST /catalog/periods "$TOKEN" '{"name":"Periodo E2E","startDate":"2026-03-01","endDate":"2026-12-15"}' 201 "Crear período"
PERIOD="$(field .id)"
expect POST /catalog/services "$TOKEN" '{"name":"Colegiatura E2E","code":"SRV-E2E"}' 201 "Crear servicio"
SERVICE="$(field .id)"
expect POST /catalog/rates "$TOKEN" "{\"serviceId\":\"$SERVICE\",\"amount\":100.00,\"validFrom\":\"2026-01-01\"}" 201 "Crear tarifa"
expect POST /catalog/plans "$TOKEN" "{\"name\":\"Plan E2E\",\"description\":\"Plan de prueba\",\"serviceIds\":[\"$SERVICE\"]}" 201 "Crear plan"
PLAN="$(field .id)"

expect POST /enrollments "$TOKEN" "{\"studentId\":\"$STUDENT\",\"educationalLevelId\":\"$LEVEL\",\"planId\":\"$PLAN\",\"academicPeriodId\":\"$PERIOD\",\"startDate\":\"2026-03-01\",\"agreedPrice\":100.00,\"services\":[]}" 201 "Crear matrícula"
ENROLLMENT="$(field .id)"
expect POST "/enrollments/$ENROLLMENT/confirm" "$TOKEN" "" 200 "Confirmar matrícula"

expect POST "/billing/charges/from-enrollment/$ENROLLMENT" "$TOKEN" "{}" 200 "Generar obligación inicial"
CHARGE="$(field .id)"
CHARGE_TOTAL="$(field '.items | map(.total) | add')"
if [ "$CHARGE_TOTAL" = "100" ] || [ "$CHARGE_TOTAL" = "100.00" ]; then
  ok "Obligación por 100.00 (total=$CHARGE_TOTAL)"
else
  bad "Total de obligación inesperado" "$CODE" "$CHARGE_TOTAL"
fi

say "== 8-10. Pago, aplicación y recibo =="
expect POST /billing/payments "$TOKEN" "{\"studentId\":\"$STUDENT\",\"amount\":100.00,\"method\":\"BANK_TRANSFER\",\"reference\":\"TRF-E2E\",\"receivedDate\":\"$TODAY\"}" 201 "Registrar pago por transferencia (pendiente)"
PAYMENT="$(field .id)"
expect POST "/billing/payments/$PAYMENT/confirm" "$TOKEN" "" 200 "Confirmar pago"
expect POST "/billing/payments/$PAYMENT/allocations" "$TOKEN" "{\"allocations\":[{\"chargeId\":\"$CHARGE\",\"amount\":100.00}]}" 200 "Aplicar pago a la obligación"
expect GET "/billing/receipts/by-payment/$PAYMENT" "$TOKEN" "" 200 "Consultar recibo interno"
RECEIPT="$(field .receiptNumber)"
[ -n "$RECEIPT" ] && [ "$RECEIPT" != "null" ] && ok "Recibo emitido: $RECEIPT" || bad "Recibo sin número" "$CODE" "$BODY"

say "== 11-13. Egreso, confirmación y caja =="
expect POST /finance/expense-categories "$TOKEN" '{"code":"CAT-E2E","name":"Egreso E2E","description":"Categoría de prueba","active":true}' 201 "Crear categoría de egreso"
CATEGORY="$(field .id)"
expect POST /finance/expenses "$TOKEN" "{\"categoryId\":\"$CATEGORY\",\"amount\":25.00,\"expenseDate\":\"$TODAY\",\"description\":\"Compra E2E\",\"method\":\"CASH\",\"beneficiary\":\"Proveedor E2E\",\"reference\":\"FAC-E2E\"}" 201 "Registrar egreso"
EXPENSE="$(field .id)"
expect POST "/finance/expenses/$EXPENSE/confirm" "$TOKEN" "" 200 "Confirmar egreso"
expect GET "/finance/cash-movements?from=2026-01-01&to=2026-12-31" "$TOKEN" "" 200 "Consultar movimientos de caja"

say "== 14-15. Comunicación asistida y wa.me =="
expect POST /communications/templates "$TOKEN" '{"code":"TPL-E2E","name":"Plantilla E2E","body":"Hola {estudiante}, somos {institucion}.","active":true}' 201 "Crear plantilla de mensaje"
TEMPLATE="$(field .id)"
expect POST /communications/preview "$TOKEN" "{\"studentId\":\"$STUDENT\",\"representativeId\":\"$REP\",\"templateId\":\"$TEMPLATE\",\"includeFinancialInfo\":false}" 200 "Vista previa de comunicación"
WALINK="$(field .waLink)"
case "$WALINK" in
  https://wa.me/593999999999*) ok "Enlace wa.me generado: $WALINK" ;;
  *) bad "Enlace wa.me inválido" "$CODE" "$WALINK" ;;
esac
expect POST /communications "$TOKEN" "{\"studentId\":\"$STUDENT\",\"representativeId\":\"$REP\",\"templateId\":\"$TEMPLATE\",\"includeFinancialInfo\":false,\"saveAsDraft\":false}" 201 "Registrar comunicación preparada"
COMMUNICATION="$(field .id)"
expect POST "/communications/$COMMUNICATION/opened" "$TOKEN" "" 200 "Registrar apertura del enlace (no confirma envío)"

say "== 16-18. Importación de estudiantes =="
expect GET /students "$TOKEN" "" 200 "Conteo previo de estudiantes"
BEFORE="$(field .totalElements)"
upload /imports/students/preview "$TOKEN" "$EXCEL" 201 "Vista previa de Excel sin persistir"
IMPORT="$(field .id)"
expect GET /students "$TOKEN" "" 200 "El conteo no cambia tras la vista previa"
AFTER_PREVIEW="$(field .totalElements)"
[ "$AFTER_PREVIEW" = "$BEFORE" ] && ok "Vista previa no persiste ($BEFORE estudiantes)" || bad "La vista previa persistió datos" "$CODE" "$BEFORE -> $AFTER_PREVIEW"

upload /imports/students/preview "$TOKEN" "$EXCEL" 201 "Segunda vista previa para detectar duplicados internos"
DUPES="$(field .duplicateRows)"
[ "$DUPES" -gt 0 ] && ok "Duplicados detectados en el archivo: $DUPES" || bad "Sin duplicados internos detectados" "$CODE" "$BODY"
IMPORT2="$(field .id)"

expect POST "/imports/students/$IMPORT/confirm" "$TOKEN" '{"allowUpdateExisting":false}' 200 "Confirmar importación (con duplicados contra existentes)"
expect POST "/imports/students/$IMPORT/confirm" "$TOKEN" '{"allowUpdateExisting":false}' 200 "Reintentar la confirmación es idempotente"
expect POST "/imports/students/$IMPORT2/confirm" "$TOKEN" '{"allowUpdateExisting":false}' 200 "Confirmar lote con duplicados internos"

say "== 19. Dashboard y reportes =="
expect GET /finance/dashboard "$TOKEN" "" 200 "Consultar dashboard"
expect GET "/finance/reports/outstanding?from=2026-01-01&to=2026-12-31" "$TOKEN" "" 200 "Reporte de saldos pendientes"
expect GET "/finance/reports/cash-summary" "$TOKEN" "" 200 "Resumen de caja"

say "== 20. Aislamiento entre instituciones =="
expect POST /auth/login "" "{\"email\":\"admin.b.$SUFFIX@test.local\",\"password\":\"E2eClave123!\"}" 200 "Login administrador institucional B"
TOKEN_B="$(field .accessToken)"
expect GET "/students/$STUDENT" "$TOKEN_B" "" 404 "Institución B no puede ver el estudiante de A"
expect GET "/students/$STUDENT?institutionId=$INST_A" "$TOKEN_B" "" 403 "Institución B no puede forzar el contexto de A"

say "== Permisos por rol =="
expect POST /users "$TOKEN" "{\"email\":\"director.$SUFFIX@test.local\",\"fullName\":\"Director E2E\",\"password\":\"E2eClave123!\",\"roles\":[\"DIRECTOR\"]}" 201 "Crear usuario DIRECTOR"
expect POST /auth/login "" "{\"email\":\"director.$SUFFIX@test.local\",\"password\":\"E2eClave123!\"}" 200 "Login DIRECTOR"
TOKEN_DIR="$(field .accessToken)"
expect POST /finance/expenses "$TOKEN_DIR" "{\"categoryId\":\"$CATEGORY\",\"amount\":10.00,\"expenseDate\":\"$TODAY\",\"description\":\"No autorizado\",\"method\":\"CASH\",\"beneficiary\":\"X\",\"reference\":null}" 403 "DIRECTOR no puede registrar egresos"

say "== Desactivación de usuario =="
expect POST /users "$TOKEN" "{\"email\":\"temporal.$SUFFIX@test.local\",\"fullName\":\"Temporal E2E\",\"password\":\"E2eClave123!\",\"roles\":[\"SECRETARY\"]}" 201 "Crear usuario temporal"
TEMP_USER="$(field .id)"
expect POST /auth/login "" "{\"email\":\"temporal.$SUFFIX@test.local\",\"password\":\"E2eClave123!\"}" 200 "Login usuario temporal"
TEMP_TOKEN="$(field .accessToken)"
expect PATCH "/users/$TEMP_USER/status" "$TOKEN" '{"active":false}' 200 "Desactivar usuario"
expect GET /auth/me "$TEMP_TOKEN" "" 401 "Token del usuario desactivado queda invalidado"
expect POST /auth/login "" "{\"email\":\"temporal.$SUFFIX@test.local\",\"password\":\"E2eClave123!\"}" 401 "Usuario desactivado no puede iniciar sesión"

printf '\n=============================================\n'
printf 'Resultado E2E: %d correctos, %d fallidos\n' "$PASS" "$FAIL"
printf 'Institución A: %s\nInstitución B: %s\n' "$INST_A" "$INST_B"
printf '=============================================\n'

[ "$FAIL" -eq 0 ]
