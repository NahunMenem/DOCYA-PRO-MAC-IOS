import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class HistoriaClinicaScreen extends StatefulWidget {
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;

  const HistoriaClinicaScreen({
    super.key,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
  });

  @override
  State<HistoriaClinicaScreen> createState() => _HistoriaClinicaScreenState();
}

class _HistoriaClinicaScreenState extends State<HistoriaClinicaScreen> {
  final _motivoCtrl = TextEditingController();
  final _taCtrl = TextEditingController();
  final _satCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _fcCtrl = TextEditingController();
  final _respiratorioCtrl = TextEditingController();
  final _cardioCtrl = TextEditingController();
  final _abdomenCtrl = TextEditingController();
  final _sncCtrl = TextEditingController();
  final _observacionCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();

  bool _guardando = false;

  Future<void> _guardarHistoria() async {
    if (_motivoCtrl.text.isEmpty || _diagnosticoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ Complete motivo y diagnóstico"),
        backgroundColor: Colors.orangeAccent,
      ));
      return;
    }

    setState(() => _guardando = true);
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/nota");

      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "medico_id": widget.medicoId,
          "paciente_uuid": widget.pacienteUuid,
          "contenido": jsonEncode({
            "motivo": _motivoCtrl.text,
            "signos_vitales": {
              "ta": _taCtrl.text,
              "sat": _satCtrl.text,
              "temp": _tempCtrl.text,
              "fc": _fcCtrl.text,
            },
            "respiratorio": _respiratorioCtrl.text,
            "cardio": _cardioCtrl.text,
            "abdomen": _abdomenCtrl.text,
            "snc": _sncCtrl.text,
            "observacion": _observacionCtrl.text,
            "diagnostico": _diagnosticoCtrl.text,
          }),
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Historia clínica guardada"),
          backgroundColor: Color(0xFF14B8A6),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: ${resp.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Historia Clínica"),
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            child: Column(
              children: [
                _glassCard(
                  child: Column(
                    children: [
                      _sectionTitle("🩺 Motivo de consulta"),
                      _inputField(_motivoCtrl, "Motivo", "Ej: fiebre de 48hs"),
                      const SizedBox(height: 16),
                      _sectionTitle("❤️ Signos Vitales"),
                      Row(
                        children: [
                          Expanded(child: _inputField(_taCtrl, "TA", "120/80")),
                          const SizedBox(width: 8),
                          Expanded(child: _inputField(_satCtrl, "Sat%", "98%")),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _inputField(_tempCtrl, "T°", "37.5")),
                          const SizedBox(width: 8),
                          Expanded(child: _inputField(_fcCtrl, "FC", "80 lpm")),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle("🫁 Examen Físico"),
                      _inputField(_respiratorioCtrl, "Aparato respiratorio", "MVB+ sin ruidos"),
                      const SizedBox(height: 10),
                      _inputField(_cardioCtrl, "Cardiovascular", "R1 R2 normofonético"),
                      const SizedBox(height: 10),
                      _inputField(_abdomenCtrl, "Abdomen", "Blando, depresible, indoloro"),
                      const SizedBox(height: 10),
                      _inputField(_sncCtrl, "Sistema nervioso", "Lúcido, orientado"),
                      const SizedBox(height: 10),
                      _inputField(_observacionCtrl, "Observaciones", "Opcional"),
                      const SizedBox(height: 16),
                      _sectionTitle("🧠 Diagnóstico"),
                      _inputField(_diagnosticoCtrl, "Diagnóstico", "Síndrome febril"),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: _guardando ? null : _guardarHistoria,
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
                        )
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
                                const Icon(PhosphorIconsRegular.floppyDisk, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  "Guardar Historia Clínica",
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

  // -------------------------
  // 🧩 COMPONENTES DE UI
  // -------------------------

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
