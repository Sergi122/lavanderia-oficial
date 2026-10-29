import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'validador_selfie.dart';

class ParSelfies {
  final Uint8List frente;
  final Uint8List lado;
  const ParSelfies({required this.frente, required this.lado});
}

/// Verificación biométrica estilo Persona/SumSub: cámara frontal en vivo,
/// un círculo guía con arco de progreso que se llena mientras la cara
/// cumple la pose pedida (de frente, luego de perfil) y auto-captura al
/// completarse. En la web no se ofrece este flujo (no hay forma confiable
/// de tomar la selfie desde el navegador): se muestra un aviso de que la
/// verificación es solo desde el celular. Si la cámara del celular falla
/// por algún motivo, cae a un flujo de respaldo con `image_picker`.
class CapturadorSelfieEnVivo extends StatefulWidget {
  final ValueChanged<ParSelfies> onCompletado;
  final VoidCallback? onCancelar;

  const CapturadorSelfieEnVivo({
    super.key,
    required this.onCompletado,
    this.onCancelar,
  });

  @override
  State<CapturadorSelfieEnVivo> createState() => _CapturadorSelfieEnVivoState();
}

/// Evita que los mensajes parpadeen (práctica común en SDKs de verificación
/// de identidad: un solo mensaje a la vez, que solo aparece si la condición
/// se mantiene un momento, y que se queda visible un mínimo antes de poder
/// cambiar o desaparecer).
class _GestorAvisos {
  static const _aparecerTras = Duration(milliseconds: 600);
  static const _minimoVisible = Duration(milliseconds: 3000);

  String? actual;
  DateTime _desde = DateTime.now();
  Duration _minimoActual = _minimoVisible;
  String? _candidato;
  DateTime _candidatoDesde = DateTime.now();

  /// Mensaje que se debería mostrar ahora (null = ninguno). Devuelve el
  /// mensaje efectivamente visible.
  String? pedir(String? deseado) {
    final ahora = DateTime.now();
    if (deseado == actual) {
      _candidato = null;
      return actual;
    }
    if (_candidato != deseado) {
      _candidato = deseado;
      _candidatoDesde = ahora;
    }
    final sostenido = ahora.difference(_candidatoDesde) >= _aparecerTras;
    final cumplioMinimo =
        actual == null || ahora.difference(_desde) >= _minimoActual;
    if (sostenido && cumplioMinimo) {
      actual = deseado;
      _desde = ahora;
      _minimoActual = _minimoVisible;
      _candidato = null;
    }
    return actual;
  }

  /// Mensaje importante: aparece ya y se queda más tiempo.
  String forzar(
    String texto, {
    Duration duracion = const Duration(seconds: 5),
  }) {
    actual = texto;
    _desde = DateTime.now();
    _minimoActual = duracion;
    _candidato = null;
    return texto;
  }

  void limpiar() {
    actual = null;
    _candidato = null;
  }
}

class _CapturadorSelfieEnVivoState extends State<CapturadorSelfieEnVivo> {
  final _avisos = _GestorAvisos();
  int? _idBloqueado;
  int _carasFramePrevio = 0;
  CameraController? _controller;
  FaceDetector? _detector;
  PoseSelfie _pose = PoseSelfie.frente;
  Uint8List? _frenteBytes;
  double _progreso = 0;
  bool _procesandoFrame = false;
  bool _capturando = false;
  String? _error;
  String? _aviso;
  // Diagnóstico visible en pantalla (también en release).
  int _frames = 0;
  bool _lentesDetectados = false;
  String _diag = 'esperando frames...';

  int _intentos = 0;
  Timer? _vigilante;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Pequeña espera: deja que la cámara trasera del carnet termine de
      // cerrarse (este tipo de celulares solo permite una cámara abierta).
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _iniciarCamara();
      });
    }
  }

  /// Si en 4 s no llegó ningún frame, la cámara no arrancó de verdad:
  /// se libera y se reintenta (hasta 3 veces).
  void _armarVigilante() {
    _vigilante?.cancel();
    _vigilante = Timer(const Duration(seconds: 4), () async {
      if (!mounted || _frames > 0 || _capturando) return;
      if (_intentos >= 3) {
        setState(() => _error = 'no-camara');
        return;
      }
      _intentos++;
      final viejo = _controller;
      setState(() {
        _controller = null;
        _diag = 'reintentando cámara ($_intentos/3)...';
      });
      try {
        await viejo?.dispose();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _iniciarCamara();
    });
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      final frontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );

      final controller = CameraController(
        frontal,
        // Baja a propósito: cada foto va como base64 dentro de un documento
        // de Firestore con límite de 1MB (ver maxTamanoFotoBytes en los
        // repos), y "low" ya alcanza de sobra para que ML Kit detecte cara
        // y ángulo de cabeza.
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          // Tracking y contornos son excluyentes en ML Kit; los contornos
          // ya no se usan.
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.2,
        ),
      );
      _controller = controller;
      setState(() {});
      await controller.startImageStream(_procesarFrame);
      _armarVigilante();
    } catch (e) {
      debugPrint(
        'No se pudo abrir la cámara en vivo, se usa respaldo manual: $e',
      );
      if (mounted) setState(() => _error = 'no-camara');
    }
  }

  InputImage? _inputImageDesdeFrame(
    CameraImage image,
    CameraDescription camara,
  ) {
    final rotacion =
        InputImageRotationValue.fromRawValue(camara.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final formato = InputImageFormatValue.fromRawValue(image.format.raw);
    if (formato == null) return null;
    if (image.planes.isEmpty) return null;
    final plano = image.planes.first;

    return InputImage.fromBytes(
      bytes: plano.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotacion,
        format: formato,
        bytesPerRow: plano.bytesPerRow,
      ),
    );
  }

  Future<void> _procesarFrame(CameraImage image) async {
    final controller = _controller;
    final detector = _detector;
    if (controller == null ||
        detector == null ||
        _procesandoFrame ||
        _capturando)
      return;
    _procesandoFrame = true;
    _frames++;
    try {
      final inputImage = _inputImageDesdeFrame(image, controller.description);
      if (inputImage == null) {
        if (mounted)
          setState(
            () => _diag =
                'f=$_frames inputImage NULL fmt=${image.format.raw} planos=${image.planes.length}',
          );
        return;
      }

      final caras = await detector.processImage(inputImage);
      if (!mounted) return;

      _diag =
          'f=$_frames ${image.width}x${image.height} rot=${controller.description.sensorOrientation} caras=${caras.length}';

      if (caras.length != 1) {
        _carasFramePrevio = caras.length;
        setState(() {
          // Antes bajaba 0.12 por frame: una pérdida momentánea del rostro
          // (común al girar la cabeza para el perfil) tiraba todo el
          // progreso abajo. Ahora es más gradual.
          _progreso = (_progreso - 0.04).clamp(0, 1);
          _aviso = _avisos.pedir(
            caras.isEmpty
                ? 'No vemos tu cara, acércate un poco'
                : 'Solo debe verse una persona',
          );
        });
        return;
      }

      final cara = caras.first;

      // ¿Cambió la persona? Si el ID de seguimiento cambia entre dos frames
      // seguidos con una sola cara, es otra persona. Si la cara desapareció
      // un rato (p. ej. al girar el perfil) no se puede saber, se acepta.
      final id = cara.trackingId;
      if (id != null) {
        if (_idBloqueado == null) {
          _idBloqueado = id;
        } else if (id != _idBloqueado) {
          if (_carasFramePrevio == 1) {
            _reiniciar(
              mensaje:
                  'Cambió la persona frente a la cámara. Volvemos a empezar',
            );
            _carasFramePrevio = 1;
            return;
          }
          _idBloqueado = id;
        }
      }
      _carasFramePrevio = 1;

      final progresoFrame = progresoPose(cara, _pose);
      debugPrint(
        'verif: pose=$_pose giroY=${cara.headEulerAngleY} X=${cara.headEulerAngleX} '
        'progFrame=${progresoFrame.toStringAsFixed(2)} prog=${_progreso.toStringAsFixed(2)}',
      );
      // Suavizado más "perezoso" (antes 0.55/0.45): un frame malo aislado
      // (parpadeo, jitter) ya no hace retroceder tanto el progreso.
      final nuevoProgreso = (_progreso * 0.7 + progresoFrame * 0.3)
          .clamp(0, 1)
          .toDouble();

      setState(() {
        _progreso = nuevoProgreso;
        _aviso = _avisos.pedir(
          _lentesDetectados
              ? 'Detectamos lentes. Quítatelos para continuar'
              : (pareceOcluida(cara)
                    ? 'Quítate lentes oscuros, gorra o sombrero'
                    : null),
        );
        _diag +=
            ' Y=${cara.headEulerAngleY?.toStringAsFixed(0)} X=${cara.headEulerAngleX?.toStringAsFixed(0)} '
            'ojos=${cara.leftEyeOpenProbability?.toStringAsFixed(1)}/${cara.rightEyeOpenProbability?.toStringAsFixed(1)}';
      });

      // Antes exigía _progreso >= 0.999 (prácticamente perfecto); con 0.9
      // ya alcanza sostener la pose un momento, sin dejar de exigir la
      // pose real (cumplePose) en el instante de la captura.
      if (cumplePose(cara, _pose) && _progreso >= 0.9) {
        await _capturarPose();
      }
    } catch (e) {
      debugPrint('Error procesando frame de verificación: $e');
      if (mounted) setState(() => _diag = 'f=$_frames ERROR: $e');
    } finally {
      _procesandoFrame = false;
    }
  }

  /// "No eres tú" / volver a empezar: descarta lo capturado y reinicia.
  void _reiniciar({String? mensaje}) {
    if (_capturando) return;
    setState(() {
      _pose = PoseSelfie.frente;
      _frenteBytes = null;
      _progreso = 0;
      _idBloqueado = null;
      _lentesDetectados = false;
      _aviso = mensaje == null
          ? (_avisos..limpiar()).actual
          : _avisos.forzar(mensaje);
    });
  }

  Future<void> _capturarPose() async {
    final controller = _controller;
    if (controller == null || _capturando) return;
    _capturando = true;
    try {
      await controller.stopImageStream();
      final foto = await controller.takePicture();
      final bytes = await foto.readAsBytes();

      final lentes = await detectarLentes(foto.path);
      if (lentes.hayLentes) {
        if (!mounted) return;
        setState(() {
          _lentesDetectados = true;
          _progreso = 0;
          _aviso = _avisos.forzar(
            'Detectamos lentes. Quítatelos para continuar',
          );
          _diag = 'etiquetas: ${lentes.etiquetas}';
        });
        await controller.startImageStream(_procesarFrame);
        return;
      }
      if (mounted) {
        setState(() {
          _lentesDetectados = false;
          _diag = 'etiquetas: ${lentes.etiquetas}';
        });
      }

      if (_pose == PoseSelfie.frente) {
        setState(() {
          _frenteBytes = bytes;
          _pose = PoseSelfie.lado;
          _progreso = 0;
        });
        await controller.startImageStream(_procesarFrame);
      } else {
        widget.onCompletado(ParSelfies(frente: _frenteBytes!, lado: bytes));
      }
    } catch (e) {
      debugPrint('No se pudo capturar la foto: $e');
      if (mounted)
        setState(() => _aviso = 'No se pudo tomar la foto, sigue intentando');
    } finally {
      _capturando = false;
    }
  }

  @override
  void dispose() {
    _vigilante?.cancel();
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _BloqueoSoloCelular();
    }
    if (_error == 'no-camara') {
      return _RespaldoManual(onCompletado: widget.onCompletado);
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        Text(
          _pose.instruccion,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          _pose == PoseSelfie.frente
              ? 'Encaja tu cara en el círculo, con buena luz'
              : 'Sigue girando hasta que el arco se complete',
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize?.height ?? 240,
                      height: controller.value.previewSize?.width ?? 240,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size(260, 260),
                painter: _ArcoProgresoPainter(progreso: _progreso),
              ),
              if (_frenteBytes != null && _pose == PoseSelfie.lado)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _diag,
          style: const TextStyle(color: Colors.black38, fontSize: 10),
        ),
        // Banner de altura fija: el mensaje aparece y desaparece sin mover
        // el resto de la pantalla.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _aviso == null
              ? const SizedBox(key: ValueKey('sin-aviso'), height: 56)
              : Container(
                  key: ValueKey(_aviso),
                  constraints: const BoxConstraints(minHeight: 56),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _aviso!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => _reiniciar(),
          icon: const Icon(Icons.person_off_outlined, size: 18),
          label: const Text('¿No eres tú? Volver a empezar'),
        ),
        if (widget.onCancelar != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onCancelar,
            child: const Text('Cancelar'),
          ),
        ],
      ],
    );
  }
}

class _ArcoProgresoPainter extends CustomPainter {
  final double progreso;
  const _ArcoProgresoPainter({required this.progreso});

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2 - 4;

    final fondo = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(centro, radio, fondo);

    final color = Color.lerp(
      Colors.redAccent,
      Colors.green,
      progreso.clamp(0, 1),
    )!;
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: radio),
      -math.pi / 2,
      2 * math.pi * progreso.clamp(0, 1),
      false,
      trazo,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcoProgresoPainter oldDelegate) =>
      oldDelegate.progreso != progreso;
}

/// Aviso que reemplaza el flujo de selfie cuando se entra desde la web: no
/// se puede verificar identidad con foto desde el navegador, hay que usar
/// el celular. La gestión del negocio (pedidos, finanzas, empleados) sí
/// sigue disponible en la web sin restricción.
class _BloqueoSoloCelular extends StatelessWidget {
  const _BloqueoSoloCelular();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phone_iphone_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verificación disponible solo desde el celular',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Para verificar tu identidad con cámara en vivo necesitás abrir la app '
            'desde tu celular; la web no da soporte a este paso.\n\n'
            'Si ya formás parte de una lavandería y solo querés administrarla '
            '(pedidos, finanzas, empleados), podés seguir haciéndolo desde acá, '
            'en la web.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Flujo de respaldo si la cámara en vivo del celular no se pudo abrir: dos
/// fotos manuales con `image_picker`, validadas foto por foto igual que
/// antes.
class _RespaldoManual extends StatefulWidget {
  final ValueChanged<ParSelfies> onCompletado;
  const _RespaldoManual({required this.onCompletado});

  @override
  State<_RespaldoManual> createState() => _RespaldoManualState();
}

class _RespaldoManualState extends State<_RespaldoManual> {
  Uint8List? _frente;
  Uint8List? _lado;
  bool _validando = false;
  String? _error;

  Future<void> _tomar(PoseSelfie pose) async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 640,
      imageQuality: 60,
    );
    if (archivo == null) return;

    setState(() {
      _validando = true;
      _error = null;
    });
    final resultado = await validarSelfie(archivo.path, pose);
    if (!resultado.valida) {
      setState(() {
        _validando = false;
        _error = resultado.mensaje;
      });
      return;
    }
    final bytes = await archivo.readAsBytes();
    setState(() {
      _validando = false;
      if (pose == PoseSelfie.frente) {
        _frente = bytes;
      } else {
        _lado = bytes;
      }
    });
    if (_frente != null && _lado != null) {
      widget.onCompletado(ParSelfies(frente: _frente!, lado: _lado!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _validando ? null : () => _tomar(PoseSelfie.frente),
          icon: Icon(
            _frente != null ? Icons.check_circle : Icons.camera_alt_outlined,
            color: _frente != null ? Colors.green : null,
          ),
          label: Text(
            _frente != null
                ? 'Selfie de frente lista'
                : 'Tomar selfie de frente',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _validando || _frente == null
              ? null
              : () => _tomar(PoseSelfie.lado),
          icon: Icon(
            _lado != null ? Icons.check_circle : Icons.camera_alt_outlined,
            color: _lado != null
                ? Colors.green
                : (_frente == null ? Colors.black26 : null),
          ),
          label: Text(
            _lado != null ? 'Selfie de perfil lista' : 'Tomar selfie de perfil',
          ),
        ),
        if (_validando)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
