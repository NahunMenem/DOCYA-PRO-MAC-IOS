import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TerminosScreen extends StatelessWidget {
  const TerminosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Términos y Condiciones"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Términos y Condiciones – DocYa Pro",
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                        const SizedBox(height: 16),
                        Text(
                          "Bienvenido a DocYa Pro. Antes de comenzar a utilizar la aplicación, te pedimos que leas atentamente los siguientes términos y condiciones:",
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _section("1. Registro y veracidad de datos",
                            "Al registrarte en DocYa Pro confirmás que los datos brindados son reales, incluyendo matrícula profesional y especialidad."),
                        _section("2. Disponibilidad y penalizaciones",
                            "Debés marcar tu estado como 'Disponible' al menos 2 horas por día. En caso contrario, la plataforma podrá aplicar penalizaciones en tu perfil."),
                        _section("3. Conducta profesional",
                            "Los médicos deben brindar atención respetuosa, ética y ajustada a la normativa vigente. Cualquier conducta inapropiada podrá derivar en la suspensión de la cuenta."),
                        _section("4. Confidencialidad",
                            "La información de los pacientes es confidencial y debe resguardarse en todo momento. El mal uso de la misma será considerado falta grave."),
                        _section("5. Pagos y comisiones",
                            "DocYa Pro retiene una comisión del 20% por cada consulta realizada. Los pagos a médicos se acreditan semanalmente en la cuenta bancaria registrada."),
                        _section("6. Aceptación",
                            "Al registrarte y usar DocYa Pro confirmás que aceptás estos términos y condiciones."),
                        const SizedBox(height: 30),
                        Center(
                          child: Text(
                            "© 2025 DocYa Pro – Salud a tu puerta",
                            style: GoogleFonts.manrope(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
