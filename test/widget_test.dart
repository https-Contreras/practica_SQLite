import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/app_database.dart';
import 'package:gestor_tareas_local/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  // En pruebas se inyecta una base SQLite en memoria en lugar del archivo real.
  setUp(() => db = AppDatabase(NativeDatabase.memory()));

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
}
