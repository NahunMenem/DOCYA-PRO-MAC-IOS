import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class ConsultaDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> consulta;
  const ConsultaDetalleScreen({super.key, required this.consulta});

  @override
  State<ConsultaDetalleScreen> createState() => _ConsultaDetalleScreenState();
}

class _ConsultaDetalleScreenState extends State<ConsultaDetalleScreen> {
  bool _tieneReceta = false;
  bool _tieneCertificado = false;
  bool _loading = false;

  Color _colorEstado(String estado) {
    switch (estado) {
      case "finalizada":
        return const Color(0xFF22C55E);
      case "rechazada":
        return const Color(0xFFEF4444);
      case "en_camino":
        return const Color(0xFFF97316);
      case "en_domicilio":
        return const Color(0xFF3B82F6);
      case "aceptada":
        return const Color(0xFF14B8A6);
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  void initState() {
    super.initState();
    _verificarArchivos();
  }

  Future<void> _verificarArchivos() async {
    setState(() => _loading = true);
    try {
      final pacienteUuid = widget.consulta["paciente_uuid"];
      final res = await http.get(Uri.parse(
          "https://docya-railway-production.up.railway.app/pacientes/$pacienteUuid/archivos"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          for (var a in data) {
            if (a["url"].toString().contains("/receta")) _tieneReceta = true;
            if (a["url"].toString().contains("/certificado")) _tieneCertificado = true;
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando archivos: $e");
    }
    setState(() => _loading = false);
  }

  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo abrir el enlace")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consulta;
    final estado = c["estado"] ?? "desconocido";
    final color = _colorEstado(estado);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Detalle de Consulta",
            style: GoogleFonts.manrope(
                color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.only(
                    top: kToolbarHeight + 30, left: 20, right: 20, bottom: 40),
                children: [
                  // Estado
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          border: Border.all(color: color.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: color, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                "Estado: ${estado.toUpperCase()}",
                                style: GoogleFonts.manrope(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3),
                  const SizedBox(height: 25),

                  _infoCard(
                      icon: Icons.healing,
                      titulo: "Motivo",
                      contenido: c["motivo"] ?? "Sin motivo especificado"),
                  _infoCard(
                      icon: Icons.person,
                      titulo: "Paciente",
                      contenido: c["paciente_nombre"] ?? "Desconocido"),
                  _infoCard(
                      icon: Icons.location_on_outlined,
                      titulo: "Dirección",
                      contenido: c["direccion"] ?? "No disponible"),
                  _infoCard(
                      icon: Icons.calendar_today,
                      titulo: "Fecha",
                      contenido: c["creado_en"] ?? "—"),

                  const SizedBox(height: 35),

                  if (estado == "finalizada" &&
                      (_tieneReceta || _tieneCertificado))
                    Column(
                      children: [
                        if (_tieneReceta)
                          _botonAccion(
                            context,
                            icon: Icons.receipt_long,
                            label: "Ver receta médica",
                            color: const Color(0xFF14B8A6),
                            onTap: () => _abrirEnlace(
                                "https://docya-railway-production.up.railway.app/consultas/${c["id"]}/receta"),
                          ),
                        if (_tieneReceta) const SizedBox(height: 15),
                        if (_tieneCertificado)
                          _botonAccion(
                            context,
                            icon: Icons.description_outlined,
                            label: "Ver certificado",
                            color: Colors.blueAccent,
                            onTap: () => _abrirEnlace(
                                "https://docya-railway-production.up.railway.app/consultas/${c["id"]}/certificado"),
                          ),
                      ],
                    )
                  else if (estado == "finalizada")
                    Center(
                        child: Text(
                      "Sin receta ni certificado generados",
                      style: GoogleFonts.manrope(
                          color: Colors.white54, fontSize: 15),
                    )),
                ],
              ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String titulo,
    required String contenido,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF14B8A6), size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: GoogleFonts.manrope(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(contenido,
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonAccion(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label,
          style:
              GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 16)),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }
}
