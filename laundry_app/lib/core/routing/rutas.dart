import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servidor de rutas. Por defecto usa el OSRM público (gratis, con límites de
/// uso); para producción se apunta a uno propio sin tocar código:
///   flutter build ... --dart-define=OSRM_URL=https://mi-osrm.ejemplo.com
const _osrmUrl = String.fromEnvironment(
  'OSRM_URL',
  defaultValue: 'https://router.project-osrm.org',
);

class TramoRuta {
  final List<LatLng> puntos;
  final double km;
  final double minutos;
  final bool aproximado;
  const TramoRuta(this.puntos, this.km, this.minutos, this.aproximado);
}

final _cache = <String, TramoRuta>{};

String _clave(LatLng a, LatLng b) =>
    '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
    '|${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

/// Ruta real por calles (con caché para no golpear el servidor de más);
/// si falla, línea recta con la distancia aproximada.
Future<TramoRuta> calcularTramo(LatLng a, LatLng b) async {
  final clave = _clave(a, b);
  final guardado = _cache[clave];
  if (guardado != null) return guardado;
  try {
    final url = Uri.parse(
      '$_osrmUrl/route/v1/driving/'
      '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
      '?overview=full&geometries=geojson',
    );
    final resp = await http.get(url).timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final ruta =
          (jsonDecode(resp.body)['routes'] as List).first
              as Map<String, dynamic>;
      final coords = (ruta['geometry']['coordinates'] as List)
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      return _cache[clave] = TramoRuta(
        coords,
        (ruta['distance'] as num) / 1000,
        (ruta['duration'] as num) / 60,
        false,
      );
    }
  } catch (_) {}
  final km = const Distance().as(LengthUnit.Kilometer, a, b) * 1.3;
  return TramoRuta([a, b], km, km / 25 * 60, true);
}
