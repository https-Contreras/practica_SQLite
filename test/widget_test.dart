import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';
import 'package:gestor_tareas_local/models/tarea.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// Consulta la base con async real (fuera del reloj simulado del test).
  Future<List<Tarea>> leer(WidgetTester tester) async =>
      (await tester.runAsync(db.obtenerTareas))!;

  /// Desmonta la app y cierra la base con async real (fuera del reloj
  /// simulado de testWidgets); si no, la prueba se queda colgada.
  Future<void> cerrar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(() => db.close());
  }

  testWidgets('La pantalla inicial se muestra sin errores', (tester) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    expect(find.text('Gestor de tareas'), findsOneWidget);
    expect(find.text('Agregar tarea'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await cerrar(tester);
  });

  testWidgets('Agregar una tarea la guarda en la base y la muestra', (
    tester,
  ) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Estudiar Drift  ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(find.text('Estudiar Drift'), findsOneWidget);
    final guardadas = await leer(tester);
    expect(guardadas.single.titulo, 'Estudiar Drift');
    await cerrar(tester);
  });

  testWidgets('Un título vacío no se registra y muestra un error (P5)', (
    tester,
  ) async {
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(find.text('Agregar tarea'));
    await tester.pumpAndSettle();

    expect(find.text('El título no puede estar vacío'), findsOneWidget);
    expect(await leer(tester), isEmpty);
    await cerrar(tester);
  });

  testWidgets('Editar, completar y eliminar desde la interfaz', (tester) async {
    await tester.runAsync(() => db.agregarTarea('Original'));
    await tester.pumpWidget(GestorTareasApp(database: db));
    await tester.pumpAndSettle();

    // Editar título.
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campoEditarTitulo')), 'Nueva');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva'), findsOneWidget);

    // Marcar como completada.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect((await leer(tester)).single.completada, isTrue);

    // Eliminar.
    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(await leer(tester), isEmpty);
    expect(find.text('Todavía no hay tareas guardadas'), findsOneWidget);
    await cerrar(tester);
  });
}
