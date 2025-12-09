import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

/// 🌿 Pantalla principal del dashboard DocYa Pro
class DashboardScreen extends StatefulWidget {
  final String medicoId;
  const DashboardScreen({super.key, required this.medicoId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 📊 Variables principales
  int consultas = 0;
  int ganancias = 0;
  int consultasDiurnas = 0;
  int consultasNocturnas = 0;
  int gananciasDiurnas = 0;
  int gananciasNocturnas = 0;
  int consultasDiurnasTarjeta = 0;
  int consultasNocturnasTarjeta = 0;
  int consultasDiurnasEfectivo = 0;
  int consultasNocturnasEfectivo = 0;

  String metodoFrecuente = "-";

  String tipo = "medico"; // default
  String periodo = "";
  double saldoPendiente = 0;
  Map<String, dynamic> detallePagos = {};
  bool cargando = true;

  // ========================================================
  // 🔄 Obtener datos del backend
  // ========================================================
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final urlStats = Uri.parse(
          "https://docya-railway-production.up.railway.app/auth/medico/${widget.medicoId}/stats");

      final urlSaldo = Uri.parse(
          "https://docya-railway-production.up.railway.app/medicos/${widget.medicoId}/saldo");

      final resStats = await http.get(urlStats);
      final resSaldo = await http.get(urlSaldo);

      if (resStats.statusCode == 200) {
        final data = jsonDecode(resStats.body);

        // Sanitizar tipo
        String tipoApi = (data["tipo"] ?? "").toString().toLowerCase().trim();
        if (tipoApi != "medico" && tipoApi != "enfermero") tipoApi = "medico";

        setState(() {
          tipo = tipoApi;
          periodo = data["periodo"] ?? "";

          // Totales
          consultas = data["consultas"] ?? 0;

          // 🔥 Aplicar 80% (descuento del 20%)
          final bruto = (data["ganancias"] ?? 0).toDouble();
          ganancias = (bruto * 0.8).round();

          gananciasDiurnas = ((data["ganancias_diurnas"] ?? 0) * 0.8).round();
          gananciasNocturnas = ((data["ganancias_nocturnas"] ?? 0) * 0.8).round();

          // Diurnas / Nocturnas
          consultasDiurnas = data["consultas_diurnas"] ?? 0;
          consultasNocturnas = data["consultas_nocturnas"] ?? 0;

          // 🚀 NUEVOS CAMPOS PARA TARJETA / EFECTIVO (DIURNA + NOCTURNA)
          consultasDiurnasTarjeta = data["consultas_diurnas_tarjeta"] ?? 0;
          consultasNocturnasTarjeta = data["consultas_nocturnas_tarjeta"] ?? 0;
          consultasDiurnasEfectivo = data["consultas_diurnas_efectivo"] ?? 0;
          consultasNocturnasEfectivo = data["consultas_nocturnas_efectivo"] ?? 0;

          // Método frecuente
          metodoFrecuente = data["metodo_frecuente"] ?? "-";

          // Pie chart
          detallePagos = data["detalle_pagos"] ?? {};
        });
      }

      if (resSaldo.statusCode == 200) {
        final saldoData = jsonDecode(resSaldo.body);
        saldoPendiente = double.tryParse("${saldoData["saldo"]}") ?? 0.0;
      }
    } catch (e) {
      debugPrint("⚠️ Error cargando dashboard: $e");
    }

    setState(() => cargando = false);
  }


  // ========================================================
  // 🎨 Estilo DocYa
  // ========================================================
  static const kTeal = Color(0xFF14B8A6);
  static const kGradient = [
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364)
  ];

  // ========================================================
  // 🏗 UI GENERAL
  // ========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGradient.first,
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: kGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter),
              ),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 25),
                    _buildResumenRapido(),

                    const SizedBox(height: 25),
                    _buildTarifasCard(),

                    const SizedBox(height: 30),
                    _buildMainStats(),

                    const SizedBox(height: 30),
                    _buildLiquidacionCard(),

                    if (saldoPendiente < 0) ...[
                      const SizedBox(height: 22),
                      _buildComisionPendienteCard(),
                    ],

                    const SizedBox(height: 30),
                    _buildPieSection(),

                    const SizedBox(height: 40),
                    _buildRefreshButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // ========================================================
  // 🧠 HEADER
  // ========================================================
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hola, ${tipo == "enfermero" ? "enfermero/a" : "médico/a"} 👋",
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Tu resumen semanal",
          style: GoogleFonts.manrope(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          periodo,
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  // ========================================================
  // ⭐ RESUMEN RÁPIDO (Tarjeta / Efectivo)
  // ========================================================
  Widget _buildResumenRapido() {
    return Column(
      children: [

        // 🟦 TARJETA
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pagos por la App",
                style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickItem(
                    "Diurnas",
                    "$consultasDiurnasTarjeta",
                    PhosphorIconsBold.sun,
                  ),
                  _quickItem(
                    "Nocturnas",
                    "$consultasNocturnasTarjeta",
                    PhosphorIconsBold.moon,
                  ),
                  _quickItem(
                    "Método",
                    "Pago digital",
                    PhosphorIconsBold.creditCard,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 🟩 EFECTIVO
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pagos en efectivo",
                style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickItem(
                    "Diurnas",
                    "$consultasDiurnasEfectivo",
                    PhosphorIconsBold.sun,
                  ),
                  _quickItem(
                    "Nocturnas",
                    "$consultasNocturnasEfectivo",
                    PhosphorIconsBold.moon,
                  ),
                  _quickItem(
                    "Método",
                    "Efectivo",
                    PhosphorIconsBold.wallet,
                  ),
                ],
              ),
            ],
          ),
        ),

      ],
    );
  }


  Widget _quickItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kTeal, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  // ========================================================
  // ⭐ TARIFAS OFICIALES (según rol)
  // ========================================================
  Widget _buildTarifasCard() {
    final esMedico = tipo == "medico";

    final tarifaDiurna = esMedico ? 30000 : 20000;
    final tarifaNocturna = esMedico ? 40000 : 30000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Tus tarifas oficiales"),
        const SizedBox(height: 16),
        _glassCard(
          child: Row(
            children: [
              Icon(PhosphorIconsBold.receipt, color: kTeal, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esMedico ? "Tarifas de médico" : "Tarifas de enfermero",
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text("🟢 Diurna: \$${tarifaDiurna}",
                        style: GoogleFonts.manrope(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text("🌙 Nocturna: \$${tarifaNocturna}",
                        style: GoogleFonts.manrope(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      "Se aplican automáticamente según el horario de la consulta.",
                      style: GoogleFonts.manrope(
                          color: Colors.white38, fontSize: 11, height: 1.4),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================
  // ⭐ ESTADÍSTICAS PRINCIPALES
  // ========================================================
  Widget _buildMainStats() {
    return _glassCard(
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 16,
        spacing: 20,
        children: [
          _statItem(
            icon: PhosphorIconsRegular.calendarCheck,
            label: "Consultas",
            value: "$consultas",
          ),
          _statItem(
            icon: PhosphorIconsRegular.wallet,
            label: "Ganancias",
            value: "\$$ganancias",
          ),
          _statItem(
            icon: PhosphorIconsRegular.stethoscope,
            label: "Rol",
            value: tipo.toUpperCase(),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.15);
  }

  // ========================================================
  // 💸 LIQUIDACIÓN SEMANAL
  // ========================================================
  Widget _buildLiquidacionCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Liquidación semanal"),
        const SizedBox(height: 16),
        _glassCard(
          color: kTeal.withOpacity(0.12),
          child: Row(
            children: [
              const Icon(PhosphorIconsBold.coins, color: kTeal, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("A transferir el lunes",
                        style: GoogleFonts.manrope(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(
                      "\$${saldoPendiente.toStringAsFixed(0)}",
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Monto preliminar sujeto a ajustes por comisiones de pago digital.",
                      style: GoogleFonts.manrope(
                          color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("Semana actual",
                    style: GoogleFonts.manrope(
                        color: kTeal, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================
  // ❗ COMISIÓN PENDIENTE
  // ========================================================
  Widget _buildComisionPendienteCard() {
    return _glassCard(
      color: Colors.red.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsBold.warningCircle,
                  color: Colors.redAccent, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text("Comisión pendiente con DocYa",
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "\$${saldoPendiente.abs().toStringAsFixed(0)}",
            style: GoogleFonts.manrope(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            "Corresponde a consultas en efectivo. Se descontará automáticamente.",
            style: GoogleFonts.manrope(
                color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  // ========================================================
  // 🥧 GRÁFICO MÉTODOS DE PAGO
  // ========================================================
  Widget _buildPieSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Distribución por método de pago"),
        const SizedBox(height: 16),
        _glassCard(
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 45,
                sectionsSpace: 4,
                sections: _buildPieSections(),
              ),
            ),
          ).animate().fadeIn().scaleXY(begin: 0.85),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    if (detallePagos.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade600,
          title: "Sin datos",
          value: 100,
          titleStyle: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
        ),
      ];
    }

    // Total para calcular porcentajes
    double total = detallePagos.values
        .fold(0, (sum, e) => sum + (e["monto"] ?? 0).toDouble());

    return detallePagos.entries.map((e) {
      final rawMetodo = e.key.toLowerCase().trim();

      // 🔥 Unificación de métodos
      final metodo =
          (rawMetodo == "efectivo") ? "efectivo" : "digital";

      final monto = (e.value["monto"] ?? 0).toDouble();
      final porcentaje = total == 0 ? 0 : (monto / total) * 100;

      // 🎨 Colores
      final color = metodo == "efectivo"
          ? const Color(0xFFEE6352)  // rojo suave
          : kTeal;                   // digital → teal

      return PieChartSectionData(
        color: color,
        value: porcentaje,
        radius: 65,
        title: "$metodo\n${porcentaje.toStringAsFixed(1)}%",
        titleStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );
    }).toList();
  }


  // ========================================================
  // 🔁 BOTÓN ACTUALIZAR
  // ========================================================
  Widget _buildRefreshButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _cargarDatos,
        style: ElevatedButton.styleFrom(
          backgroundColor: kTeal,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(PhosphorIconsRegular.arrowClockwise,
            color: Colors.white),
        label: Text("Actualizar datos",
            style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ),
    );
  }

  // ========================================================
  // 🌟 GLASS CARD
  // ========================================================
  Widget _glassCard({required Widget child, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }

  // ========================================================
  // 🔤 TÍTULO
  // ========================================================
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  // ========================================================
  // 📊 ÍTEM
  // ========================================================
  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: kTeal, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
        ),
        if (label == "Ganancias") ...[
          const SizedBox(height: 4),
          Text(
            "Sujeto a comisiones por pago digital.",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
                color: Colors.white54, fontSize: 11, height: 1.3),
          ),
        ]
      ],
    );
  }
}