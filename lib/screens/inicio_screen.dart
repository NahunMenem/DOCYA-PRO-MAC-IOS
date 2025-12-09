// ==================================================
// TU CÓDIGO COMPLETO TAL CUAL, CON AÑADIDOS DEL BLOQUEO  
// API IOS PRO AIzaSyBgfqDTSxmIinKcUcDW-KOg9VzGZpNUwBg
// ==================================================
// ==================================================
// TU CÓDIGO COMPLETO TAL CUAL, CON AÑADIDOS DEL BLOQUEO
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
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/consulta_entrante_modal.dart';
import '../widgets/docya_snackbar.dart';
import '../widgets/recordatorio_elementos_medico.dart';

// ==================================================
// 🧠 FUNCIÓN DE BACKGROUND
// ==================================================
// ==================================================
// 🧠 FUNCIÓN DE BACKGROUND (CORREGIDA)
// ==================================================
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  String? medicoId;

  service.on("setUserId").listen((event) {
    medicoId = event?["userId"];
  });

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "DocYa Pro activo",
      content: "Compartiendo tu ubicación para recibir pacientes cercanos.",
    );
  }

  Timer.periodic(const Duration(seconds: 20), (timer) async {
    // ================================
    // 🔥 CARGAR DISPONIBILIDAD REAL
    // ================================
    final prefs = await SharedPreferences.getInstance();
    final disponible = prefs.getBool("disponible") ?? false;

    // 🛑 SI NO ESTÁ DISPONIBLE → NO ENVIAR
    if (!disponible) {
      print("🛑 [BG] Médico NO disponible → no envío ubicación");
      return;
    }

    // ================================
    // 🌎 SI ESTÁ DISPONIBLE → ENVIAR
    // ================================
    if (!(await Geolocator.isLocationServiceEnabled())) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (medicoId != null) {
      try {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/medico/$medicoId/ubicacion"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "lat": pos.latitude,
            "lng": pos.longitude,
          }),
        );
        print("📡 [BG] Ubicación enviada (modo DISPONIBLE)");
      } catch (e) {
        print("⚠️ [BG] Error enviando ubicación: $e");
      }
    }
  });

  service.on("stopService").listen((event) async {
    print("🛑 BG service detenido");
    service.stopSelf();
  });
}


// ==================================================
// 🧭 INICIOSCREEN (DocYa Pro)
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
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
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
    setState(() => mostrarRecordatorio = true);
    _mostrarRecordatorioSiCorresponde();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _detenerServicioBackground();
    _desconectarWS();
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

  Future<void> _iniciarServicioBackground() async {
    final status = await Permission.locationAlways.request();
    if (!status.isGranted) return;

    final service = FlutterBackgroundService();

    if (await service.isRunning()) return;

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'docya_background',
        initialNotificationTitle: 'DocYa Pro activo',
        initialNotificationContent: 'Enviando tu ubicación en tiempo real...',
        foregroundServiceNotificationId: 88,
      ),
      iosConfiguration: IosConfiguration(),
    );

    await service.startService();
    service.invoke("setUserId", {"userId": widget.userId});
  }

  Future<void> _detenerServicioBackground() async {
    final service = FlutterBackgroundService();

    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }

  Future<void> _cargarDisponibilidad() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("disponible", false);
    setState(() => disponible = false);
    print("⛔ InicioScreen → Médico NO disponible por defecto");
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

  void _conectarWS() {
    if (_channel != null) return;

    final url =
        "wss://docya-railway-production.up.railway.app/ws/medico/${widget.userId}";
    print("🔌 Conectando WebSocket médico ${widget.userId}");

    _channel = IOWebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen((event) async {
      if (event == "pong") return;

      Map<String, dynamic> data;
      try {
        data = jsonDecode(event);
      } catch (_) {
        return;
      }

      if (data["tipo"] == "consulta_nueva") {
        await mostrarConsultaEntrante(context, widget.userId);
        _cargarStats();
      }
    }, onError: (_) {
      _reintentarWS();
    }, onDone: () {
      _reintentarWS();
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _channel?.sink.add(jsonEncode({"tipo": "ping"}));
    });
  }

  void _reintentarWS() {
    _channel = null;
    Future.delayed(const Duration(seconds: 2), () {
      if (disponible) _conectarWS();
    });
  }

  void _desconectarWS() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle(_mapStyle);
  }

  // ==================================================
  // 🛑 **AQUÍ VIENE EL BLOQUEO DE NAVEGACIÓN**
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (disponible) {
          DocYaSnackbar.show(
            context,
            title: "⚠️ Modo disponible activo",
            message:
                "Ponete en 'NO disponible' para poder navegar la app.",
            type: SnackType.warning,
          );
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          // ==================================================
          // MAPA (TAL CUAL LO TENÍAS)
          // ==================================================
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
                target: LatLng(-34.6037, -58.3816), zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ==================================================
          // TODO TU UI (SIN CAMBIAR NADA)
          // ==================================================

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
                          color:
                              const Color(0xFF14B8A6).withOpacity(opacity * 0.3),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ===============================================================
          // 💥 ACÁ ESTÁ TU MODAL DE BLOQUEO (SUPER IMPORTANTE)
          // ===============================================================
          if (disponible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  DocYaSnackbar.show(
                    context,
                    title: "⚠️ Modo disponible activo",
                    message:
                        "Ponete en 'NO disponible' para poder usar la app.",
                    type: SnackType.warning,
                  );
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

          // ==================================================
          // ⚠ NO MODIFIQUÉ NADA DEL RESTO
          // ==================================================

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
  // 🔷 SECCIÓNES ORIGINALES (NO TOCADA)
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

      try {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"disponible": true}),
        );
      } catch (_) {}

      DocYaSnackbar.show(
        context,
        title: "✅ Modo disponible activado",
        message: "Ahora estás recibiendo solicitudes.",
        type: SnackType.success,
      );

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

      _conectarWS();
      await _iniciarServicioBackground();
      _pulseController.repeat();
    } else {
      setState(() => disponible = false);
      await _guardarDisponibilidad(false);

      try {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/medico/${widget.userId}/status"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"disponible": false}),
        );
      } catch (_) {}

      DocYaSnackbar.show(
        context,
        title: "🛑 Modo disponible desactivado",
        message: "Ya no recibirás pacientes.",
        type: SnackType.error,
      );

      _desconectarWS();
      _pulseController.stop();
      await _detenerServicioBackground();
    }
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