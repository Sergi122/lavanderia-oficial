import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Punto que elige el cliente en el mapa (Localización) y que usa el pedido.
typedef PuntoElegido = ({LatLng punto, String direccion});

const centroLaPaz = LatLng(-16.5000, -68.1500);
const _distancia = Distance();

/// Resultado de pedir el GPS: el punto o un mensaje listo para mostrar.
class ResultadoUbicacion {
  final LatLng? punto;
  final String? error;
  const ResultadoUbicacion.ok(LatLng this.punto) : error = null;
  const ResultadoUbicacion.fallo(String this.error) : punto = null;
}

/// Pide permiso y lee la posición actual. Nunca lanza: devuelve el error.
Future<ResultadoUbicacion> ubicacionActual() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const ResultadoUbicacion.fallo(
        'Activa la ubicación (GPS) de tu celular',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      return const ResultadoUbicacion.fallo(
        'Necesitamos permiso de ubicación (o marca el punto en el mapa)',
      );
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return ResultadoUbicacion.ok(LatLng(pos.latitude, pos.longitude));
  } catch (_) {
    return const ResultadoUbicacion.fallo('No pudimos obtener tu ubicación');
  }
}

/// Dirección legible de un punto (Nominatim/OSM). Null si no hay internet.
Future<String?> direccionDe(LatLng punto) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&zoom=18&lat=${punto.latitude}&lon=${punto.longitude}',
    );
    final r = await http
        .get(uri, headers: {'User-Agent': 'com.losasustadores.laundry_app'})
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['display_name'] as String?;
  } catch (_) {
    return null;
  }
}

double kmEntre(LatLng a, LatLng b) => _distancia.as(LengthUnit.Kilometer, a, b);
