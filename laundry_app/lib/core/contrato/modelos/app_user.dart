import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { cliente, empleado, admin, verificador, repartidor, superadmin }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.cliente,
  );
}

class AppUser {
  final String uid;
  final String nombre;
  final String nombres;
  final String apellidos;
  final double? ubicacionLat;
  final double? ubicacionLng;
  final String email;
  final UserRole role;
  final String telefono;
  final String? lavanderiaId;
  final bool activo;
  final String bioEmpleado;
  final double? salarioEmpleado;
  final DateTime? fechaNacimiento;
  final String direccion;
  final String fotoBase64;
  final String cvBase64;
  final String cvNombre;

  /// Versión de la política de privacidad y términos que aceptó ('' = nunca).
  final String terminosVersion;

  /// Lo que el empleado está haciendo ahora (lo ve el admin en la ciudad 3D):
  /// descanso, recepcion, lavando, secando, planchando, vapor, colgando.
  final String actividad;
  final DateTime? actividadEn;

  /// Repartidor: si está recibiendo encargos nuevos (switch de su panel).
  final bool disponibleEncargos;

  /// Por qué el superadmin suspendió la cuenta ('' si está activa).
  final String motivoSuspension;

  const AppUser({
    required this.uid,
    required this.nombre,
    this.nombres = '',
    this.apellidos = '',
    this.ubicacionLat,
    this.ubicacionLng,
    required this.email,
    required this.role,
    this.telefono = '',
    this.lavanderiaId,
    this.activo = true,
    this.bioEmpleado = '',
    this.salarioEmpleado,
    this.fechaNacimiento,
    this.direccion = '',
    this.fotoBase64 = '',
    this.cvBase64 = '',
    this.cvNombre = '',
    this.terminosVersion = '',
    this.actividad = 'descanso',
    this.actividadEn,
    this.disponibleEncargos = true,
    this.motivoSuspension = '',
  });

  /// Un cliente nuevo debe completar nombres, apellidos y el punto donde se
  /// recoge su ropa antes de usar la app (sin verificación de identidad).
  bool get perfilCompleto =>
      nombres.trim().isNotEmpty &&
      apellidos.trim().isNotEmpty &&
      direccion.trim().isNotEmpty &&
      ubicacionLat != null &&
      ubicacionLng != null;

  /// null si no puso fecha de nacimiento — nunca se pide la edad directo,
  /// se calcula sola para que no quede desactualizada con el tiempo.
  int? get edad {
    final f = fechaNacimiento;
    if (f == null) return null;
    final ahora = DateTime.now();
    var edad = ahora.year - f.year;
    if (ahora.month < f.month || (ahora.month == f.month && ahora.day < f.day))
      edad--;
    return edad;
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      nombre: map['nombre'] as String? ?? '',
      nombres: map['nombres'] as String? ?? '',
      apellidos: map['apellidos'] as String? ?? '',
      ubicacionLat: (map['ubicacionLat'] as num?)?.toDouble(),
      ubicacionLng: (map['ubicacionLng'] as num?)?.toDouble(),
      email: map['email'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'cliente'),
      telefono: map['telefono'] as String? ?? '',
      lavanderiaId: map['lavanderiaId'] as String?,
      activo: map['activo'] as bool? ?? true,
      bioEmpleado: map['bioEmpleado'] as String? ?? '',
      salarioEmpleado: (map['salarioEmpleado'] as num?)?.toDouble(),
      fechaNacimiento: (map['fechaNacimiento'] as Timestamp?)?.toDate(),
      direccion: map['direccion'] as String? ?? '',
      fotoBase64: map['fotoBase64'] as String? ?? '',
      cvBase64: map['cvBase64'] as String? ?? '',
      cvNombre: map['cvNombre'] as String? ?? '',
      terminosVersion: map['terminosVersion'] as String? ?? '',
      actividad: map['actividad'] as String? ?? 'descanso',
      actividadEn: map['actividadEn'] is Timestamp
          ? (map['actividadEn'] as Timestamp).toDate()
          : null,
      disponibleEncargos: map['disponibleEncargos'] as bool? ?? true,
      motivoSuspension: map['motivoSuspension'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'nombres': nombres,
      'apellidos': apellidos,
      if (ubicacionLat != null) 'ubicacionLat': ubicacionLat,
      if (ubicacionLng != null) 'ubicacionLng': ubicacionLng,
      'email': email,
      'role': role.name,
      'telefono': telefono,
      if (lavanderiaId != null) 'lavanderiaId': lavanderiaId,
      'activo': activo,
      'bioEmpleado': bioEmpleado,
      if (salarioEmpleado != null) 'salarioEmpleado': salarioEmpleado,
      if (fechaNacimiento != null)
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento!),
      'direccion': direccion,
      'fotoBase64': fotoBase64,
      'cvBase64': cvBase64,
      'cvNombre': cvNombre,
    };
  }
}
