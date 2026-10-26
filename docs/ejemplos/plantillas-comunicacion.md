# Plantillas de comunicación incluidas

Las plantillas se crean por institución con `POST /api/v1/communications/templates`.
En el perfil `dev` también se siembran automáticamente para la institución demo.

## Marcadores disponibles

| Marcador | Valor |
|---|---|
| `{{estudiante}}` | Apellidos, nombres del estudiante |
| `{{representante}}` | Nombre completo del representante |
| `{{institucion}}` | Nombre comercial o legal de la institución |
| `{{fecha}}` | Fecha actual en la zona horaria de la institución |
| `{{detalle_financiero}}` | Texto financiero confirmado por el usuario; vacío si no se incluye |

Los marcadores desconocidos se rechazan con `400`.

## Recordatorio de pago

```json
{
  "code": "PAGO",
  "name": "Recordatorio de pago",
  "body": "Estimado/a {{representante}}:\n\nLe recordamos que {{estudiante}} tiene una obligación pendiente en {{institucion}}.\n\n{{detalle_financiero}}\n\nFecha: {{fecha}}",
  "active": true
}
```

Para incluir el detalle financiero, la petición de vista previa debe enviar
`"includeFinancialInfo": true` y un `financialNote` no vacío. El mensaje exacto se devuelve en
`messageBody` antes de abrir WhatsApp.

## Citación general

```json
{
  "code": "CITACION",
  "name": "Citación general",
  "body": "Estimado/a {{representante}}:\n\nNos comunicamos de {{institucion}} para conversar sobre {{estudiante}}.\nPor favor, responda a este mensaje para coordinar una reunión.\n\nFecha: {{fecha}}",
  "active": true
}
```

## Bienvenida

```json
{
  "code": "BIENVENIDA",
  "name": "Bienvenida",
  "body": "Hola {{representante}}:\n\nBienvenido/a a {{institucion}}. {{estudiante}} ya forma parte de nuestra comunidad educativa.\n\nFecha: {{fecha}}",
  "active": true
}
```

## Vista previa

```json
{
  "studentId": "UUID del estudiante",
  "representativeId": "UUID del representante",
  "templateId": "UUID de la plantilla",
  "includeFinancialInfo": false,
  "financialNote": null
}
```

Respuesta relevante:

```json
{
  "messageBody": "Estimado/a María Pérez:\n\n...",
  "waPhone": "593999999999",
  "waLink": "https://wa.me/593999999999?text=...",
  "warnings": [
    "El enlace wa.me abre WhatsApp, pero no confirma el envío ni la entrega del mensaje."
  ]
}
```

El estado `OPENED` significa únicamente que el usuario abrió el enlace. No debe interpretarse
como entrega o lectura del mensaje.
