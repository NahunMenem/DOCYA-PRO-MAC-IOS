// ==================================================
// DOCYA PRO – INICIO SCREEN COMPLETO (VERSIÓN UBER)
// ==================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/websocket_manager.dart';
import '../services/background_location_service.dart';

import '../widgets/consulta_entrante_modal.dart';
import '../widgets/docya_snackbar.dart';
import '../widgets/recordatorio_elementos_medico.dart';

// ==================================================
// 🧭 INICIO SCREEN (DocYa Pro)
// ==================================================

class InicioScreen extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>)? onAceptarConsulta;

  const InicioScreen({
    super.key,
    required this.userId,
    this.onAceptarConsulta,
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

  WebSocketManager? _wsManager;
  BackgroundLocationService? _bgLocation;

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
    _mostrarRecordatorioSiCorresponde();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsManager?.disconnect();
    _bgLocation?.stop();
    super.dispose();
  }

  Future<void> _mostrarRecordatorioSiCorresponde() async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final ultima = prefs.getString('ultimo_recordatorio');

    if (ultima != hoy) {
      setState(() => mostrarRecordatorio = true);
      prefs.setString('ultimo_recordatorio', hoy);
    }
  }

  Future<void> _cargarDisponibilidad() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool("disponible") ?? false;

    setState(() => disponible = saved);

    if (saved) {
      // Si el médico quedó disponible antes → reconectar WS + BG
      _iniciarWebSocket();
      _iniciarBackgroundLocation();
    }

    print("⛔ InicioScreen → Disponibilidad inicial: $saved");
  }

  Future<void> _guardarDisponibilidad(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("disponible", value);
  }

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

  // ==================================================
  // 🔌 NUEVO: WEBSOCKET MANAGER PROFESIONAL
  // ==================================================

  void _iniciarWebSocket() {
    if (_wsManager != null) return;

    _wsManager = WebSocketManager(
      medicoId: widget.userId,
      onMessage: (data) async {
        if (data["tipo"] == "consulta_nueva") {
          await mostrarConsultaEntrante(context, widget.userId);
          _cargarStats();
        }
      },
    );

    _wsManager!.connect();
  }

  // ==================================================
  // 🌎 NUEVO: BACKGROUND LOCATION REAL
  // ==================================================

  Future<void> _iniciarBackgroundLocation() async {
    _bgLocation = BackgroundLocationService(widget.userId);
    await _bgLocation!.start();
  }

  Future<void> _detenerBackgroundLocation() async {
    await _bgLocation?.stop();
  }

  // ==================================================
  // 🌎 MANEJO DE DISPONIBILIDAD (ACTUALIZADO)
  // ==================================================

  Future<void> _handleToggleDisponible(bool value) async {
    if (value) {
      LocationPermission perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }

      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        DocYaSnackbar.show(
          context,
          title: "⚠️ Ubicación requerida",
          message: "Debes permitir ubicación.",
          type: SnackType.error,
        );

        setState(() => disponible = false);
        await _guardarDisponibilidad(false);
        return;
      }

      setState(() => disponible = true);
      await _guardarDisponibilidad(true);

      // Backend → disponible
      await http.post(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"disponible": true}),
      );

      DocYaSnackbar.show(
        context,
        title: "✅ Modo disponible activado",
        message: "Ahora estás recibiendo consultas.",
        type: SnackType.success,
      );

      // Ubicación inicial
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/medico/${widget.userId}/ubicacion"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"lat": pos.latitude, "lng": pos.longitude}),
        );
      } catch (_) {}

      // Iniciar WebSocket + Background
      _iniciarWebSocket();
      _iniciarBackgroundLocation();

      _pulseController.repeat();

    } else {
      setState(() => disponible = false);
      await _guardarDisponibilidad(false);

      await http.post(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"disponible": false}),
      );

      DocYaSnackbar.show(
        context,
        title: "🛑 Modo disponible desactivado",
        message: "Ya no recibirás consultas.",
        type: SnackType.error,
      );

      _wsManager?.disconnect();
      await _detenerBackgroundLocation();

      _pulseController.stop();
    }
  }

  // ==================================================
  // 🗺 MAPA
  // ==================================================

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _mapController.setMapStyle(_mapStyle);
  }

  // ==================================================
  // UI COMPLETA (SIN CAMBIOS)
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (disponible) {
          DocYaSnackbar.show(
            context,
            title: "⚠️ Modo disponible activo",
            message: "Ponete en 'NO disponible' para poder navegar la app.",
            type: SnackType.warning,
          );
          return false;
        }
        return true;
      },
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
                  builder: (context, child) {
                    double scale = 1 + (_pulseController.value * 1.2);
                    double opacity = 1 - _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF14B8A6)
                              .withOpacity(opacity * 0.3),
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
                    title: "⚠️ Modo disponible activo",
                    message: "Ponete en 'NO disponible' para poder usar la app.",
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

  // ==================================================
  // TARJETAS INFERIORES (NO CAMBIADAS)
  // ==================================================

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
                    style: GoogleFonts.manrope(fontSize: 14, color: Colors.black54)),
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
                    style: GoogleFonts.manrope(fontSize: 14, color: Colors.black54)),
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
