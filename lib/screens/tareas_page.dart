import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/validacion.dart';
import '../models/tarea.dart';

/// Pantalla principal: alta y consulta de tareas guardadas en SQLite.
/// Edición, cambio de estado y eliminación quedan pendientes (Etapa 3).
class TareasPage extends StatefulWidget {
  const TareasPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();

  /// Consulta reactiva creada una sola vez (no dentro de build()).
  /// Después de cada INSERT, Drift vuelve a emitir la lista.
  late Stream<List<Tarea>> _tareas;

  String? _errorTitulo;

  @override
  void initState() {
    super.initState();
    _tareas = widget.database.observarTareas();
  }

  Future<void> _agregarTarea() async {
    final titulo = _tituloController.text;
    final error = validarTitulo(titulo);
    if (error != null) {
      setState(() => _errorTitulo = error);
      return;
    }
    final ok = await _ejecutar(
      () => widget.database.agregarTarea(titulo),
      'No se pudo guardar la tarea',
    );
    if (ok && mounted) {
      _tituloController.clear();
      setState(() => _errorTitulo = null);
    }
  }

  void _alternarCompletada(Tarea tarea, bool completada) {
    _mostrarMensaje('Implementar actualización de tarea');
  }

  void _editarTarea(Tarea tarea) {
    _mostrarMensaje('Implementar edición de título');
  }

  void _eliminarTarea(Tarea tarea) {
    _mostrarMensaje('Implementar eliminación de tarea');
  }

  /// Ejecuta una operación de almacenamiento y muestra un mensaje
  /// comprensible si falla. Devuelve `true` si terminó sin errores.
  Future<bool> _ejecutar(
    Future<Object?> Function() operacion,
    String mensaje,
  ) async {
    try {
      await operacion();
      return true;
    } on TituloInvalidoException catch (e) {
      _mostrarMensaje(e.mensaje);
    } catch (e, st) {
      debugPrint('Error de almacenamiento: $e\n$st');
      _mostrarMensaje('$mensaje. Inténtalo de nuevo.');
    }
    return false;
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestor de tareas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              maxLength: longitudMaximaTitulo,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _agregarTarea(),
              onChanged: (_) {
                if (_errorTitulo != null) setState(() => _errorTitulo = null);
              },
              decoration: InputDecoration(
                labelText: 'Nueva tarea',
                border: const OutlineInputBorder(),
                errorText: _errorTitulo,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _agregarTarea,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tarea'),
            ),
            const SizedBox(height: 12),
            const Text('Mis tareas', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Tarea>>(
                stream: _tareas,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'No se pudieron cargar las tareas.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final tareas = snapshot.data!;
                  if (tareas.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay tareas guardadas'),
                    );
                  }
                  return ListView.builder(
                    itemCount: tareas.length,
                    itemBuilder: (context, index) {
                      final tarea = tareas[index];
                      return Card(
                        child: ListTile(
                          leading: Checkbox(
                            value: tarea.completada,
                            onChanged: (valor) {
                              if (valor != null) {
                                _alternarCompletada(tarea, valor);
                              }
                            },
                          ),
                          title: Text(tarea.titulo),
                          subtitle: Text(
                            'ID: ${tarea.id} · '
                            '${tarea.completada ? 'Completada' : 'Pendiente'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editarTarea(tarea),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _eliminarTarea(tarea),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
