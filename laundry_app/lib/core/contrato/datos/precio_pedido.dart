import '../modelos/lavanderia.dart';
import '../modelos/pedido.dart';
import '../modelos/tipos_prenda.dart';

/// Precio por prenda cuando la lavandería no fijó uno para ese tipo.
const precioPorDefecto = 5.0;

/// Costo de las prendas según la lista de precios de la lavandería. Lo usa el
/// cliente al armar el pedido y la lavandería al confirmarlo: el monto que
/// manda el celular del cliente no se toma como verdad.
double costoPrendasPara(
  Lavanderia lav,
  Map<String, int> prendas,
  ModoCobroRegular modo,
  double cantidadRegular,
) {
  double precio(String tipo) => lav.precios[tipo] ?? precioPorDefecto;
  var especiales = 0.0;
  var regular = 0.0;
  var piezasRegulares = 0;
  prendas.forEach((tipo, n) {
    if (n <= 0) return;
    if (prendasEspeciales.contains(tipo)) {
      especiales += n * precio(tipo);
    } else if (modo == ModoCobroRegular.pieza) {
      regular += n * precio(tipo);
      piezasRegulares += n;
    }
  });
  switch (modo) {
    case ModoCobroRegular.pieza:
      regular *= 1 - lav.descuentoParaPiezas(piezasRegulares) / 100;
    case ModoCobroRegular.docena:
      regular = 0;
    case ModoCobroRegular.kilo:
      regular = cantidadRegular * (lav.precioKg ?? 0);
  }
  return especiales + regular;
}
