import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ilustraciones propias de cada tipo de prenda (assets/prendas/*.svg).
const iconosPrenda = [
  'camisa',
  'blusa',
  'polera',
  'chompa',
  'abrigo',
  'pantalon',
  'jeans',
  'short',
  'falda',
  'vestido',
  'traje',
  'traje_completo',
  'ropa_cama',
  'edredon',
  'toalla',
  'cortina',
  'zapatillas',
  'otro',
];

String _sinAcentos(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ñ', 'n');

/// Elige la ilustración por el nombre del servicio, así también tienen dibujo
/// los servicios que el admin crea con su propio nombre ("Sábanas king",
/// "Terno de novio"...).
String iconoParaPrenda(
  String nombre, {
  Map<String, String> elegidos = const {},
}) {
  final propio = elegidos[nombre];
  if (propio != null && iconosPrenda.contains(propio)) return propio;
  final n = _sinAcentos(nombre);
  bool tiene(List<String> claves) => claves.any(n.contains);
  if (tiene(['traje completo', 'terno'])) return 'traje_completo';
  if (tiene(['traje', 'saco', 'blazer'])) return 'traje';
  if (tiene(['jean', 'denim'])) return 'jeans';
  if (tiene(['vestid'])) return 'vestido';
  if (tiene(['fald', 'pollera'])) return 'falda';
  if (tiene(['short', 'bermuda'])) return 'short';
  if (tiene(['polera', 'camiseta', 'remera'])) return 'polera';
  if (tiene(['blusa'])) return 'blusa';
  if (tiene(['camis'])) return 'camisa';
  if (tiene(['pantal'])) return 'pantalon';
  if (tiene(['chompa', 'sueter', 'buzo', 'hoodie', 'polar'])) return 'chompa';
  if (tiene(['abrig', 'chamarra', 'casaca', 'chaqueta', 'campera']))
    return 'abrigo';
  if (tiene(['edred', 'cobij', 'frazad', 'manta', 'colcha', 'plumon']))
    return 'edredon';
  if (tiene(['sabana', 'cama', 'almohad', 'funda'])) return 'ropa_cama';
  if (tiene(['toall'])) return 'toalla';
  if (tiene(['cortin'])) return 'cortina';
  if (tiene(['zapat', 'tenis', 'calzado'])) return 'zapatillas';
  return 'otro';
}

class IconoPrenda extends StatelessWidget {
  /// Id de la ilustración (ver [iconosPrenda]) o nombre del servicio.
  final String prenda;
  final double tamano;
  final Map<String, String> elegidos;
  const IconoPrenda(
    this.prenda, {
    super.key,
    this.tamano = 40,
    this.elegidos = const {},
  });

  @override
  Widget build(BuildContext context) {
    final id = iconosPrenda.contains(prenda)
        ? prenda
        : iconoParaPrenda(prenda, elegidos: elegidos);
    return SvgPicture.asset(
      'assets/prendas/$id.svg',
      width: tamano,
      height: tamano,
      semanticsLabel: prenda,
    );
  }
}
