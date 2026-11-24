import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'screens/tareas_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestorTareasApp());
}

/// Punto de entrada de la aplicación.
///
/// Es dueña de la conexión a la base de datos: la abre al iniciar y la cierra
/// al desmontarse. En pruebas se puede inyectar una base distinta con
/// [database] (en ese caso quien la crea es responsable de cerrarla).
class GestorTareasApp extends StatefulWidget {
  const GestorTareasApp({super.key, this.database});

  final AppDatabase? database;

  @override
  State<GestorTareasApp> createState() => _GestorTareasAppState();
}

class _GestorTareasAppState extends State<GestorTareasApp> {
  late final AppDatabase _database = widget.database ?? AppDatabase();

  @override
  void dispose() {
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor de tareas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TareasPage(database: _database),
    );
  }
}
