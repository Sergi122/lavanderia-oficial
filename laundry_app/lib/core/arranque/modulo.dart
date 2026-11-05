import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contrato/modelos/app_user.dart';

/// Un botón del menú del módulo (pantalla /modulo). `ruta` puede llevar
/// `{rol}`, que se cambia por el prefijo del rol que navega (/admin, /empleado…).
class EntradaModulo {
  final String titulo;
  final String ruta;
  final IconData icono;
  final Set<UserRole> roles;
  const EntradaModulo(this.titulo, this.ruta, this.icono, this.roles);

  String rutaPara(UserRole rol) => ruta.replaceAll('{rol}', prefijoRol(rol));
}

/// Un módulo del documento (Sprint S1…S10): trae sus propias rutas. La app completa
/// (main.dart) junta los diez; cada `main_<modulo>.dart` junta solo el suyo
/// (más S1, que pone el inicio de sesión).
class Modulo {
  final int numero;
  final String id;
  final String nombre;
  final String responsable;
  final List<RouteBase> rutas;
  final List<EntradaModulo> entradas;
  const Modulo({
    required this.numero,
    required this.id,
    required this.nombre,
    required this.responsable,
    required this.rutas,
    this.entradas = const [],
  });

  String get etiqueta => 'S$numero · $nombre';
}

String prefijoRol(UserRole rol) => switch (rol) {
  UserRole.cliente => 'cliente',
  UserRole.empleado => 'empleado',
  UserRole.admin => 'admin',
  UserRole.verificador => 'verificador',
  UserRole.repartidor => 'repartidor',
  UserRole.superadmin => 'superadmin',
};

/// Módulos con los que arrancó esta app. Lo fija cada main_*.dart.
final modulosActivosProvider = Provider<List<Modulo>>(
  (ref) => throw UnimplementedError('arrancarApp() define los módulos'),
);

/// Módulo que se está presentando (null = app completa).
final moduloPresentadoProvider = Provider<Modulo?>((ref) => null);
