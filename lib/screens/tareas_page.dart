import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/validacion.dart';
import '../models/tarea.dart';

/// Pantalla principal: alta, consulta, edición, cambio de estado y
/// eliminación de tareas guardadas en SQLite.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TextEditingController _tituloController = TextEditingController();

  /// Consulta reactiva creada una sola vez (no dentro de build()).
  /// Después de cada INSERT/UPDATE/DELETE, Drift vuelve a emitir la lista.
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

  Future<void> _alternarCompletada(Tarea tarea, bool completada) async {
    await _ejecutar(
      () => widget.database.cambiarEstado(tarea.id, completada),
      'No se pudo actualizar el estado de la tarea',
    );
  }

  Future<void> _editarTarea(Tarea tarea) async {
    final nuevoTitulo = await showDialog<String>(
      context: context,
      builder: (context) => _DialogoEditarTitulo(tituloInicial: tarea.titulo),
    );
    if (nuevoTitulo == null || nuevoTitulo.trim() == tarea.titulo) return;
    await _ejecutar(
      () => widget.database.editarTitulo(tarea.id, nuevoTitulo),
      'No se pudo editar la tarea',
    );
  }

  Future<void> _eliminarTarea(Tarea tarea) async {
    final ok = await _ejecutar(
      () => widget.database.eliminarTarea(tarea.id),
      'No se pudo eliminar la tarea',
    );
    if (ok) _mostrarMensaje('Tarea "${tarea.titulo}" eliminada');
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
                          title: Text(
                            tarea.titulo,
                            style: tarea.completada
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
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

/// Diálogo para editar el título; valida antes de cerrar.
class _DialogoEditarTitulo extends StatefulWidget {
  const _DialogoEditarTitulo({required this.tituloInicial});

  final String tituloInicial;

  @override
  State<_DialogoEditarTitulo> createState() => _DialogoEditarTituloState();
}

class _DialogoEditarTituloState extends State<_DialogoEditarTitulo> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.tituloInicial,
  );
  String? _error;

  void _guardar() {
    final error = validarTitulo(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tarea'),
      content: TextField(
        key: const Key('campoEditarTitulo'),
        controller: _controller,
        autofocus: true,
        maxLength: longitudMaximaTitulo,
        onSubmitted: (_) => _guardar(),
        decoration: InputDecoration(
          labelText: 'Título',
          errorText: _error,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
