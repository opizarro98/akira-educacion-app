# Fase 1 — Fundamentos, autenticación y configuración institucional

La Fase 0 fue revisada y aprobada. Continúa con la implementación de la Fase 1 sobre el repositorio existente.

Mantén la estructura de submódulos:

- Backend: `app/backend`
- Frontend: `app/frontend`

No crees repositorios nuevos ni reemplaces la plantilla Angular existente.

## Decisiones de negocio confirmadas

- Cada usuario pertenece únicamente a una institución.
- El MVP incluye `PLATFORM_ADMIN`.
- La autenticación utilizará JWT.
- Los recibos serán internos y no tributarios.
- La moneda inicial será USD.
- El IVA será configurable por institución, con activación, tasa y vigencia.
- Solo `INSTITUTION_ADMIN` puede anular pagos. La funcionalidad de pagos todavía no se implementará en esta fase.
- No se integrará directamente WhatsApp. En una fase posterior se utilizarán enlaces `wa.me` con mensajes preparados y revisados por el usuario.
- El desarrollo se realizará contra la base PostgreSQL local en `localhost`.
- La base externa compartida no debe utilizarse para desarrollo ni pruebas automatizadas.

## Alcance del backend

Implementa únicamente:

1. Perfiles `dev`, `test` y `prod`.
2. Configuración de PostgreSQL mediante variables de entorno.
3. Archivo `.env.example` sin secretos reales.
4. Dependencia y configuración correcta de Flyway para PostgreSQL.
5. Migración inicial del esquema.
6. API REST versionada bajo `/api/v1`.
7. Configuración base de Spring Security.
8. Autenticación mediante JWT.
9. Entidad `Institution`.
10. Entidad `AppUser`.
11. Entidades de roles y permisos.
12. `PLATFORM_ADMIN`.
13. `INSTITUTION_ADMIN`.
14. Creación y edición de instituciones.
15. Configuración institucional editable:
    - Nombre legal y comercial.
    - Identificación tributaria.
    - Datos de contacto.
    - Logo y branding.
    - País, ciudad, zona horaria e idioma.
    - Moneda.
    - Configuración de IVA.
    - Módulos habilitados.
16. Contexto institucional derivado del usuario autenticado.
17. Aislamiento entre instituciones.
18. Auditoría básica de creación y modificación de instituciones, usuarios, roles y configuración.
19. Manejo uniforme de errores mediante `ProblemDetail` o una estructura equivalente.
20. DTOs, validaciones, paginación cuando sea necesario y documentación OpenAPI si resulta compatible con Spring Boot 4.1.1.

No implementes todavía estudiantes, representantes, matrículas, obligaciones, pagos, egresos, comunicaciones ni reportes.

## Reglas de seguridad

- No confíes en un `institutionId` enviado por el frontend.
- El usuario normal solo puede acceder a su institución.
- `PLATFORM_ADMIN` puede administrar instituciones mediante operaciones explícitas y auditadas.
- No expongas contraseñas, tokens ni secretos en logs.
- No almacenes contraseñas en texto plano.
- No permitas que un usuario de una institución consulte datos de otra.
- Usa `ddl-auto=validate` como configuración objetivo.
- Si necesitas utilizar `ddl-auto=update` temporalmente en desarrollo, justifícalo y configúralo únicamente en el perfil `dev`; no lo uses en `test` ni `prod`.
- Las migraciones oficiales deben gestionarse con Flyway.

## Alcance del frontend

Adapta la plantilla existente sin reemplazarla:

1. Configura la URL base de la API.
2. Prepara `HttpClient`.
3. Agrega interceptor para JWT.
4. Agrega interceptor para errores HTTP.
5. Implementa rutas de autenticación.
6. Implementa login conectado al backend.
7. Agrega guards para rutas protegidas.
8. Prepara el manejo de sesión.
9. Crea el layout inicial para `PLATFORM_ADMIN` e `INSTITUTION_ADMIN`.
10. Retira de la navegación los elementos demo que interfieran.
11. Conserva los estilos y componentes reutilizables de Berry.
12. No implementes aún los módulos de estudiantes, matrículas o pagos.

## Git y submódulos

Antes de modificar archivos:

1. Revisa el estado del repositorio principal.
2. Revisa el estado de `app/backend`.
3. Revisa el estado de `app/frontend`.
4. Conserva los cambios locales existentes.
5. No hagas commits automáticos sin informar los cambios.
6. No actualices la referencia del submódulo principal sin revisar primero los cambios realizados dentro del submódulo.

## Pruebas obligatorias

Implementa y ejecuta pruebas para:

1. Login exitoso.
2. Login fallido.
3. Contraseña no almacenada en texto plano.
4. Acceso autorizado de `INSTITUTION_ADMIN`.
5. Rechazo de acceso entre instituciones.
6. Acceso global controlado de `PLATFORM_ADMIN`.
7. Creación y edición de una institución.
8. Configuración de IVA.
9. Auditoría de cambios institucionales.
10. Expiración o rechazo de un JWT inválido.

Usa la base local para desarrollo. Para pruebas automatizadas utiliza una base aislada o Testcontainers cuando Docker esté disponible. No utilices la base externa compartida.

## Resultado esperado

Al terminar, entrega:

- Resumen de la implementación.
- Archivos creados y modificados.
- Migraciones Flyway agregadas.
- Endpoints disponibles.
- Usuarios de prueba creados, sin revelar contraseñas reales.
- Comandos ejecutados.
- Resultado real de compilaciones y pruebas.
- Problemas encontrados.
- Cambios pendientes.
- Confirmación de que no se utilizó la base externa compartida.
