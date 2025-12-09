import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'ConsultaDetalleScreen.dart';

class HistorialScreen extends StatefulWidget {
  final int medicoId;
  const HistorialScreen({super.key, required this.medicoId});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<dynamic> _consultas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    try {
      final url =
          "https://docya-railway-production.up.railway.app/consultas/historial_medico/${widget.medicoId}";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          _consultas = jsonDecode(res.body);
          _loading = false;
        });
      } else {
        throw Exception("Error ${res.statusCode}");
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("⚠️ Error: $e")));
    }
  }

  Color _estadoColor(String e) {
    switch (e) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Historial de Consultas",
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _consultas.isEmpty
                ? Center(
                    child: Text("No hay consultas registradas",
                        style: GoogleFonts.manrope(
                            color: Colors.white70, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        top: kToolbarHeight + 25, left: 20, right: 20),
                    itemCount: _consultas.length,
                    itemBuilder: (context, i) {
                      final c = _consultas[i];
                      final estado = c["estado"] ?? "desconocido";
                      final color = _estadoColor(estado);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConsultaDetalleScreen(consulta: c),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.local_hospital,
                                                  color: Colors.white70,
                                                  size: 18),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Consulta #${c["id"]}",
                                                style: GoogleFonts.manrope(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      color.withOpacity(0.5)),
                                            ),
                                            child: Text(
                                              estado.toUpperCase(),
                                              style: GoogleFonts.manrope(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        c["motivo"] ??
                                            "Sin motivo especificado",
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline,
                                              size: 18,
                                              color: Colors.white60),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c["paciente_nombre"] ?? "—",
                                              style: GoogleFonts.manrope(
                                                color: Colors.white70,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                              Icons.location_on_outlined,
                                              size: 18,
                                              color: Colors.white60),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c["direccion"] ?? "—",
                                              style: GoogleFonts.manrope(
                                                  color: Colors.white70,
                                                  fontSize: 15),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "📅 ${c["creado_en"]}",
                                            style: GoogleFonts.manrope(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(Icons.arrow_forward_ios,
                                                  size: 14,
                                                  color:
                                                      Colors.white.withOpacity(
                                                          0.7)),
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15);
                    },
                  ),
      ),
    );
  }
}
