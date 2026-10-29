import 'escena_lavanderia.dart';

/// Datos de la escena en el formato que entiende la ciudad 3D (escena3d.js).
Map<String, dynamic> escenaAJson(EscenaDatos d) => {
  'colgadas': d.colgadas,
  'lavando': d.lavando,
  'secando': d.secando,
  'listas': d.listas,
  'ciclo': d.ciclo,
  'paquete': d.paqueteEnCasa,
  'destacarMia': d.destacarMia,
  'nombre': d.nombreLavanderia,
  'foco': d.foco,
  'rutaLarga': d.rutaLarga,
  if (d.casas.isNotEmpty)
    'casas': [
      for (final c in d.casas)
        {'slot': c.slot, 'estado': c.estado, 'etiqueta': c.etiqueta},
    ],
  'motos': [
    for (final m in d.motos)
      {
        'rol': m.rol.name,
        'progreso': m.progreso,
        'slot': m.slot,
        'rapido': m.rapido,
      },
  ],
};
