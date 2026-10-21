# Prompt optimizado: plataforma modular de gestión escolar multiinstitución

## 1. Rol y objetivo

Actúa como arquitecto de software y desarrollador full-stack senior especializado en Java, Spring Boot, Angular, PostgreSQL, seguridad y plataformas SaaS multiinstitución.

Diseña y desarrolla un MVP funcional, mantenible y verificable para la gestión administrativa y financiera de instituciones educativas. El primer cliente piloto es **Cukitos**, institución particular de Ecuador con menos de 100 estudiantes. La solución debe poder reutilizarse con otras instituciones sin crear una aplicación distinta para cada una.

No entregues prototipos estáticos ni código de ejemplo desconectado. Toda funcionalidad declarada como implementada debe incluir persistencia, validaciones, autorización, manejo de errores, pruebas y documentación proporcional. Si algo no está implementado o no pudo verificarse, decláralo explícitamente.

## 2. Stack y restricciones técnicas

- Backend: Java + Spring Boot.
- API: REST versionada bajo `/api/v1`.
- Frontend: Angular + TypeScript.
- Base de datos: PostgreSQL.
- Persistencia: Spring Data JPA/Hibernate.
- Seguridad: Spring Security.
- Migraciones: Flyway.
- Validaciones: Bean Validation.
- Pruebas: JUnit, Spring Boot Test y Testcontainers cuando el entorno lo permita.
- Documentación: OpenAPI/Swagger.
- Ejecución reproducible: Docker Compose.
- Control de versiones: Git.

Usa versiones estables y compatibles, verifica las versiones disponibles antes de crear el proyecto y documenta la decisión. Evita librerías innecesarias, microservicios y sobreingeniería: el MVP será un monolito modular.

No uses `ddl-auto=update` en producción. No uses `float` ni `double` para dinero: usa `NUMERIC` en PostgreSQL y `BigDecimal` en Java.

## 2.1. Estado actual del repositorio y punto de partida

El desarrollo ya cuenta con un repositorio principal preparado para trabajar con submódulos Git. No crees repositorios nuevos ni cambies esta estrategia.

La estructura esperada es:

```text
app/
├── backend/    # repositorio del backend
└── frontend/   # repositorio del frontend
```

Antes de modificar archivos:

1. Inspecciona el repositorio principal, sus submódulos, ramas, archivos de configuración y estado de Git.
2. Confirma que `app/backend` y `app/frontend` existen y que cada uno corresponde al repositorio esperado.
3. Lee los `README`, `package.json`, archivos de configuración, scripts disponibles y estructura de módulos.
4. Ejecuta las pruebas, compilaciones o comandos de verificación existentes antes de hacer cambios, cuando sea posible.
5. No borres, reemplaces ni reinicialices repositorios, submódulos, configuraciones o archivos existentes sin justificarlo y solicitar confirmación si la acción puede ser destructiva.
6. Respeta la plantilla visual ya instalada en `app/frontend`. No la reemplaces por otra plantilla: adáptala progresivamente para construir las pantallas del sistema.
7. Mantén separadas las responsabilidades: el backend debe permanecer en `app/backend` y el frontend en `app/frontend`.
8. Después de cada cambio importante, indica los archivos modificados, los comandos ejecutados y el resultado real.

### Versiones y tecnologías ya seleccionadas

No cambies estas versiones sin verificar compatibilidad y explicar el motivo:

- Frontend: Angular 22.
- Lenguaje frontend: TypeScript 6.0.3.
- Estilos y componentes: Bootstrap 5.3.8.
- Componentes Bootstrap para Angular: `@ng-bootstrap/ng-bootstrap`.
- Gráficos: ApexCharts 5.13.0 mediante `ng-apexcharts`.
- Backend: Java 25.
- Framework backend: Spring Boot 4.1.1.

Angular será la base de componentes, páginas, formularios, rutas y navegación. Bootstrap será la base visual y responsive. ApexCharts se utilizará para indicadores y gráficos del dashboard cuando el módulo correspondiente se implemente.

Antes de agregar una dependencia, verifica si la plantilla o el proyecto ya ofrece una solución equivalente. No agregues librerías duplicadas ni actualices versiones automáticamente. Si detectas una incompatibilidad entre versiones, detén la implementación afectada, documenta el problema y presenta alternativas antes de cambiar el stack.

## 3. Arquitectura y aislamiento multiinstitución

Organiza el monolito por módulos: `identity`, `institution`, `configuration`, `students`, `catalog`, `enrollment`, `billing`, `payments`, `finance`, `communications`, `reporting` y `audit`.

La aplicación debe garantizar aislamiento entre instituciones en backend, consultas, servicios, relaciones y base de datos. Nunca uses un `institutionId` enviado por el frontend para autorizar acceso. El contexto institucional debe derivarse de la sesión autenticada o de una operación explícita de un usuario de plataforma autorizado.

Cada registro de negocio debe pertenecer a una institución cuando corresponda. Usa `institution_id`, claves foráneas y restricciones de integridad suficientes para impedir referencias cruzadas entre instituciones. Todas las operaciones críticas deben quedar auditadas.

### Roles mínimos

- `PLATFORM_ADMIN`: administra instituciones y configuraciones globales; opcional para el MVP si no se requiere un panel central.
- `INSTITUTION_ADMIN`: administra la institución, usuarios, roles, módulos y configuración de su institución.
- `SECRETARY`: estudiantes, representantes, matrículas y operaciones autorizadas.
- `TREASURY`: obligaciones, cobros, pagos y operaciones financieras autorizadas.
- `DIRECTOR`: consulta información y reportes y ejecuta únicamente acciones autorizadas.

Un usuario puede tener varios roles. Define permisos de forma explícita y comprueba siempre el alcance institucional.

## 4. Configuración y edición de la institución

El sistema debe permitir que una institución configure sus datos sin modificar código ni base de datos manualmente. Implementa una entidad `Institution` y una pantalla protegida de administración institucional.

Como mínimo, debe poder editarse:

- Nombre legal y nombre comercial.
- Identificación tributaria, si aplica.
- Logo, colores y datos de contacto.
- Dirección, teléfono, correo y sitio web.
- País, ciudad, zona horaria, idioma y moneda.
- Formato y prefijo de numeración de recibos.
- Datos que aparecerán en recibos internos y reportes.
- Configuración de módulos habilitados.
- Niveles, períodos, planes, servicios, tarifas, frecuencias y reglas de cobro.
- Datos del usuario administrador y usuarios de la institución.

Separa claramente:

1. **Configuración global de plataforma**, administrada por `PLATFORM_ADMIN`.
2. **Configuración propia de una institución**, administrada por `INSTITUTION_ADMIN`.
3. **Datos históricos**, que no deben cambiar retroactivamente por editar la configuración actual.

Los documentos históricos deben guardar instantáneas de nombre, identificación, dirección, moneda, conceptos y precios utilizados en el momento de la operación. Los cambios de logo, nombre o tarifas no deben alterar recibos, obligaciones, pagos ni matrículas ya confirmados.

El diseño debe permitir agregar una nueva institución mediante un flujo de alta, asignar su administrador y cargar su configuración inicial. No incluyas datos de Cukitos codificados en el sistema: usa datos semilla o configuración editable.

## 5. Alcance funcional del MVP

Prioriza estas capacidades:

### 5.1 Estudiantes y representantes

- Crear, editar, consultar y buscar estudiantes.
- Fecha de ingreso obligatoria; fecha de nacimiento opcional.
- Estados: `PRE_REGISTERED`, `ACTIVE`, `WITHDRAWN`, `GRADUATED`.
- Historial de matrículas y observaciones con permisos.
- Registrar representantes y relaciones muchos-a-muchos con estudiantes.
- Definir contacto principal y contactos autorizados para comunicaciones o cobros.
- Importar estudiantes desde Excel con prevalidación, detección de duplicados, vista previa y reporte de errores.
- No borrar físicamente estudiantes con matrículas, obligaciones o pagos.

### 5.2 Configuración académica, catálogo y matrículas

Cada institución debe poder configurar niveles, períodos lectivos opcionales, modalidades de ingreso, planes, servicios, tarifas, vigencias, frecuencias, fechas de emisión/vencimiento y conceptos obligatorios u opcionales.

Admite tanto:

- Matrículas vinculadas a un período lectivo.
- Ingresos continuos sin período lectivo obligatorio.

Modela separadamente planes, servicios, servicios incluidos, servicios adicionales, tarifas vigentes y contrataciones por estudiante. Nunca codifiques precios en Angular o en reglas fijas del backend.

Una matrícula debe registrar estudiante, nivel, plan, servicios, inicio, finalización opcional, período opcional, estado, precio acordado e historial de cambios/cancelaciones. Al confirmarse, debe poder generar conceptos iniciales sin duplicarlos si la petición se reintenta.

Debe existir un mecanismo de ajuste manual para el primer cobro cuando no exista una regla automática confirmada. Guarda usuario, fecha, importe original, importe final y motivo.

### 5.3 Obligaciones, pagos y recibos

Implementa obligaciones por matrícula, pensiones, materiales, matrícula anual, servicios adicionales y otros conceptos configurables. Registra conceptos, cantidades, precios unitarios, total, emisión, vencimiento, estado y saldo.

Estados mínimos: `PENDING`, `PARTIAL`, `PAID`, `VOID`.

Implementa pagos en efectivo, transferencia y medios configurables; referencia, fecha de recepción, estado de verificación, aplicaciones a una o varias obligaciones, pagos parciales, recibos internos y anulaciones autorizadas.

Una transferencia puede quedar `PENDING_VERIFICATION`; solo una transferencia confirmada cuenta como dinero recibido. La recepción, confirmación y aplicación deben ser transaccionales. Impide que:

- Un pago o una obligación tenga importe inválido.
- Las aplicaciones superen el pago recibido.
- Las aplicaciones superen el saldo de cada obligación.
- Una operación duplicada genere cobros o recibos duplicados.
- Se eliminen físicamente pagos confirmados.

Los números de recibo deben ser únicos por institución. Los recibos internos no deben presentarse como facturas tributarias autorizadas.

### 5.4 Egresos, caja, comunicaciones y reportes

Implementa registro de egresos con categoría, fecha, importe, descripción, medio de pago y responsable. Distingue obligaciones generadas de dinero realmente recibido y evita registrar como ingreso manual pagos escolares ya registrados.

Incluye comunicaciones asistidas: plantillas, recordatorios, selección de contactos autorizados, vista previa y registro del resultado. No simules WhatsApp ni otra integración no implementada; deja una interfaz preparada para un proveedor oficial.

Dashboard y reportes mínimos:

- Estudiantes activos.
- Matrículas.
- Obligaciones pendientes y vencidas.
- Cobros por período y medio de pago.
- Egresos por período.
- Resumen de caja.
- Pagos por usuario y medio de pago.

Todos los reportes deben definir su período, separar devengado de cobrado y conciliar con operaciones confirmadas y anulaciones.

## 6. Modelo mínimo de datos

Incluye, como mínimo: `Institution`, `AppUser`, `Role`, `UserRole`, `InstitutionModule`, `AcademicPeriod`, `EducationLevel`, `Student`, `Representative`, `StudentRepresentative`, `Service`, `Plan`, `PlanService`, `Tariff`, `Enrollment`, `Charge`, `ChargeItem`, `Payment`, `PaymentAllocation`, `Expense`, `CashMovement`, `Communication`, `AuditEvent`.

Agrega entidades para reglas de facturación, configuración institucional y numeración cuando sean necesarias. Documenta relaciones, restricciones, índices, estrategia de aislamiento y migraciones Flyway.

## 7. API, frontend y seguridad

La API debe usar DTOs, validaciones, paginación, filtros, ordenamiento, códigos HTTP y errores consistentes. No expongas entidades JPA directamente. El servidor debe establecer automáticamente usuario responsable, institución, fechas y campos sensibles.

El frontend debe incluir login, dashboard, navegación lateral, rutas protegidas, listados, filtros, formularios reactivos, estados de carga/error/éxito, confirmaciones, paginación, expediente del estudiante, historial de matrículas/pagos y consulta/impresión de recibos.

Usa hashing seguro de contraseñas, gestión de secretos mediante variables de entorno, errores que no filtren información sensible, logs sin datos innecesarios de menores y auditoría de operaciones financieras. Documenta copias de seguridad y recuperación. Usa únicamente datos ficticios en pruebas y demostraciones.

## 8. Pruebas de aceptación mínimas

Prueba, como mínimo:

1. Creación de estudiante y representantes.
2. Matrícula con y sin período lectivo.
3. Configuración y edición de una institución por su administrador.
4. Alta de una segunda institución y aislamiento de sus datos.
5. Cambio de tarifa sin alterar cobros históricos.
6. Generación de obligación y cálculo de saldo.
7. Pago parcial y pago aplicado a varias obligaciones.
8. Rechazo de aplicaciones superiores al pago o al saldo.
9. Confirmación y anulación de transferencias.
10. Unicidad de recibos y protección contra reintentos.
11. Permisos por rol y protección de endpoints.
12. Conciliación de reportes después de anulaciones.

Ejecuta las pruebas y documenta el resultado real. Nunca declares una prueba aprobada si no fue ejecutada.

## 9. Trabajo por fases

No intentes construir todo en una sola operación.

### Fase 0 — análisis

Inspecciona el repositorio principal, sus submódulos y el entorno existentes. Parte del código actual; no inicialices proyectos nuevos. Verifica específicamente `app/backend` y `app/frontend`, la plantilla Angular instalada, el estado de Git y la forma correcta de ejecutar ambos proyectos. No sobrescribas archivos sin necesidad. Entrega únicamente:

- Arquitectura propuesta.
- Estructura de carpetas.
- Modelo entidad-relación.
- Decisiones técnicas.
- Riesgos, ambigüedades y preguntas de negocio.
- Plan de implementación por fases.
- Lista de supuestos explícitos.

No implementes todavía toda la aplicación y no inventes reglas de negocio importantes.

### Fase 1 — fundamentos

Proyecto base, Docker Compose, PostgreSQL, Flyway, autenticación, instituciones, usuarios, roles, permisos y configuración institucional.

### Fase 2 — gestión escolar

Estudiantes, representantes, niveles, períodos, catálogo y matrículas.

### Fase 3 — cobros

Obligaciones, conceptos, pagos, aplicaciones, recibos, confirmaciones y anulaciones.

### Fase 4 — finanzas y reportes

Egresos, movimientos de caja, dashboard y reportes.

### Fase 5 — comunicaciones, importación y despliegue

Importación de Excel, comunicaciones asistidas, validación funcional y documentación de despliegue.

Al terminar cada fase, resume archivos y funcionalidades, ejecuta pruebas, registra comandos y resultados, corrige errores e indica lo pendiente. Solicita confirmación antes de avanzar cuando exista una decisión de negocio no resuelta.

## 10. Entregables

Código backend y frontend, migraciones Flyway, Docker Compose, `.env.example`, datos ficticios, pruebas automatizadas, documentación de arquitectura, diagrama ER, OpenAPI, instrucciones desde cero, guía de configuración de una institución, guía de importación Excel, lista de funcionalidades implementadas/pendientes/limitaciones y resultados reales de las pruebas.

## Primera tarea

Comienza exclusivamente por la **Fase 0** sobre el repositorio existente. Inspecciona el repositorio principal, sus submódulos, `app/backend`, `app/frontend`, la plantilla Angular y los comandos disponibles. Ejecuta únicamente verificaciones no destructivas. No escribas todavía funcionalidades de negocio ni reemplaces la plantilla.

Presenta después:

- Estado actual del backend y frontend.
- Comandos confirmados para instalar, ejecutar y probar cada aplicación.
- Estructura relevante existente.
- Compatibilidad verificada de Java 25, Spring Boot 4.1.1, Angular 22, TypeScript 6.0.3, Bootstrap 5.3.8, `@ng-bootstrap/ng-bootstrap`, ApexCharts 5.13.0 y `ng-apexcharts`.
- Arquitectura propuesta adaptada al código actual.
- Modelo entidad-relación inicial.
- Plan de implementación por fases.
- Riesgos, incompatibilidades, supuestos y decisiones que requieren confirmación.

No declares que una aplicación compila, inicia o que una prueba pasa si no ejecutaste el comando correspondiente. El objetivo es evolucionar el código existente hacia un MVP seguro, mantenible, verificable y reutilizable para múltiples instituciones, no reemplazarlo por un prototipo nuevo.
