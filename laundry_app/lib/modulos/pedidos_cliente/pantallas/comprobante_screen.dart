import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/contrato/modelos/pedido.dart';
import 'historial_pedidos_screen.dart';

/// WF-18 · Comprobante digital (RF-32): reemplaza al recibo de papel.
/// Trae el código, la lavandería, las prendas y el total; se comparte o se
/// descarga en PDF.
class ComprobanteScreen extends StatelessWidget {
  final Pedido pedido;
  const ComprobanteScreen({super.key, required this.pedido});

  List<(String, String)> get _filas => [
    if (pedido.cantidadRopaRegular > 0)
      (
        'Ropa regular (por ${pedido.modoRopaRegular.name})',
        pedido.cantidadRopaRegular.toStringAsFixed(1),
      ),
    for (final e in pedido.prendas.entries) (e.key, '${e.value}'),
  ];

  String get _fecha => pedido.creadoEn == null
      ? '—'
      : DateFormat('dd/MM/yyyy HH:mm').format(pedido.creadoEn!);

  Future<pw.Document> _pdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Comprobante ${codigoPedido(pedido)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Lavandería ${pedido.lavanderiaNombre}'),
            pw.Text(
              'Cliente: ${pedido.clienteNombre.isEmpty ? '-' : pedido.clienteNombre} · $_fecha',
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Prenda', 'Cant.'],
              data: [
                for (final (a, b) in _filas) [a, b],
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Prendas: Bs ${pedido.costoPrendas.toStringAsFixed(2)}'),
            if (pedido.costoEnvio > 0)
              pw.Text('Envío: Bs ${pedido.costoEnvio.toStringAsFixed(2)}'),
            pw.Text(
              'Total: Bs ${pedido.costoTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: pedido.id,
              width: 90,
              height: 90,
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  Future<void> _compartir() async {
    final doc = await _pdf();
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'comprobante-${codigoPedido(pedido)}.pdf',
    );
  }

  Future<void> _descargar() async {
    final doc = await _pdf();
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'comprobante-${codigoPedido(pedido)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comprobante ${codigoPedido(pedido)}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primary,
                child: Icon(
                  Icons.local_laundry_service_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lavandería ${pedido.lavanderiaNombre}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${pedido.clienteNombre.isEmpty ? 'Cliente' : pedido.clienteNombre} · $_fecha',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.black12),
            columnWidths: const {1: IntrinsicColumnWidth()},
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0x110C5197)),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Prenda',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Cant.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              for (final (a, b) in _filas)
                TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(a)),
                    Padding(padding: const EdgeInsets.all(8), child: Text(b)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Prendas: Bs ${pedido.costoPrendas.toStringAsFixed(2)}'),
          if (pedido.costoEnvio > 0)
            Text(
              'Recojo a domicilio: Bs ${pedido.costoEnvio.toStringAsFixed(2)}',
            ),
          const SizedBox(height: 4),
          Text(
            'Total: Bs ${pedido.costoTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 110),
                  Text(
                    codigoPedido(pedido),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _compartir,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _descargar,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Descargar PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
