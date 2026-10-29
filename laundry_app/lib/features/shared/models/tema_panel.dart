import 'package:flutter/material.dart';

/// Temas de color para el panel del dashboard del admin (nombre → degradé).
/// Se usa la clave (ej. "aqua") como valor guardado en Firestore.
const temasPanel = <String, List<Color>>{
  'aqua': [Color(0xFF0EA5A4), Color(0xFF6366F1)],
  'coral': [Color(0xFFF97362), Color(0xFFFCA65B)],
  'violeta': [Color(0xFF8B5CF6), Color(0xFFD946EF)],
  'bosque': [Color(0xFF16A34A), Color(0xFF65A30D)],
  'atardecer': [Color(0xFFF59E0B), Color(0xFFEF4444)],
  'oceano': [Color(0xFF0284C7), Color(0xFF06B6D4)],
};

List<Color> gradientePanel(String tema) =>
    temasPanel[tema] ?? temasPanel['aqua']!;

/// Emojis decorativos sugeridos para el panel (tema lavandería).
const iconosPanel = ['🧺', '🧼', '👕', '💧', '✨', '🧴', '🌊', '🧽'];
