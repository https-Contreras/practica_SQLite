import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/tarea.dart';
import 'validacion.dart';

part 'app_database.g.dart';

/// Tabla `tareas` en SQLite.
///
/// CREATE TABLE tareas (
///   id         INTEGER PRIMARY KEY AUTOINCREMENT,
///   titulo     TEXT    NOT NULL,          -- 1..200 caracteres
///   completada INTEGER NOT NULL DEFAULT 0 -- booleano: 0 = pendiente, 1 = completada
/// );
@DataClassName('TareaRegistro')
class Tareas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo =>
      text().withLength(min: 1, max: longitudMaximaTitulo)();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
}

/// Base de datos local de la aplicación (Drift sobre SQLite).
///
/// Por defecto abre un archivo persistente con `drift_flutter`, que funciona en
/// Android, iOS, Windows, Linux, macOS y web (con `sqlite3.wasm` y
/// `drift_worker.js` dentro de `web/`). En las pruebas se puede inyectar otro
/// [QueryExecutor], por ejemplo `NativeDatabase.memory()`.
@DriftDatabase(tables: [Tareas])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrirConexion());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _abrirConexion() {
    return driftDatabase(
      name: 'gestor_tareas',
      // Nativo: archivo gestor_tareas.sqlite en la carpeta privada de datos de
      // la app (Android: /data/data/<paquete>/files, iOS/macOS: Application
      // Support, Linux: ~/.local/share/<id>, Windows: %APPDATA%\<empresa>\<app>).
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // Web: SQLite compilado a WebAssembly, guardado en OPFS o IndexedDB.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Consultas (SELECT)
  // ---------------------------------------------------------------------------

  /// Consulta reactiva: emite la lista completa cada vez que la tabla cambia.
  Stream<List<Tarea>> observarTareas() {
    final consulta = select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return consulta.watch().map((filas) => filas.map(_aModelo).toList());
  }

  /// Consulta puntual de todas las tareas.
  Future<List<Tarea>> obtenerTareas() async {
    final consulta = select(tareas)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    final filas = await consulta.get();
    return filas.map(_aModelo).toList();
  }

  // ---------------------------------------------------------------------------
  // Escrituras (INSERT, UPDATE, DELETE)
  // ---------------------------------------------------------------------------

  /// INSERT. Devuelve el id generado.
  Future<int> agregarTarea(String titulo) async {
    final limpio = normalizarTitulo(titulo);
    return into(tareas).insert(TareasCompanion.insert(titulo: limpio));
  }

  /// UPDATE del título. Devuelve `true` si se modificó alguna fila.
  Future<bool> editarTitulo(int id, String nuevoTitulo) async {
    final limpio = normalizarTitulo(nuevoTitulo);
    final filas = await (update(tareas)..where((t) => t.id.equals(id))).write(
      TareasCompanion(titulo: Value(limpio)),
    );
    return filas > 0;
  }

  /// UPDATE del estado. Devuelve `true` si se modificó alguna fila.
  Future<bool> cambiarEstado(int id, bool completada) async {
    final filas = await (update(tareas)..where((t) => t.id.equals(id))).write(
      TareasCompanion(completada: Value(completada)),
    );
    return filas > 0;
  }

  /// DELETE por id. Devuelve `true` si se eliminó alguna fila.
  Future<bool> eliminarTarea(int id) async {
    final filas = await (delete(tareas)..where((t) => t.id.equals(id))).go();
    return filas > 0;
  }

  static Tarea _aModelo(TareaRegistro fila) =>
      Tarea(id: fila.id, titulo: fila.titulo, completada: fila.completada);
}
