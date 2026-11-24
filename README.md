# Gestor de tareas local (SQLite + Drift)

Aplicación Flutter que administra tareas en una base de datos **SQLite local**,
sin servidor, sin MySQL y sin conexión a internet. El mismo código está
diseñado para Android, iOS, Windows, Linux, macOS y web.

## Tecnología de persistencia elegida

| Paquete | Versión | Para qué se usa |
|---|---|---|
| [`drift`](https://pub.dev/packages/drift) | 2.35.x | ORM/consultas tipadas sobre SQLite, consultas reactivas (`Stream`). |
| [`drift_flutter`](https://pub.dev/packages/drift_flutter) | 0.3.x | Abre la base en la ubicación correcta de cada plataforma (`driftDatabase(...)`), incluida la web con WebAssembly. |
| [`drift_dev`](https://pub.dev/packages/drift_dev) (dev) | 2.35.x | Generador de código de Drift (tablas, data classes, companions). |
| [`build_runner`](https://pub.dev/packages/build_runner) (dev) | 2.x | Ejecuta el generador: `dart run build_runner build`. |

**¿Por qué Drift y no `sqflite`?** `sqflite` solo funciona en Android, iOS y
macOS; en Windows/Linux necesita `sqflite_common_ffi` y en web otra
implementación distinta. Drift + `drift_flutter` usa el paquete `sqlite3`
(FFI en plataformas nativas y `sqlite3.wasm` en el navegador), así que **una
sola base de código** cubre las seis plataformas. Además da consultas con tipos
verificados en compilación y consultas reactivas para refrescar la interfaz.

No se usa `shared_preferences`, JSON, API REST ni MySQL: todo vive en un
archivo SQLite de la propia instalación.

## Diseño de la tabla

```sql
CREATE TABLE tareas (
  id         INTEGER PRIMARY KEY AUTOINCREMENT, -- identificador único
  titulo     TEXT    NOT NULL,                  -- 1 a 200 caracteres
  completada INTEGER NOT NULL DEFAULT 0         -- booleano: 0 pendiente, 1 completada
);
```

- **Identificación de registros:** cada tarea se identifica por `id`, un entero
  autoincremental que genera SQLite al hacer `INSERT`. Editar, cambiar estado y
  eliminar se hacen siempre con `WHERE id = ?`.
- **Booleano:** SQLite no tiene tipo `BOOLEAN`; Drift guarda `completada` como
  `INTEGER` 0/1 y lo convierte a `bool` en Dart.
- **Título:** se valida antes de guardar (no vacío, no solo espacios, máximo
  200 caracteres) y se guarda sin espacios al inicio/final.

## Organización prevista

```
lib/
  main.dart                 # arranque; crea y cierra la base de datos
  models/tarea.dart         # modelo usado por la UI (id, titulo, completada)
  data/app_database.dart    # tabla Tareas + AppDatabase (Drift) y consultas
  data/app_database.g.dart  # código generado por build_runner (no editar)
  data/validacion.dart      # validación del título
  screens/tareas_page.dart  # interfaz; no hace consultas dentro de build()
test/                       # pruebas automatizadas
web/                        # incluirá sqlite3.wasm y drift_worker.js
```

## Cómo ejecutar

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d linux     # o -d chrome, o un dispositivo de `flutter devices`
```

Si se modifica la tabla en `lib/data/app_database.dart`, hay que regenerar
`app_database.g.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> Estado actual: **Etapa 2** — la base SQLite se abre con `drift_flutter` y ya
> se pueden agregar y consultar tareas persistentes. Faltan editar, cambiar estado y eliminar.
