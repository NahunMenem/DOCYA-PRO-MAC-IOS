import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/docya_snackbar.dart';
import 'chat_medico_screen.dart';
import 'certificado_screen.dart';
import 'receta_screen.dart';
import 'historia_clinica_screen.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class UbicacionMedicoManager {
  final int medicoId;
  final String baseUrl;
  Timer? _timer;

  UbicacionMedicoManager({
    required this.medicoId,
    required this.baseUrl,
  });

  void start() {
    Geolocator.requestPermission();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition();
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

class MedicoEnCasaScreen extends StatefulWidget {
  final VoidCallback? onFinalizar;
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;
  final String pacienteNombre;
  final String direccion;
  final String motivo;
  final String telefono;
  final double lat;
  final double lng;
  final UbicacionMedicoManager? ubicacionManager;
  final String tipo; // medico / enfermero


  const MedicoEnCasaScreen({
    super.key,
    required this.tipo,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
    required this.pacienteNombre,
    required this.direccion,
    required this.motivo,
    required this.telefono,
    required this.lat,
    required this.lng,
    this.ubicacionManager,
    this.onFinalizar,
  });


  @override
  State<MedicoEnCasaScreen> createState() => _MedicoEnCasaScreenState();
}

class _MedicoEnCasaScreenState extends State<MedicoEnCasaScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _consultaIniciada = false;
  bool _puedeIniciar = false;
  double? _distancia;
  UbicacionMedicoManager? _ubicacionManager;
  bool _pagoConfirmado = false;
  String _metodoPago = "";
  int _mensajesNoLeidos = 0;
  late List<Tab> _tabs;
  late List<Widget> _tabPages;


  @override
  void initState() {
    super.initState();

    debugPrint("👉 MedicoEnCasaScreen iniciado. TIPO = '${widget.tipo}'");

    _tabs = [];
    _tabPages = [];

    if (widget.tipo == "medico") {
      _tabs.add(const Tab(
        icon: Icon(PhosphorIconsRegular.fileText),
        text: "Certificado",
      ));
      _tabPages.add(
        _tabBtn(
          context,
          "Generar Certificado",
          PhosphorIconsRegular.fileText,
          CertificadoScreen(
            consultaId: widget.consultaId,
            medicoId: widget.medicoId,
            pacienteUuid: widget.pacienteUuid,
            pacienteNombre: widget.pacienteNombre,
          ),
        ),
      );

      _tabs.add(const Tab(
        icon: Icon(PhosphorIconsRegular.pill),
        text: "Receta",
      ));
      _tabPages.add(
        _tabBtn(
          context,
          "Generar Receta",
          PhosphorIconsRegular.pill,
          RecetaScreen(
            consultaId: widget.consultaId,
            medicoId: widget.medicoId,
            pacienteUuid: widget.pacienteUuid,
            pacienteNombre: widget.pacienteNombre,
          ),
        ),
      );
    }

    _tabs.add(const Tab(
      icon: Icon(PhosphorIconsRegular.book),
      text: "Historia",
    ));
    _tabPages.add(
      _tabBtn(
        context,
        "Historia Clínica",
        PhosphorIconsRegular.book,
        HistoriaClinicaScreen(
          consultaId: widget.consultaId,
          medicoId: widget.medicoId,
          pacienteUuid: widget.pacienteUuid,
        ),
      ),
    );

    _tabController = TabController(length: _tabs.length, vsync: this);

    // 🔥 Calcular distancia inicial
    _chequearUbicacion();

    // 🔥 ACTUALIZAR distancia en tiempo real
    Timer.periodic(const Duration(seconds: 5), (_) {
      _chequearUbicacion();
    });

    _ubicacionManager = widget.ubicacionManager;
    _verificarPago();
    _verificarMensajes();
  }



  Future<void> _verificarPago() async {
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/estado_pago");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _pagoConfirmado = data["pagado"] ?? false;
          _metodoPago = data["metodo"] ?? "";
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error al verificar pago: $e");
    }
  }

  Future<void> _verificarMensajes() async {
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/chat/${widget.consultaId}/mensajes_no_leidos?medico_id=${widget.medicoId}");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _mensajesNoLeidos = data["no_leidos"] ?? 0);
      }
    } catch (e) {
      debugPrint("⚠️ Error mensajes no leídos: $e");
    }
  }

  Future<void> _chequearUbicacion() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      double distancia = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.lat,
        widget.lng,
      );
      setState(() {
        _distancia = distancia;
        _puedeIniciar = distancia <= 200;
      });
    } catch (e) {
      debugPrint("⚠️ Error ubicacion: $e");
    }
  }

  Future<void> iniciarConsulta() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/iniciar");
    final resp = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"medico_id": widget.medicoId}));
    if (resp.statusCode == 200 && mounted) {
      setState(() => _consultaIniciada = true);
      DocYaSnackbar.show(
        context,
        title: "✅ Consulta iniciada",
        message: "Podés comenzar con la atención",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "No se pudo iniciar: ${resp.body}",
        type: SnackType.error,
      );
    }
  }

  Future<void> marcarEnCamino() async {
    await http.post(
      Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/encamino"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"medico_id": widget.medicoId}),
    );
  }

  Future<void> finalizarConsulta() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/finalizar");
    final resp = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"medico_id": widget.medicoId}));
    if (resp.statusCode == 200 && mounted) {
      _ubicacionManager?.stop();
      Navigator.pop(context);
      DocYaSnackbar.show(
        context,
        title: "✅ Consulta finalizada",
        message: "Se registró correctamente la finalización",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "No se pudo finalizar: ${resp.body}",
        type: SnackType.error,
      );
    }
  }

  Future<void> _abrirEnGoogleMaps(String direccion) async {
    final query = Uri.encodeComponent(direccion);
    final url = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  // ===================================================
  // 🎨 INTERFAZ
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        DocYaSnackbar.show(
          context,
          title: "⛔ Acción no permitida",
          message: "No podés salir hasta finalizar la consulta.",
          type: SnackType.warning,
        );
        return false; // ❌ BLOQUEA ATRÁS
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false, // ❌ Ocultamos botón atrás
          title: Image.asset("assets/DOCYAPROBLANCO.png", height: 38),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    PhosphorIconsRegular.chatCircleText,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatMedicoScreen(
                          consultaId: widget.consultaId,
                          medicoId: widget.medicoId,
                          nombreMedico: "Dr. ${widget.medicoId}",
                        ),
                      ),
                    );
                    _verificarMensajes();
                  },
                ),
                if (_mensajesNoLeidos > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.user,
                              color: Color(0xFF14B8A6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.pacienteNombre,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _infoTile(PhosphorIconsRegular.phone, widget.telefono),
                        _infoTile(PhosphorIconsRegular.mapPin, widget.direccion),
                        _infoTile(PhosphorIconsRegular.heart, widget.motivo),
                        const SizedBox(height: 12),
                        // === BADGE AUTOMÁTICO DE ESTADO DE PAGO ===
                        _pagarBadgeInteligente(),   

                        const SizedBox(height: 14),
                        _gradientButton(
                          text: "Abrir en Google Maps",
                          icon: PhosphorIconsRegular.navigationArrow,
                          onTap: () async {
                            await marcarEnCamino();
                            _abrirEnGoogleMaps(widget.direccion);
                            _chequearUbicacion();
                          },
                          colors: [Colors.tealAccent, Colors.cyanAccent],
                        ),
                        const SizedBox(height: 10),
                        _gradientButton(
                          text: _puedeIniciar
                              ? "Iniciar Consulta"
                              : "Acérquese al domicilio",
                          icon: PhosphorIconsRegular.playCircle,
                          onTap: _puedeIniciar ? iniciarConsulta : null,
                          colors: const [Color(0xFF14B8A6), Color(0xFF0F2027)],
                        ),
                        if (_distancia != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "Distancia actual: ${_distancia!.toStringAsFixed(0)} m",
                              style: GoogleFonts.manrope(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
                  const SizedBox(height: 25),

                  // === Tabs ===
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.tealAccent,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.tealAccent,
                    tabs: _tabs,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: !_consultaIniciada
                        ? Center(
                            child: Text(
                              "⚠️ Debe iniciar la consulta al llegar al domicilio",
                              style: GoogleFonts.manrope(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: _tabPages,
                          ),
                  ),


                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _consultaIniciada ? finalizarConsulta : null,
              icon: const Icon(
                PhosphorIconsRegular.checkCircle,
                color: Colors.white,
              ),
              label: Text(
                "Finalizar Consulta",
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                disabledBackgroundColor: Colors.grey,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms),
          ),
        ),
      ),
    );
  }


  Widget _pagoBadge({required String text, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
    // ===================================================
  // 🧠 BADGE INTELIGENTE PARA MOSTRAR ESTADO DE PAGO
  // ===================================================
  Widget _pagarBadgeInteligente() {
    // Caso 1 → Pagado por Mercado Pago
    if (_pagoConfirmado && _metodoPago == "tarjeta") {
      return _pagoBadge(
        text: "💳 Pagado por la app",
        color: Colors.greenAccent,
      );
    }

    // Caso 2 → Seleccionó efectivo
    if (_metodoPago == "efectivo") {
      return _pagoBadge(
        text: "💵 Cobro pendiente (efectivo)",
        color: Colors.orangeAccent,
      );
    }

    // Caso 3 → Todavía no llega webhook (raro pero posible)
    return _pagoBadge(
      text: "⏳ Procesando pago...",
      color: Colors.yellowAccent,
    );
  }


  Widget _infoTile(IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.manrope(color: Colors.white70)),
            ),
          ],
        ),
      );

  Widget _tabBtn(
      BuildContext context, String text, IconData icon, Widget page) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(text,
            style: GoogleFonts.manrope(
                color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          minimumSize: const Size(230, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _gradientButton({
    required String text,
    required IconData icon,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  } // ← cierre del método correctamente

  // ← AQUÍ VA dispose(), al mismo nivel que build() y initState()
  @override
  void dispose() {
    _ubicacionManager?.stop();
    _tabController.dispose();
    super.dispose();
  }

  // ← ESTE ES EL ÚNICO cierre de la clase


}