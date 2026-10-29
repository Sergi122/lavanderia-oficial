/// Órdenes que el panel le manda a la ciudad 3D (cámara) y lo que la ciudad
/// le avisa al panel (qué tocó el usuario).
class Ciudad3DControl {
  void Function(Map<String, dynamic> mensaje)? _enviar;

  void conectar(void Function(Map<String, dynamic>) enviar) => _enviar = enviar;
  void desconectar() => _enviar = null;

  void enfocar(Object objetivo) =>
      _enviar?.call({'tipo': 'enfocar', 'objetivo': objetivo});
  void enfocarObjeto(String tipo, String id) =>
      enfocar({'tipo': tipo, 'id': id});
  void zoom(int sentido) => _enviar?.call({'tipo': 'zoom', 'valor': sentido});
  void rotar() => _enviar?.call({'tipo': 'rotar'});
}

/// Lo que el usuario tocó en la ciudad: empleado, pedido, intencion, lavanderia.
class Seleccion3D {
  final String tipo;
  final String id;
  const Seleccion3D(this.tipo, this.id);

  @override
  bool operator ==(Object other) =>
      other is Seleccion3D && other.tipo == tipo && other.id == id;
  @override
  int get hashCode => Object.hash(tipo, id);
}
