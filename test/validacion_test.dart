import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_tareas_local/data/validacion.dart';

void main() {
  group('validarTitulo', () {
    test('rechaza un título vacío', () {
      expect(validarTitulo(''), isNotNull);
    });

    test('rechaza un título compuesto solo por espacios', () {
      expect(validarTitulo('    '), isNotNull);
      expect(validarTitulo(' \t \n '), isNotNull);
    });

    test('rechaza un título demasiado largo', () {
      expect(validarTitulo('a' * (longitudMaximaTitulo + 1)), isNotNull);
    });

    test('acepta un título normal', () {
      expect(validarTitulo('Comprar leche'), isNull);
      expect(validarTitulo('a' * longitudMaximaTitulo), isNull);
    });
  });

  group('normalizarTitulo', () {
    test('quita espacios al inicio y al final', () {
      expect(normalizarTitulo('  Estudiar Flutter  '), 'Estudiar Flutter');
    });

    test('lanza TituloInvalidoException con títulos inválidos', () {
      expect(
        () => normalizarTitulo('   '),
        throwsA(isA<TituloInvalidoException>()),
      );
    });
  });
}
