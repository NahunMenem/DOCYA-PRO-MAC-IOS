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
import '../widgets/docya_snackbar.dart';
import '../main.dart'; // 👈 para usar navigatorKey

bool _modalConsultaAbierto = false;

Future<bool?> mostrarConsultaEntrante(
    BuildContext context, String profesionalId) async {
  if (_modalConsultaAbierto) return null;
  _modalConsultaAbierto = true;

  int segundosRestantes = 20;
  Timer? timer;

  // ==========================================================
  // 🔹 Pedimos la consulta al backend
  // ==========================================================
  final response = await http.get(
    Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/asignadas/$profesionalId"),
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode != 200) {
    _modalConsultaAbierto = false;
    DocYaSnackbar.show(
      navigatorKey.currentContext!,
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
      navigatorKey.currentContext!,
      title: "Sin consultas",
      message: "No hay consultas disponibles",
      type: SnackType.info,
    );
    return null;
  }

  // ==========================================================
  // 🔹 Info
  // ==========================================================
  final pacienteNombre =
      datos["paciente_nombre"] ?? "Paciente #${datos["paciente_uuid"]}";
  final iniciales = pacienteNombre
      .trim()
      .split(" ")
      .map((e) => e[0])
      .take(2)
      .join()
      .toUpperCase();

  final distanciaInfo =
      "${datos["distancia_km"] ?? "?"} km • ${datos["tiempo_estimado_min"] ?? "?"} min";

  final tipo = datos["tipo"] ?? "medico";

  // ==========================================================
  // 💰 TARIFAS – Día/Noche
  // ==========================================================
  final ahoraAR = DateTime.now().toUtc().subtract(const Duration(hours: 3));
  final hora = ahoraAR.hour;

  final esNocturno = (hora >= 22 || hora < 6);

  String tarifa = tipo == "medico"
      ? (esNocturno ? "40.000" : "30.000")
      : (esNocturno ? "30.000" : "20.000");

  debugPrint("💸 TIPO: $tipo | NOCHE: $esNocturno | TARIFA: $tarifa");

  // ==========================================================
  // 🔊 SONIDO + VIBRACIÓN (iOS + Android)
  // ==========================================================
  try {
    // vibración
    if (await Vibration.hasVibrator() ?? false) {
      if (!esNocturno) {
        Vibration.vibrate(pattern: [0, 300, 100, 300]);
      } else {
        Vibration.vibrate(duration: 400);
      }
    }

    // SONIDO
    final player = AudioPlayer();
    player.setReleaseMode(ReleaseMode.stop);

    if (!esNocturno) {
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOS debe usar CAF
        await player.play(AssetSource('sounds/alert.caf'));
      } else {
        // Android
        await player.play(AssetSource('sounds/alert.mp3'));
      }
    } else {
      debugPrint("🌙 Modo nocturno: sin sonido, solo vibración");
    }
  } catch (e) {
    debugPrint("❌ Error sonido/vibración: $e");
  }

  // ==========================================================
  // 🪟 MODAL
  // ==========================================================
  final result = await showModalBottomSheet<bool>(
    context: navigatorKey.currentContext!,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setModalState) {
        timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
          if (segundosRestantes > 0) {
            setModalState(() => segundosRestantes--);
          } else {
            t.cancel();
            Navigator.of(navigatorKey.currentContext!, rootNavigator: true)
                .pop(null);
            DocYaSnackbar.show(
              navigatorKey.currentContext!,
              title: "Tiempo agotado",
              message: "Consulta fue reasignada",
              type: SnackType.warning,
            );
          }
        });

        final progreso = segundosRestantes / 20;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withOpacity(0.90),
              child: _modalContenido(
                datos: datos,
                iniciales: iniciales,
                pacienteNombre: pacienteNombre,
                distanciaInfo: distanciaInfo,
                tarifa: tarifa,
                tipo: tipo,
                progreso: progreso,
                segundosRestantes: segundosRestantes,
                profesionalId: profesionalId,
                timer: timer!,
              ),
            ),
          ),
        );
      });
    },
  ).whenComplete(() {
    timer?.cancel();
    _modalConsultaAbierto = false;
  });

  return result;
}

// ==========================================================
// 🌟 CONTENIDO DEL MODAL SEPARADO PARA LIMPIEZA
// ==========================================================
Widget _modalContenido({
  required Map datos,
  required String iniciales,
  required String pacienteNombre,
  required String distanciaInfo,
  required String tarifa,
  required String tipo,
  required double progreso,
  required int segundosRestantes,
  required String profesionalId,
  required Timer timer,
}) {
  return Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF14B8A6),
              child: Text(
                iniciales,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
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
                    builder: (_, value, __) => CircularProgressIndicator(
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        _infoTile(Icons.location_on, "Dirección", datos["direccion"]),
        _infoTile(Icons.healing, "Motivo", datos["motivo"]),
        _infoTile(Icons.directions_car, "Distancia", distanciaInfo),
        _infoTile(Icons.monetization_on, "Pago", "\$$tarifa"),

        const SizedBox(height: 25),

        // BOTONES
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  timer.cancel();

                  Navigator.of(navigatorKey.currentContext!,
                          rootNavigator: true)
                      .pop(false);

                  await http.post(
                    Uri.parse(
                        "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/rechazar"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"medico_id": profesionalId}),
                  );

                  DocYaSnackbar.show(
                    navigatorKey.currentContext!,
                    title: "Consulta rechazada",
                    message: "Fue reasignada",
                    type: SnackType.info,
                  );
                },
                child: Text(
                  "Rechazar",
                  style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  timer.cancel();

                  final resp = await http.post(
                    Uri.parse(
                        "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/aceptar"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"medico_id": profesionalId}),
                  );

                  if (resp.statusCode == 200) {
                    DocYaSnackbar.show(
                      navigatorKey.currentContext!,
                      title: "Consulta aceptada",
                      message: "En camino al domicilio",
                      type: SnackType.success,
                    );

                    final ubicacion =
                        UbicacionMedicoManager(medicoId: int.parse(profesionalId), baseUrl:
                            "https://docya-railway-production.up.railway.app");
                    ubicacion.start();

                    Navigator.of(navigatorKey.currentContext!,
                            rootNavigator: true)
                        .pop(true);

                    Future.microtask(() {
                      Navigator.push(
                        navigatorKey.currentContext!,
                        MaterialPageRoute(
                          builder: (_) => MedicoEnCasaScreen(
                            tipo: tipo,
                            consultaId: datos["id"],
                            medicoId: int.parse(profesionalId),
                            pacienteUuid: datos["paciente_uuid"],
                            pacienteNombre: pacienteNombre,
                            direccion: datos["direccion"],
                            telefono: datos["paciente_telefono"],
                            motivo: datos["motivo"],
                            lat: (datos["lat"] as num?)?.toDouble() ?? 0.0,
                            lng: (datos["lng"] as num?)?.toDouble() ?? 0.0,
                            onFinalizar: () => Navigator.of(
                                    navigatorKey.currentContext!)
                                .popUntil((r) => r.isFirst),
                          ),
                        ),
                      );
                    });
                  }
                },
                child: Text(
                  "Aceptar",
                  style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    ),
  );
}

// ==========================================================
// INFO TILE
// ==========================================================
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
        subtitle:
            Text(value, style: GoogleFonts.manrope(color: Colors.black54)),
      ),
    ),
  );
}
