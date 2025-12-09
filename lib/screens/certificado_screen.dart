import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class CertificadoScreen extends StatefulWidget {
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;
  final String pacienteNombre;

  const CertificadoScreen({
    super.key,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
    required this.pacienteNombre,
  });

  @override
  State<CertificadoScreen> createState() => _CertificadoScreenState();
}

class _CertificadoScreenState extends State<CertificadoScreen> {
  final _diagnosticoCtrl = TextEditingController();
  final _reposoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  bool _guardando = false;

  Future<void> _guardarYVerCertificado() async {
    if (_diagnosticoCtrl.text.isEmpty || _reposoCtrl.text.isEmpty) {
      _showSnack("⚠️ Completá todos los campos obligatorios", Colors.orangeAccent);
      return;
    }

    setState(() => _guardando = true);

    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/certificado");

      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "medico_id": widget.medicoId,
          "paciente_uuid": widget.pacienteUuid,
          "diagnostico": _diagnosticoCtrl.text,
          "reposo_dias": _reposoCtrl.text,
          "observaciones": _observacionesCtrl.text,
        }),
      );

      if (resp.statusCode == 200) {
        final pdfUrl =
            "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/certificado";
        await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);

        if (mounted) {
          Navigator.pop(context);
          _showSnack("✅ Certificado generado correctamente", const Color(0xFF14B8A6));
        }
      } else {
        _showSnack("⚠️ Error al generar: ${resp.body}", Colors.redAccent);
      }
    } catch (e) {
      _showSnack("❌ Error: $e", Colors.redAccent);
    }

    setState(() => _guardando = false);
  }

  void _showSnack(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Certificado Médico"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              children: [
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          widget.pacienteNombre,
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle("🩺 Diagnóstico"),
                      _inputField(_diagnosticoCtrl,
                          "Diagnóstico", "Ej: Cuadro febril por infección respiratoria"),
                      const SizedBox(height: 16),
                      _sectionTitle("🛏️ Días de reposo"),
                      _inputField(_reposoCtrl, "Días", "Ej: 3 días de reposo domiciliario",
                          inputType: TextInputType.number),
                      const SizedBox(height: 16),
                      _sectionTitle("🧾 Observaciones"),
                      _inputField(_observacionesCtrl, "Observaciones",
                          "Ej: Control médico si persisten síntomas",
                          maxLines: 4),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),

                const SizedBox(height: 30),

                GestureDetector(
                  onTap: _guardando ? null : _guardarYVerCertificado,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 55,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF14B8A6), Color(0xFF0F2027)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _guardando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(PhosphorIconsRegular.filePdf,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  "Generar y Ver Certificado",
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 30),
                Text(
                  "DocYa © 2025",
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------
  // 🧩 COMPONENTES UI
  // -------------------

  Widget _sectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            text,
            style: GoogleFonts.manrope(
              color: Colors.tealAccent,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
      );

  Widget _inputField(TextEditingController controller, String label, String hint,
      {int maxLines = 1, TextInputType? inputType}) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      style: GoogleFonts.manrope(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              border: Border.all(color: Colors.white10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
        ),
      );
}
