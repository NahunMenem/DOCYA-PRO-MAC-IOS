// ==================================================
// 🧭 INICIOSCREEN (DocYa Pro) – VERSION FINAL SIN WEBSOCKET EN UI
// ==================================================

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/background_service.dart';
import '../utils/local_notifications.dart';
import '../widgets/consulta_entrante_modal.dart';
import '../widgets/docya_snackbar.dart';
import '../widgets/recordatorio_elementos_medico.dart';

class InicioScreen extends StatefulWidget {
  final String userId;

  const InicioScreen({
    super.key,
    required this.userId,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with SingleTickerProviderStateMixin {
  bool disponible = false;
  bool mostrarRecordatorio = false;
  late GoogleMapController _mapController;
  int totalConsultas = 0;
  int totalGanancias = 0;

  late AnimationController _pulseController;

  final String _mapStyle = '''
  [
    {"elementType": "geometry","stylers":[{"color":"#122932"}]},
    {"elementType": "labels.text.fill","stylers":[{"color":"#E0F2F1"}]},
    {"elementType": "labels.text.stroke","stylers":[{"color":"#0B1A22"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#155E63"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#18A999"}]},
    {"featureType":"water","stylers":[{"color":"#0C2F3A"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: false);

    _cargarDisponibilidad();
    _cargarStats();
    _escucharEventosBackground();
    _mostrarRecordatorioSiCorresponde();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _detenerServicioBackground();
    super.dispose();
  }

  // --------------------------------------------------------
  // 🔔 ESCUCHAR EVENTOS DEL BACKGROUND SERVICE
  // --------------------------------------------------------
  void _escucharEventosBackground() {
    final service = FlutterBackgroundService();

    service.on("consulta_nueva").listen((data) {
      mostrarConsultaEntrante(context, widget.userId);
      _cargarStats();
    });
  }


  Future<bool> _pedirPermisosUbicacion(BuildContext context) async {
    // 1) Permiso cuando la app está en uso
    var statusWhen = await Permission.locationWhenInUse.status;

    if (!statusWhen.isGranted) {
      statusWhen = await Permission.locationWhenInUse.request();
    }

    if (!statusWhen.isGranted) {
      DocYaSnackbar.show(
        context,
        title: "Permiso requerido",
        message: "Debes otorgar acceso a tu ubicación para recibir consultas.",
        type: SnackType.error,
      );
      return false;
    }

    // 2) Permiso en segundo plano (Android 10+)
    var statusAlways = await Permission.locationAlways.status;

    if (!statusAlways.isGranted) {
      statusAlways = await Permission.locationAlways.request();
    }

    if (!statusAlways.isGranted) {
      DocYaSnackbar.show(
        context,
        title: "Permiso requerido",
        message:
            "Necesitamos permiso de ubicación en segundo plano para enviarte consultas incluso con la pantalla bloqueada.",
        type: SnackType.error,
      );
      return false;
    }

    return true;
  }



  // --------------------------------------------------------
  // Cargar disponibilidad
  // --------------------------------------------------------
  Future<void> _cargarDisponibilidad() async {
    final prefs = await SharedPreferences.getInstance();
    disponible = prefs.getBool("disponible") ?? false;
    if (mounted) setState(() {});
  }

  Future<void> _guardarDisponibilidad(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("disponible", value);
  }

  // --------------------------------------------------------
  // Cargar estadísticas
  // --------------------------------------------------------
  Future<void> _cargarStats() async {
    try {
      final res = await http.get(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/auth/medico/${widget.userId}/stats"),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          totalConsultas = data["consultas"] ?? 0;
          totalGanancias = ((data["ganancias"] ?? 0) * 0.8).round();
        });
      }
    } catch (_) {}
  }

  // --------------------------------------------------------
  // RECORDATORIO DIARIO
  // --------------------------------------------------------
  Future<void> _mostrarRecordatorioSiCorresponde() async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final ultima = prefs.getString('ultimo_recordatorio');

    if (ultima != hoy) {
      setState(() => mostrarRecordatorio = true);
      prefs.setString('ultimo_recordatorio', hoy);
    }
  }

  // --------------------------------------------------------
  // 🚀 INICIAR SERVICIO BACKGROUND
  // --------------------------------------------------------
  Future<void> _iniciarServicioBackground() async {
    final service = FlutterBackgroundService();

    if (!(await service.isRunning())) {
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'docya_background',
          initialNotificationTitle: 'DocYa Pro activo',
          initialNotificationContent:
              'Enviando ubicación y escuchando consultas...',
          foregroundServiceNotificationId: 88,
        ),
        iosConfiguration: IosConfiguration(),
      );

      await service.startService();
    }

    // Enviar el userId al background
    service.invoke("setUserId", {"userId": widget.userId});
  }


  // --------------------------------------------------------
  // 🛑 DETENER SERVICIO BACKGROUND
  // --------------------------------------------------------
  Future<void> _detenerServicioBackground() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }

  // --------------------------------------------------------
  // 🟢/🔴 TOGGLE DISPONIBLE
  // --------------------------------------------------------
  Future<void> _handleToggleDisponible(bool value) async {
    if (value) {
      // 0) Solicitar permisos ANTES DE TODO
      final permisosOk = await _pedirPermisosUbicacion(context);
      if (!permisosOk) {
        setState(() => disponible = false);
        return;
      }

      // NO marcar disponible todavía
      await _guardarDisponibilidad(true);

      // 1) Iniciar background (abre WS)
      await _iniciarServicioBackground();

      // 2) Reintentar hasta que el WS esté activo
      bool activado = false;

      for (int i = 0; i < 10; i++) {
        try {
          final res = await http.post(
            Uri.parse(
                "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"disponible": true}),
          );

          final data = jsonDecode(res.body);

          if (data["ok"] == true) {
            print("🟢 WS OK → Disponible confirmado");
            activado = true;
            break;
          }
        } catch (_) {}

        print("⏳ Esperando WS… intento ${i + 1}/10");
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!activado) {
        await _guardarDisponibilidad(false);
        setState(() => disponible = false);
        DocYaSnackbar.show(
          context,
          title: "Error",
          message: "No se pudo activar disponible. Revisá los permisos.",
          type: SnackType.error,
        );
        return;
      }

      // 3) Todo OK
      setState(() => disponible = true);
      _pulseController.repeat();

      DocYaSnackbar.show(
        context,
        title: "🟢 Disponible",
        message: "Ahora estás recibiendo consultas.",
        type: SnackType.success,
      );

    } else {
      await _guardarDisponibilidad(false);
      setState(() => disponible = false);

      try {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"disponible": false}),
        );
      } catch (_) {}

      _pulseController.stop();
      await _detenerServicioBackground();

      DocYaSnackbar.show(
        context,
        title: "🔴 No disponible",
        message: "Ya no recibirás consultas.",
        type: SnackType.error,
      );
    }
  }



  // --------------------------------------------------------
  // MAPA
  // --------------------------------------------------------
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle(_mapStyle);
  }

  // --------------------------------------------------------
  // UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !disponible,
      child: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
                target: LatLng(-34.6037, -58.3816), zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Logo
          Positioned(
            top: 45,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset("assets/DOCYAPROBLANCO.png", height: 40)
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: -0.3),
            ),
          ),

          if (disponible)
            Positioned(
              top: 180,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    final scale = 1 + (_pulseController.value * 1.2);
                    final opacity = 1 - _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFF14B8A6).withOpacity(opacity * 0.3),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          if (disponible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  DocYaSnackbar.show(
                    context,
                    title: "⚠ Modo disponible",
                    message: "Ponete en 'NO disponible' para usar la app.",
                    type: SnackType.warning,
                  );
                },
                child: Container(color: Colors.transparent),
              ),
            ),

          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: _buildCardDisponibilidad(),
          ),

          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _buildStatsInferiores(),
          ),

          if (mostrarRecordatorio)
            RecordatorioElementosMedico(
              onClose: () => setState(() => mostrarRecordatorio = false),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // INFO CARDS
  // --------------------------------------------------------
  Widget _buildCardDisponibilidad() {
    return Card(
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  disponible ? Icons.check_circle : Icons.cancel,
                  color: disponible ? const Color(0xFF14B8A6) : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  disponible ? "Disponible" : "No disponible",
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            Switch.adaptive(
              value: disponible,
              activeColor: const Color(0xFF14B8A6),
              onChanged: _handleToggleDisponible,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsInferiores() {
    return Card(
      color: Colors.white.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text("Consultas",
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 5),
                Text(
                  "$totalConsultas",
                  style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ],
            ),
            Container(width: 1, height: 35, color: Colors.grey.shade300),
            Column(
              children: [
                Text("Ganancias",
                    style: GoogleFonts.manrope(
                        fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 5),
                Text(
                  "\$${totalGanancias.toString()}",
                  style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF14B8A6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

