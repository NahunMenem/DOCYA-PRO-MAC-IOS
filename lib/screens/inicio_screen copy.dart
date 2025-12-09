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
import '../widgets/consulta_entrante_modal.dart';

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
  late GoogleMapController _mapController;
  int totalConsultas = 0;
  int totalGanancias = 0;
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;

  late AnimationController _pulseController;

  final String _mapStyle = '''
  [
    {"elementType": "geometry","stylers":[{"color":"#212121"}]},
    {"elementType": "labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType": "labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType": "labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
    _cargarDisponibilidad();
    _cargarStats();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _desconectarWS();
    super.dispose();
  }

  // ==================================================
  // 🔌 Backend y WebSocket
  // ==================================================
  Future<void> _cargarDisponibilidad() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => disponible = prefs.getBool("disponible") ?? false);
    if (disponible) _conectarWS();
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
          totalGanancias = data["ganancias"] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error cargando stats: $e");
    }
  }

  void _conectarWS() {
    final url =
        "wss://docya-railway-production.up.railway.app/ws/medico/${widget.userId}";
    _channel = IOWebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen((event) async {
      final data = jsonDecode(event);
      if (data["tipo"] == "consulta_nueva") {
        final aceptada = await mostrarConsultaEntrante(context, widget.userId);
        if (aceptada == true) {
          widget.onAceptarConsulta?.call({
            "id": data["consulta_id"],
            "paciente_uuid": data["paciente_uuid"],
            "paciente_nombre": data["paciente_nombre"],
            "direccion": data["direccion"],
            "motivo": data["motivo"],
            "lat": data["lat"],
            "lng": data["lng"],
            "medico_id": int.parse(widget.userId),
          });
        }
        _cargarStats();
      }
    });

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _channel?.sink.add(jsonEncode({"tipo": "ping"}));
    });
  }

  void _desconectarWS() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _actualizarDisponibilidadBackend(bool value) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/medico/${widget.userId}/ubicacion");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "disponible": value,
        }),
      );
    } catch (e) {
      debugPrint("⚠️ Error actualizando backend: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle(_mapStyle);
  }

  // ==================================================
  // 🎨 UI moderna con pulso
  // ==================================================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🌍 Mapa (igual que el original)
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition:
              const CameraPosition(target: LatLng(-34.6037, -58.3816), zoom: 12),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),

        // 📌 Logo superior
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

        // 💚 Pulso animado (solo si disponible)
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

        // 🔘 Tarjeta disponibilidad
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: Card(
            color: Colors.white.withOpacity(0.95),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    onChanged: (value) async {
                      setState(() => disponible = value);
                      await _guardarDisponibilidad(value);
                      await _actualizarDisponibilidadBackend(value);
                      if (value) {
                        _conectarWS();
                        _pulseController.repeat();
                      } else {
                        _desconectarWS();
                        _pulseController.stop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
        ),

        // 📊 Métricas inferiores (igual, pero más limpio)
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Card(
            color: Colors.white.withOpacity(0.95),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 5,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
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
                  Container(
                    width: 1,
                    height: 35,
                    color: Colors.grey.shade300,
                  ),
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
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3),
        ),
      ],
    );
  }
}
