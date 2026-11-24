import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/data/validacion.dart';

/// Pruebas de la capa de datos sobre un SQLite real (sin Flutter UI).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CRUD en memoria', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('INSERT + SELECT: agrega tareas y las lista en orden', () async {
      final id1 = await db.agregarTarea('Primera');
      final id2 = await db.agregarTarea('  Segunda  ');

      final tareas = await db.obtenerTareas();
      expect(tareas.map((t) => t.id), [id1, id2]);
      expect(tareas.map((t) => t.titulo), ['Primera', 'Segunda']);
      expect(tareas.every((t) => !t.completada), isTrue);
    });

    test('no registra títulos vacíos ni solo con espacios', () async {
      await expectLater(
        db.agregarTarea(''),
        throwsA(isA<TituloInvalidoException>()),
      );
      await expectLater(
        db.agregarTarea('    '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect(await db.obtenerTareas(), isEmpty);
    });

    test('UPDATE: edita el título y cambia el estado', () async {
      final id = await db.agregarTarea('Original');

      expect(await db.editarTitulo(id, 'Editada'), isTrue);
      expect(await db.cambiarEstado(id, true), isTrue);

      final tarea = (await db.obtenerTareas()).single;
      expect(tarea.titulo, 'Editada');
      expect(tarea.completada, isTrue);

      await db.cambiarEstado(id, false);
      expect((await db.obtenerTareas()).single.completada, isFalse);
    });

    test('UPDATE: no permite dejar un título vacío', () async {
      final id = await db.agregarTarea('Original');
      await expectLater(
        db.editarTitulo(id, '   '),
        throwsA(isA<TituloInvalidoException>()),
      );
      expect((await db.obtenerTareas()).single.titulo, 'Original');
    });

    test('DELETE: elimina solo la tarea indicada por id', () async {
      final id1 = await db.agregarTarea('Se queda');
      final id2 = await db.agregarTarea('Se va');

      expect(await db.eliminarTarea(id2), isTrue);
      expect(await db.eliminarTarea(9999), isFalse);

      final tareas = await db.obtenerTareas();
      expect(tareas.map((t) => t.id), [id1]);
    });

    test('la consulta reactiva emite de nuevo tras cada escritura', () async {
      final emisiones = db.observarTareas().map((l) => l.length);
      final esperado = expectLater(emisiones, emitsInOrder([0, 1, 2, 1]));

      await pumpEventQueue();
      final id = await db.agregarTarea('A');
      await pumpEventQueue();
      await db.agregarTarea('B');
      await pumpEventQueue();
      await db.eliminarTarea(id);

      await esperado;
    });
  });

  group('Persistencia en archivo', () {
    late Directory dir;
    late File archivo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gestor_tareas_test');
      archivo = File('${dir.path}/tareas.sqlite');
    });
    tearDown(() => dir.delete(recursive: true));

    test('los datos sobreviven a cerrar y reabrir la base (P1–P4)', () async {
      // "Primera ejecución" de la app.
      var db = AppDatabase(NativeDatabase(archivo));
      final a = await db.agregarTarea('Tarea A');
      final b = await db.agregarTarea('Tarea B');
      final c = await db.agregarTarea('Tarea C');
      await db.close();

      // Reinicio: P1, las tres siguen ahí.
      db = AppDatabase(NativeDatabase(archivo));
      expect((await db.obtenerTareas()).length, 3);
      await db.cambiarEstado(a, true); // P2
      await db.editarTitulo(b, 'Tarea B editada'); // P3
      await db.eliminarTarea(c); // P4
      await db.close();

      // Segundo reinicio: se conservan los cambios.
      db = AppDatabase(NativeDatabase(archivo));
      final tareas = await db.obtenerTareas();
      await db.close();

      expect(tareas.map((t) => t.id), [a, b]);
      expect(tareas[0].completada, isTrue);
      expect(tareas[1].titulo, 'Tarea B editada');
    });
  });
}
