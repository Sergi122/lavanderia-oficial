/// Similitud coseno mínima para dar por buena la coincidencia carnet/selfie.
/// Se calibró con pruebas reales (misma persona 0.61-0.71, otras 0.14-0.39).
const double umbralSimilitudRostro = 0.55;

enum EstadoComparacion {
  coincide,
  noCoincide,
  sinRostroCarnet,
  sinRostroSelfie,
  error,
}

class ResultadoComparacion {
  final EstadoComparacion estado;
  final double? similitud;
  const ResultadoComparacion(this.estado, [this.similitud]);
}
