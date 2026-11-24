/// Reglas de validación del título de una tarea.
///
/// Se mantienen separadas de la UI y de la base de datos para poder
/// reutilizarlas en ambos lugares y probarlas de forma unitaria.
const int longitudMaximaTitulo = 200;

/// Devuelve un mensaje de error si [titulo] no es válido, o `null` si lo es.
String? validarTitulo(String titulo) {
  final limpio = titulo.trim();
  if (limpio.isEmpty) {
    return 'El título no puede estar vacío';
  }
  if (limpio.length > longitudMaximaTitulo) {
    return 'El título no puede tener más de $longitudMaximaTitulo caracteres';
  }
  return null;
}

/// Error lanzado por la capa de datos cuando se intenta guardar
/// un título inválido.
class TituloInvalidoException implements Exception {
  final String mensaje;
  const TituloInvalidoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Valida y normaliza (quita espacios al inicio y al final) el título.
/// Lanza [TituloInvalidoException] si no es válido.
String normalizarTitulo(String titulo) {
  final error = validarTitulo(titulo);
  if (error != null) throw TituloInvalidoException(error);
  return titulo.trim();
}
