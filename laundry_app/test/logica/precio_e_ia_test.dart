import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app/features/shared/data/precio_pedido.dart';
import 'package:laundry_app/features/shared/ia/clasificador_tipos.dart';
import 'package:laundry_app/features/shared/models/lavanderia.dart';
import 'package:laundry_app/features/shared/models/pedido.dart';

Lavanderia _lav({Map<String, double> precios = const {}, double? kg}) =>
    Lavanderia.fromMap('L1', {
      'nombre': 'Prueba',
      'precios': precios,
      'precioKg': kg,
      'descuentoPorDocena': 5,
      'descuentoMaximoPorcentaje': 10,
      'iconosServicios': {'Sábanas king': 'ropa_cama'},
    });

void main() {
  test('precio por pieza con descuento por docena', () {
    final lav = _lav(precios: {'Jeans': 10, 'Edredones / cobijas': 30});
    // 12 jeans = 1 docena → 5 % de descuento; el edredón no lleva descuento
    expect(
      costoPrendasPara(
        lav,
        {'Jeans': 12, 'Edredones / cobijas': 1},
        ModoCobroRegular.pieza,
        0,
      ),
      closeTo(12 * 10 * 0.95 + 30, 0.001),
    );
  });

  test('precio por kilo usa el peso, las delicadas siguen por pieza', () {
    final lav = _lav(precios: {'Traje completo': 40}, kg: 8);
    expect(
      costoPrendasPara(
        lav,
        {'Jeans': 5, 'Traje completo': 1},
        ModoCobroRegular.kilo,
        3.5,
      ),
      closeTo(3.5 * 8 + 40, 0.001),
    );
  });

  test('prenda sin precio en la lista usa el precio por defecto', () {
    expect(
      costoPrendasPara(_lav(), {'Vestidos': 2}, ModoCobroRegular.pieza, 0),
      2 * precioPorDefecto,
    );
  });

  test('la clase de la IA usa el nombre propio del servicio de la lavandería', () {
    final lav = _lav(precios: {'Sábanas king': 15, 'Chompas / abrigos': 12});
    expect(servicioParaClase(lav, 'ropa_cama'), 'Sábanas king');
    expect(servicioParaClase(lav, 'abrigo'), 'Chompas / abrigos');
    expect(servicioParaClase(lav, 'vestido'), 'Vestidos');
    expect(servicioParaClase(null, 'jeans'), 'Jeans');
  });

  test('las predicciones salen ordenadas por confianza', () {
    final r = ordenarPredicciones(['a', 'b', 'c'], [0.1, 0.7, 0.2]);
    expect(r.map((p) => p.clase), ['b', 'c', 'a']);
  });
}
