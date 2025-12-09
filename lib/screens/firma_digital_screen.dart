import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:signature/signature.dart';
import 'inicio_screen.dart';
import '../widgets/docya_snackbar.dart';

class FirmaDigitalScreen extends StatefulWidget {
  final int medicoId;
  const FirmaDigitalScreen({super.key, required this.medicoId});

  @override
  State<FirmaDigitalScreen> createState() => _FirmaDigitalScreenState();
}

class _FirmaDigitalScreenState extends State<FirmaDigitalScreen>
    with SingleTickerProviderStateMixin {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _subiendo = false;
  bool _mostrarCanvas = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Bloquear orientación inicial en vertical
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _subirFirma(Uint8List firmaBytes) async {
    setState(() => _subiendo = true);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://docya-railway-production.up.railway.app/auth/medico/${widget.medicoId}/firma'),
    );

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      firmaBytes,
      filename: 'firma_${widget.medicoId}.png',
      contentType: MediaType('image', 'png'),
    ));

    final response = await request.send();
    setState(() => _subiendo = false);

    if (response.statusCode == 200) {
      DocYaSnackbar.show(
        context,
        title: "✅ Éxito",
        message: "Tu firma digital fue guardada correctamente.",
      );

      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => InicioScreen(
              userId: widget.medicoId.toString(),
            ),
          ),
          (route) => false,
        );
      });
    } else {
      DocYaSnackbar.show(
        context,
        title: "❌ Error",
        message: "No se pudo subir la firma. Intentalo nuevamente.",
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F2027),
          appBar: AppBar(
            title: const Text("Firma digital"),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: !_mostrarCanvas ? _introMessage() : _firmaContent(),
          ),
        ),
      ),
    );
  }

  /// 🧾 Mensaje inicial con glassmorphism
  Widget _introMessage() {
    return Stack(
      children: [
        const _BackgroundGradient(),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_document,
                    color: Color(0xFF14B8A6), size: 80),
                const SizedBox(height: 16),
                Text(
                  "Configuración de firma digital",
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Tu firma digital se usará automáticamente en recetas y certificados médicos de DocYa Pro.\n\n"
                  "Debe ser igual o muy similar a tu firma profesional registrada.",
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                    setState(() => _mostrarCanvas = true);
                  },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    "Entendido, continuar",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ✍️ Layout de firma (solo horizontal)
  Widget _firmaContent() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return const _RotateMessage();
        }
        return const _BackgroundGradient(
          child: _FirmaCanvas(),
        );
      },
    );
  }
}

/// Fondo degradado con blur
class _BackgroundGradient extends StatelessWidget {
  final Widget? child;
  const _BackgroundGradient({this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

/// Mensaje si no gira el celular
class _RotateMessage extends StatelessWidget {
  const _RotateMessage();

  @override
  Widget build(BuildContext context) {
    return const _BackgroundGradient(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.screen_rotation, color: Colors.white, size: 80),
            SizedBox(height: 20),
            Text(
              "Por favor, girá el dispositivo para firmar",
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Componente del canvas de firma
class _FirmaCanvas extends StatefulWidget {
  const _FirmaCanvas();

  @override
  State<_FirmaCanvas> createState() => _FirmaCanvasState();
}

class _FirmaCanvasState extends State<_FirmaCanvas> {
  @override
  Widget build(BuildContext context) {
    final parent = context.findAncestorStateOfType<_FirmaDigitalScreenState>()!;
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // ✅ Solución al overflow
          child: Column(
            children: [
              Text(
                "🖋️ Firma digital del profesional",
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Firmá dentro del recuadro con tu dedo o stylus.\nAsegurate de que la firma sea legible antes de guardarla.",
                style:
                    GoogleFonts.manrope(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Canvas de firma (altura ajustada)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  height: size.height * 0.45, // 🔧 más compacto
                  width: double.infinity,
                  child: Signature(
                    controller: parent._controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => parent._controller.clear(),
                    icon: const Icon(Icons.clear, color: Colors.white),
                    label: const Text(
                      "Borrar",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.tealAccent),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: parent._subiendo
                        ? null
                        : () async {
                            if (parent._controller.isEmpty) {
                              DocYaSnackbar.show(
                                context,
                                title: "✍️ Atención",
                                message:
                                    "Realizá tu firma antes de continuar.",
                                type: SnackType.warning,
                              );
                              return;
                            }
                            final firmaBytes =
                                await parent._controller.toPngBytes();
                            if (firmaBytes != null) {
                              await parent._subirFirma(firmaBytes);
                            }
                          },
                    icon: parent._subiendo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline,
                            color: Colors.white),
                    label: const Text(
                      "Guardar firma",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
