import 'package:flutter/material.dart';

import '../../shared/models/lavanderia.dart';

/// La ciudad 3D del panel llega más adelante: avisa enseguida que no hay
/// escena para que el panel muestre su versión normal.
class AdminCiudadScreen extends StatefulWidget {
  final Lavanderia lavanderia;
  final VoidCallback onSinWebGL;
  const AdminCiudadScreen({
    super.key,
    required this.lavanderia,
    required this.onSinWebGL,
  });

  @override
  State<AdminCiudadScreen> createState() => _AdminCiudadScreenState();
}

class _AdminCiudadScreenState extends State<AdminCiudadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSinWebGL());
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
