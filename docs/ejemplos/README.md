# Ejemplos de importación de estudiantes

Archivos incluidos:

- `plantilla-estudiantes.xlsx`: solo encabezados, para que la institución complete sus datos.
- `estudiantes-importacion.xlsx`: archivo de demostración con filas válidas, una fila duplicada dentro del archivo y una fila con errores.

## Columnas

| Columna | Obligatoria | Formato |
|---|---|---|
| `Nombres` | Sí | Texto, máximo 100 caracteres |
| `Apellidos` | Sí | Texto, máximo 100 caracteres |
| `Fecha de ingreso` | Sí | `AAAA-MM-DD` (también se acepta `DD/MM/AAAA`) |
| `Identificación` | No | Texto, único dentro de la institución |
| `Fecha de nacimiento` | No | `AAAA-MM-DD`, anterior a hoy |
| `Correo` | No | Correo válido |
| `Teléfono` | No | Texto |
| `Estado` | No | `PRE_REGISTERED`, `ACTIVE`, `WITHDRAWN`, `GRADUATED` |
| `Dirección` | No | Texto, máximo 250 caracteres |

También se aceptan encabezados en inglés (`First name`, `Last name`, `Admission date`,
`Document number`, `Birth date`, `Email`, `Phone`, `Status`, `Address`) y variantes como
`Nombres`, `Apellidos`, `Fecha de ingreso`, `Identificación`, `Cédula`, `Documento`, `Correo`,
`Teléfono`, `Estado` y `Dirección`. La comparación ignora mayúsculas, tildes y separadores.

## Reglas del ejemplo

- El archivo se procesa en memoria; no se almacena en disco ni se expone públicamente.
- La institución se toma del usuario autenticado, nunca de una columna del Excel.
- La vista previa no crea estudiantes. Debe confirmarse la importación.
- Las filas con errores y los duplicados no se importan.
- Los duplicados se detectan por identificación o, si no hay identificación, por nombre,
  apellido y fecha de nacimiento.
- Para actualizar estudiantes existentes se debe activar explícitamente la opción
  `allowUpdateExisting` al confirmar.
