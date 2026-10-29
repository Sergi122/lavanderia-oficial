/// Horario de atención estandarizado (mismo formato para todas las
/// lavanderías, en vez de que cada admin escriba texto libre distinto).
/// [dias] usa 1=lunes .. 7=domingo (como `DateTime.weekday`).
class HorarioAtencion {
  final List<int> dias;
  final String horaApertura;
  final String horaCierre;

  const HorarioAtencion({
    required this.dias,
    required this.horaApertura,
    required this.horaCierre,
  });

  static const List<String> _nombresDias = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  bool get estaVacio =>
      dias.isEmpty || horaApertura.isEmpty || horaCierre.isEmpty;

  /// Comprime días consecutivos en rangos ("Lun-Vie") y agrupa el resto por
  /// coma ("Lun-Vie, Dom"), siempre con el mismo formato de hora 24h.
  String get formatoLegible {
    if (estaVacio) return '';
    final ordenados = [...dias]..sort();
    final grupos = <String>[];
    var inicio = ordenados.first;
    var previo = ordenados.first;

    void cerrarGrupo(int fin) {
      grupos.add(
        inicio == fin
            ? _nombresDias[inicio - 1]
            : '${_nombresDias[inicio - 1]}-${_nombresDias[fin - 1]}',
      );
    }

    for (final d in ordenados.skip(1)) {
      if (d == previo + 1) {
        previo = d;
        continue;
      }
      cerrarGrupo(previo);
      inicio = d;
      previo = d;
    }
    cerrarGrupo(previo);

    return '${grupos.join(', ')} · $horaApertura-$horaCierre';
  }

  factory HorarioAtencion.fromMap(Map<String, dynamic>? map) {
    if (map == null)
      return const HorarioAtencion(dias: [], horaApertura: '', horaCierre: '');
    return HorarioAtencion(
      dias:
          (map['dias'] as List?)?.map((d) => (d as num).toInt()).toList() ??
          const [],
      horaApertura: map['horaApertura'] as String? ?? '',
      horaCierre: map['horaCierre'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dias': dias,
      'horaApertura': horaApertura,
      'horaCierre': horaCierre,
    };
  }
}
