import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../screens/MedicoEnCasaScreen.dart';
import '../widgets/docya_snackbar.dart'; // ✅ tu snackbar glassmorphism

bool _modalConsultaAbierto = false;

Future<bool?> mostrarConsultaEntrante(
    BuildContext context, String profesionalId) async {
  if (_modalConsultaAbierto) return null;
  _modalConsultaAbierto = true;

  int segundosRestantes = 20;
  Timer? timer;

  // 🔹 Pedimos la consulta al backend
  final response = await http.get(
    Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/asignadas/$profesionalId"),
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode != 200) {
    _modalConsultaAbierto = false;
    DocYaSnackbar.show(
      context,
      title: "Error",
      message: "No se pudo obtener la consulta",
      type: SnackType.error,
    );
    return null;
  }

  final consulta = jsonDecode(response.body);
  final datos = consulta["consulta"] ?? consulta;
  if (datos == null || datos["id"] == null) {
    _modalConsultaAbierto = false;
    DocYaSnackbar.show(
      context,
      title: "Sin consultas",
      message: "No hay consultas disponibles por el momento",
      type: SnackType.info,
    );
    return null;
  }

  String pacienteNombre =
      datos["paciente_nombre"] ?? "Paciente #${datos["paciente_uuid"]}";
  String iniciales = pacienteNombre.isNotEmpty
      ? pacienteNombre
          .trim()
          .split(" ")
          .map((e) => e[0])
          .take(2)
          .join()
          .toUpperCase()
      : "P";
  String distanciaInfo =
      "${datos["distancia_km"] ?? "?"} km • ${datos["tiempo_estimado_min"] ?? "?"} min";
  String tipo = datos["tipo"] ?? "medico";
    // =============== TARIFA SEGÚN TIPO + HORARIO ARGENTINA =================
  final ahoraAR = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  final int hora = ahoraAR.hour;

  // 🔥 TARIFA NOCTURNA: 22:00 a 06:00
  final bool esNocturno = (hora >= 22 || hora < 6);

  String tarifa = "30.000";  // default médico diurno

  if (tipo == "medico") {
    tarifa = esNocturno ? "40.000" : "30.000";
  } else if (tipo == "enfermero") {
    tarifa = esNocturno ? "30.000" : "20.000";
  }

  debugPrint("💸 Tipo: $tipo  |  Nocturno: $esNocturno  |  Tarifa: $tarifa");


  // 🔊 Vibración + sonido de alerta
  try {
    final hora = DateTime.now().hour;
    final esNocturno = hora >= 23 || hora < 7;

    if (await Vibration.hasVibrator() ?? false) {
      if (!esNocturno) {
        Vibration.vibrate(pattern: [0, 300, 100, 300]);
      } else {
        Vibration.vibrate(duration: 400);
      }
    }

    if (!esNocturno) {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/alert.mp3'), volume: 1.0);
    } else {
      debugPrint("🌙 Modo nocturno: sin sonido (solo vibración).");
    }
  } catch (e) {
    debugPrint("⚠️ Error en vibración/sonido: $e");
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (segundosRestantes > 0) {
              setModalState(() => segundosRestantes--);
            } else {
              t.cancel();

              () async {
                // Notificar timeout al backend
                try {
                  await http.post(
                    Uri.parse(
                      "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/timeout",
                    ),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"medico_id": profesionalId}),
                  );
                } catch (e) {
                  debugPrint("❌ Error enviando timeout: $e");
                }

                if (Navigator.of(context).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop(null);

                  DocYaSnackbar.show(
                    context,
                    title: "Tiempo agotado",
                    message: "Consulta no respondida, fue reasignada",
                    type: SnackType.warning,
                  );
                }
              }();
            }
          });


          double progreso = segundosRestantes / 20;

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =======================
                      // 🧑 Header con avatar + contador
                      // =======================
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFF14B8A6),
                            child: Text(iniciales,
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                )),
                          ).animate().scaleXY(begin: 0.8, duration: 400.ms),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              pacienteNombre,
                              style: GoogleFonts.manrope(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(
                            height: 65,
                            width: 65,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 1, end: progreso),
                                  duration: const Duration(milliseconds: 500),
                                  builder: (_, value, __) =>
                                      CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 6,
                                    backgroundColor: Colors.grey.shade200,
                                    color: const Color(0xFF14B8A6),
                                  ),
                                ),
                                Text(
                                  "$segundosRestantes",
                                  style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // =======================
                      // 📋 Información
                      // =======================
                      _infoTile(Icons.location_on, "Dirección",
                          datos["direccion"] ?? "Desconocida"),
                      _infoTile(Icons.healing, "Motivo",
                          datos["motivo"] ?? "Sin motivo especificado"),
                      _infoTile(Icons.directions_car, "Distancia", distanciaInfo),
                      _infoTile(Icons.monetization_on, "Pago", "\$$tarifa"),

                      const SizedBox(height: 25),

                      // =======================
                      // 🎯 Botones aceptar / rechazar
                      // =======================
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              onPressed: () async {
                                timer?.cancel();
                                Navigator.of(context, rootNavigator: true)
                                    .pop(false);
                                await http.post(
                                  Uri.parse(
                                    "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/rechazar",
                                  ),
                                  headers: {
                                    "Content-Type": "application/json"
                                  },
                                  body: jsonEncode(
                                      {"medico_id": profesionalId}),
                                );
                                DocYaSnackbar.show(
                                  context,
                                  title: "Consulta rechazada",
                                  message: "Fue reasignada a otro profesional",
                                  type: SnackType.info,
                                );
                              },
                              child: Text("Rechazar",
                                  style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ).animate().fadeIn(duration: 400.ms),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: const Color(0xFF14B8A6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                              ),
                              onPressed: () async {
                                timer?.cancel();

                                final resp = await http.post(
                                  Uri.parse(
                                    "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/aceptar",
                                  ),
                                  headers: {
                                    "Content-Type": "application/json"
                                  },
                                  body: jsonEncode(
                                      {"medico_id": profesionalId}),
                                );

                                if (resp.statusCode == 200) {
                                  DocYaSnackbar.show(
                                    context,
                                    title: "Consulta aceptada",
                                    message:
                                        "Dirigite al domicilio del paciente",
                                    type: SnackType.success,
                                  );

                                  final ubicacionManager =
                                      UbicacionMedicoManager(
                                    medicoId: int.parse(profesionalId),
                                    baseUrl:
                                        "https://docya-railway-production.up.railway.app",
                                  );
                                  ubicacionManager.start();

                    
                                  if (context.mounted) {
                                    Navigator.of(context, rootNavigator: true).pop(true);

                                    Future.microtask(() {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MedicoEnCasaScreen(
                                            tipo: tipo, // 👈 acá decide si es médico o enfermero
                                            consultaId: datos["id"],
                                            medicoId: int.parse(profesionalId),
                                            pacienteUuid: datos["paciente_uuid"],
                                            pacienteNombre: pacienteNombre,
                                            direccion: datos["direccion"] ?? "Desconocida",
                                            telefono: datos["paciente_telefono"] ?? "Sin número",
                                            motivo: datos["motivo"] ?? "Sin motivo",
                                            lat: (datos["lat"] as num?)?.toDouble() ?? 0.0,
                                            lng: (datos["lng"] as num?)?.toDouble() ?? 0.0,
                                            onFinalizar: () => Navigator.of(context).popUntil((r) => r.isFirst),
                                          ),
                                        ),
                                      );
                                    });
                                  }

                                } else {
                                  DocYaSnackbar.show(
                                    context,
                                    title: "Error",
                                    message:
                                        "No se pudo aceptar la consulta (${resp.statusCode})",
                                    type: SnackType.error,
                                  );
                                }
                              },
                              child: Text("Aceptar",
                                  style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ).animate().fadeIn(duration: 400.ms),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    timer?.cancel();
    _modalConsultaAbierto = false;
  });

  return result;
}

// ===================================================
// 📍 Servicio de ubicación del médico
// ===================================================
class UbicacionMedicoManager {
  final int medicoId;
  final String baseUrl;
  Timer? _timer;

  UbicacionMedicoManager({required this.medicoId, required this.baseUrl});

  void start() {
    Geolocator.requestPermission();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final body = jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "disponible": false,
        });
        await http.post(
          Uri.parse("$baseUrl/medico/$medicoId/ubicacion"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } catch (e) {
        debugPrint("❌ Error ubicacion: $e");
      }
    });
  }

  void stop() => _timer?.cancel();
}

// ===================================================
// 🔹 InfoTile reutilizable
// ===================================================
Widget _infoTile(IconData icon, String title, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF14B8A6)),
        title: Text(title,
            style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        subtitle: Text(value,
            style: GoogleFonts.manrope(color: Colors.black54, fontSize: 15)),
      ),
    ),
  );
}
