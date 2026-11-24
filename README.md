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

## Organización del proyecto

```
lib/
  main.dart                 # arranque; crea la base y la cierra al desmontar la app
  models/tarea.dart         # modelo usado por la UI (id, titulo, completada)
  data/app_database.dart    # tabla Tareas + AppDatabase (Drift): INSERT/SELECT/UPDATE/DELETE
  data/app_database.g.dart  # código generado por build_runner (no editar)
  data/validacion.dart      # validación del título
  screens/tareas_page.dart  # interfaz; consulta reactiva creada en initState, no en build()
test/
  validacion_test.dart      # reglas del título (vacío, espacios, longitud)
  app_database_test.dart    # CRUD sobre SQLite real y persistencia al cerrar/reabrir
  widget_test.dart          # interfaz: inicio, alta, título vacío, editar/completar/eliminar
web/
  sqlite3.wasm              # SQLite compilado a WebAssembly (sqlite3 3.5.2)
  drift_worker.js           # worker de Drift para web (drift 2.35.4)
```

La interfaz se actualiza con una **consulta reactiva** (`select(...).watch()` →
`StreamBuilder`): después de cada INSERT/UPDATE/DELETE, Drift vuelve a emitir la
lista sin tener que volver a consultar manualmente.

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

## Configuración para web

En el navegador no hay SQLite nativo, así que se usa SQLite compilado a
WebAssembly. Drift necesita dos archivos en `web/`, **con versiones que
coincidan con las del `pubspec.lock`**:

| Archivo | Origen | Versión |
|---|---|---|
| `web/sqlite3.wasm` | https://github.com/simolus3/sqlite3.dart/releases (tag `sqlite3-3.5.2`) | paquete `sqlite3` 3.5.2 |
| `web/drift_worker.js` | https://github.com/simolus3/drift/releases (tag `drift-2.35.4`) | paquete `drift` 2.35.4 |

Si se actualizan `drift` o `sqlite3`, hay que descargar de nuevo ambos archivos
de la versión correspondiente. Se referencian en `AppDatabase` con
`DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js'))`.

Drift elige el mejor almacenamiento disponible: OPFS si el servidor envía las
cabeceras COOP/COEP, y si no, **IndexedDB** (lo que ocurre con `flutter run -d chrome`
y con un servidor estático simple; en consola aparece
`Using WasmStorageImplementation.sharedIndexedDb`).

## Dónde se guardan los datos

| Plataforma | Ubicación del archivo `gestor_tareas.sqlite` |
|---|---|
| Android | `/data/data/<paquete>/files/` (privado de la app) |
| iOS / macOS | `Library/Application Support/` del contenedor de la app |
| Linux | `~/.local/share/com.example.gestor_tareas_local/` |
| Windows | `%APPDATA%\<empresa>\gestor_tareas_local\` |
| Web | IndexedDB/OPFS del navegador, por **origen** (protocolo + host + puerto) y perfil |

Los datos se pierden al desinstalar la app, al borrar los datos del sitio en el
navegador o al cerrar una ventana de incógnito. Un *hot reload* no comprueba
la persistencia: hay que cerrar la app por completo y volver a abrirla.

## Plataformas

| Plataforma | Estado |
|---|---|
| Linux | **Probada** (Fedora 44, `flutter run -d linux`) |
| Web (Chrome) | **Probada** (compilación `flutter build web` servida en localhost) |
| Android | Prevista (mismo código; no probada) |
| iOS, macOS | Previstas (requieren una Mac con Xcode; no probadas) |
| Windows | Prevista (requiere compilar en Windows; no probada) |

## Pruebas manuales (P1–P6)

| ID | Acción | Esperado | Linux | Web |
|---|---|---|---|---|
| P1 | Agregar tres tareas, cerrar la app y abrirla | Permanecen las tres | ⬜ | ⬜ |
| P2 | Marcar una como completada y reiniciar | Se conserva el estado | ⬜ | ✅ |
| P3 | Cambiar el título y reiniciar | Aparece el nuevo título | ⬜ | ⬜ |
| P4 | Eliminar una tarea y reiniciar | No reaparece | ⬜ | ⬜ |
| P5 | Agregar un título vacío | No se registra | ⬜ | ⬜ |
| P6 | Recargar y cerrar/abrir la pestaña (mismo origen y perfil) | Los datos permanecen | — | ✅ |

✅ = verificado, ⬜ = pendiente de verificar manualmente. Las pruebas automatizadas
cubren P1–P5 sobre SQLite real (ver abajo).

## Pruebas automatizadas

`flutter test` ejecuta 17 pruebas:

- **`validacion_test.dart`**: rechaza títulos vacíos, solo con espacios y
  demasiado largos; acepta títulos válidos y quita espacios sobrantes.
- **`app_database_test.dart`** (SQLite real con `NativeDatabase`):
  INSERT/SELECT, rechazo de títulos vacíos, UPDATE de título y estado, DELETE por
  id, que la consulta reactiva emita tras cada escritura y una prueba con
  **archivo en disco** que cierra y reabre la base para comprobar P1–P4.
- **`widget_test.dart`** (base en memoria inyectada en la app): pantalla
  inicial, alta desde la interfaz, título vacío (P5) y editar/completar/eliminar
  desde la interfaz.
