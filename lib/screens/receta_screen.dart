import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
class RecetaScreen extends StatefulWidget {
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;
  final String pacienteNombre;

  const RecetaScreen({
    super.key,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
    required this.pacienteNombre,
  });

  @override
  State<RecetaScreen> createState() => _RecetaScreenState();
}

class _RecetaScreenState extends State<RecetaScreen> {
  final _diagnosticoCtrl = TextEditingController();
  final _obraSocialCtrl = TextEditingController();
  final _credencialCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _dosisCtrl = TextEditingController();
  final _frecuenciaCtrl = TextEditingController();
  final _duracionCtrl = TextEditingController();

  final List<Map<String, String>> _medicamentos = [];
  bool _generando = false;

  void _agregarMedicamento() {
    if (_nombreCtrl.text.isEmpty ||
        _dosisCtrl.text.isEmpty ||
        _frecuenciaCtrl.text.isEmpty ||
        _duracionCtrl.text.isEmpty) {
      _showSnack("⚠️ Completa todos los campos del medicamento", Colors.orangeAccent);
      return;
    }

    setState(() {
      _medicamentos.add({
        "nombre": _nombreCtrl.text,
        "dosis": _dosisCtrl.text,
        "frecuencia": _frecuenciaCtrl.text,
        "duracion": _duracionCtrl.text,
      });
      _nombreCtrl.clear();
      _dosisCtrl.clear();
      _frecuenciaCtrl.clear();
      _duracionCtrl.clear();
    });
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

  Future<void> _abrirRecetaDigital() async {
    if (_diagnosticoCtrl.text.isEmpty || _medicamentos.isEmpty) {
      _showSnack("⚠️ Agrega diagnóstico y al menos un medicamento", Colors.orangeAccent);
      return;
    }

    setState(() => _generando = true);
    try {
      final response = await http.post(
        Uri.parse("https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/receta"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "medico_id": widget.medicoId,
          "paciente_uuid": widget.pacienteUuid,
          "obra_social": _obraSocialCtrl.text,
          "nro_credencial": _credencialCtrl.text,
          "diagnostico": _diagnosticoCtrl.text,
          "medicamentos": _medicamentos,
        }),
      );

      if (response.statusCode != 200) throw Exception("Error guardando receta");

      final data = jsonDecode(response.body);
      final recetaId = data["receta_id"];
      if (recetaId == null) throw Exception("No se recibió ID de receta");

      _showSnack("✅ Receta generada correctamente", const Color(0xFF14B8A6));

      await Future.delayed(const Duration(milliseconds: 700));
https://docya-railway-production.up.railway.app/
      final uri = Uri.parse("https://docya-railway-production.up.railway.app/ver_receta/$recetaId");
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("No se pudo abrir la receta digital");
      }
    } catch (e) {
      _showSnack("❌ Error: $e", Colors.redAccent);
    } finally {
      setState(() => _generando = false);
    }
  }

  Future<void> _abrirBuscadorOficial() async {
    const url = 'https://www.argentina.gob.ar/precios-de-medicamentos';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack("❌ No se pudo abrir el buscador oficial", Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Receta Médica"),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle("👨‍⚕️ Profesional"),
                      _infoLine(PhosphorIconsRegular.identificationCard, "Médico ID", widget.medicoId.toString()),
                      const SizedBox(height: 16),
                      _sectionTitle("🧍 Paciente"),
                      _infoLine(PhosphorIconsRegular.user, "Nombre", widget.pacienteNombre),
                      const SizedBox(height: 16),
                      _inputField(_obraSocialCtrl, "Obra social", "Ej: OSDE / PAMI"),
                      const SizedBox(height: 10),
                      _inputField(_credencialCtrl, "N° de credencial", "Ej: 456789123"),
                      const SizedBox(height: 10),
                      _inputField(_diagnosticoCtrl, "Diagnóstico", "Ej: Faringitis aguda"),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),

                const SizedBox(height: 24),

                _sectionTitle("💊 Medicamentos"),

                // 🔹 Botón para abrir buscador oficial
                GestureDetector(
                  onTap: _abrirBuscadorOficial,
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.tealAccent),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.tealAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Abrir buscador oficial de medicamentos",
                            style: TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _inputField(_nombreCtrl, "Medicamento", "Ej: Amoxicilina 500mg"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _inputField(_dosisCtrl, "Dosis", "1 comprimido")),
                    const SizedBox(width: 10),
                    Expanded(child: _inputField(_frecuenciaCtrl, "Frecuencia", "cada 8 hs")),
                  ],
                ),
                const SizedBox(height: 8),
                _inputField(_duracionCtrl, "Duración", "por 7 días"),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: _agregarMedicamento,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.tealAccent),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIconsRegular.plusCircle, color: Colors.tealAccent),
                          SizedBox(width: 8),
                          Text("Agregar medicamento",
                              style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 16),
                ..._medicamentos.map((m) => _medicamentoTile(m)).toList(),

                const SizedBox(height: 24),

                // 🔹 Botón generar receta digital
                GestureDetector(
                  onTap: _generando ? null : _abrirRecetaDigital,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 55,
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
                        )
                      ],
                    ),
                    child: Center(
                      child: _generando
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
                                const Icon(PhosphorIconsRegular.arrowSquareOut, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  "Ver Receta Digital",
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🩺 COMPONENTES UI
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            color: Colors.tealAccent,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      );

  Widget _infoLine(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$label: $value",
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      );

  Widget _inputField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
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

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
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

  Widget _medicamentoTile(Map<String, String> m) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          title: Text(
            m["nombre"]!,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "${m["dosis"]}, ${m["frecuencia"]}, ${m["duracion"]}",
            style: GoogleFonts.manrope(color: Colors.white70),
          ),
          trailing: IconButton(
            icon: const Icon(PhosphorIconsRegular.trash, color: Colors.redAccent),
            onPressed: () => setState(() => _medicamentos.remove(m)),
          ),
        ),
      );
}