import '../models/lavanderia.dart';
import '../widgets/icono_prenda.dart';

/// Ruta del modelo y de sus etiquetas (mismo orden que en el entrenamiento).
const rutaModeloPrendas = 'assets/models/prendas_mobilenetv2.tflite';
const rutaEtiquetasPrendas = 'assets/models/prendas_etiquetas.txt';
const ladoEntradaModelo = 224;

/// Por debajo de esto la IA no está segura: se pide confirmar a mano.
const confianzaMinima = 0.75;

class PrediccionPrenda {
  /// Clase del modelo (coincide con el id de la ilustración).
  final String clase;
  final double confianza;
  const PrediccionPrenda(this.clase, this.confianza);
}

/// Nombre del tipo de prenda de la app para cada clase del modelo.
const nombrePorClase = {
  'camisa': 'Camisas / blusas',
  'polera': 'Poleras',
  'chompa': 'Chompas / abrigos',
  'abrigo': 'Chompas / abrigos',
  'pantalon': 'Pantalones de tela',
  'jeans': 'Jeans',
  'short': 'Shorts',
  'falda': 'Faldas',
  'vestido': 'Vestidos',
  'traje': 'Trajes (por pieza)',
  'ropa_cama': 'Ropa de cama',
  'edredon': 'Edredones / cobijas',
  'toalla': 'Toallas',
  'cortina': 'Cortinas',
  'zapatillas': 'Zapatillas',
};

/// Servicio de la lista de precios de la lavandería que corresponde a la
/// clase: si el admin le puso otro nombre ("Sábanas king"), se usa ese.
String servicioParaClase(Lavanderia? lav, String clase) {
  if (lav != null) {
    for (final nombre in lav.precios.keys) {
      final icono = iconoParaPrenda(nombre, elegidos: lav.iconosServicios);
      if (icono == clase ||
          (clase == 'abrigo' && icono == 'chompa') ||
          (clase == 'chompa' && icono == 'abrigo')) {
        return nombre;
      }
    }
  }
  return nombrePorClase[clase] ?? 'Otras prendas';
}

/// Ordena de mayor a menor confianza.
List<PrediccionPrenda> ordenarPredicciones(
  List<String> etiquetas,
  List<double> probabilidades,
) {
  final out = [
    for (var i = 0; i < etiquetas.length && i < probabilidades.length; i++)
      PrediccionPrenda(etiquetas[i], probabilidades[i]),
  ]..sort((a, b) => b.confianza.compareTo(a.confianza));
  return out;
}
