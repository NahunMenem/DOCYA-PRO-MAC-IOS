import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'editar_alias_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen_pro.dart' hide DocYaSnackbar, SnackType; 
import '../widgets/docya_snackbar.dart';

class PerfilScreen extends StatefulWidget {
  final String nombreUsuario;
  final String medicoId;

  const PerfilScreen({
    super.key,
    required this.nombreUsuario,
    required this.medicoId,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String? alias;
  String? fotoUrl;
  String? nombreCompleto;
  String? matricula;
  String? email;
  String? telefono;
  String? especialidad;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final res = await http.get(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/medicos/${widget.medicoId}"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          alias = data["alias_cbu"];
          fotoUrl = data["foto_perfil"];
          nombreCompleto = data["full_name"];
          matricula = data["matricula"];
          email = data["email"];
          telefono = data["telefono"];
          especialidad = data["especialidad"];
          _loading = false;
        });
      } else {
        debugPrint("❌ Error backend al cargar perfil: ${res.body}");
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("❌ Error cargando perfil: $e");
      setState(() => _loading = false);
    }
  }

  // 🔥 CAMBIAR FOTO
  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    var request = http.MultipartRequest(
      "POST",
      Uri.parse(
          "https://docya-railway-production.up.railway.app/medicos/${widget.medicoId}/foto"),
    );
    request.files.add(await http.MultipartFile.fromPath("file", file.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        setState(() => fotoUrl = data["foto_url"]);
        if (mounted) {
          DocYaSnackbar.show(
            context,
            title: "📸 Foto actualizada",
            message: "Tu foto de perfil se actualizó correctamente.",
            type: SnackType.success,
          );
        }
      } else {
        debugPrint("❌ Error subiendo foto: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error en la subida de foto: $e");
    }
  }

  // 🔥 ELIMINAR CUENTA DEL MÉDICO (POP-UP CONFIRMACIÓN)
  void _confirmarEliminacionMedico(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white24),
          ),
          title: const Text(
            "Eliminar cuenta",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Esta acción eliminará tu cuenta de médico de forma permanente. "
            "Tus consultas históricas se conservarán para proteger la historia clínica.",
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actions: [
            TextButton(
              child: const Text("Cancelar",
                  style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text(
                "Eliminar",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(context);
                _eliminarCuentaMedico();
              },
            ),
          ],
        );
      },
    );
  }

  // 🔥 LLAMADA AL BACKEND PARA ELIMINACIÓN DEFINITIVA
  Future<void> _eliminarCuentaMedico() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/medicos/${widget.medicoId}/delete",
      );

      final res = await http.delete(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        await prefs.clear();

        if (!mounted) return;

        DocYaSnackbar.show(
          context,
          title: "Cuenta eliminada",
          message: "Tu cuenta ha sido eliminada correctamente.",
          type: SnackType.success,
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreenPro()),
          (_) => false,
        );
      } else {
        DocYaSnackbar.show(
          context,
          title: "Error",
          message: "No se pudo eliminar la cuenta: ${res.body}",
          type: SnackType.error,
        );
      }
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "Error inesperado",
        message: e.toString(),
        type: SnackType.error,
      );
    }
  }

  // 🔥 CERRAR SESIÓN
  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Cerrar sesión",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("¿Seguro que quieres cerrar sesión?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    DocYaSnackbar.show(
      context,
      title: "👋 Sesión finalizada",
      message: "Cerraste sesión correctamente.",
      type: SnackType.info,
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreenPro()),
      (route) => false,
    );
  }

  // 🔥 TARJETA VISUAL
  Widget _infoTile(IconData icon, String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ListTile(
              leading: Icon(icon, color: const Color(0xFF14B8A6)),
              title: Text(title,
                  style: GoogleFonts.manrope(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle ?? "No configurado",
                  style: GoogleFonts.manrope(color: Colors.white70)),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Mi Perfil",
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _cambiarFoto,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundImage:
                            (fotoUrl != null && fotoUrl!.isNotEmpty)
                                ? NetworkImage(fotoUrl!)
                                : null,
                        backgroundColor: const Color(0xFF14B8A6),
                        child: (fotoUrl == null || fotoUrl!.isEmpty)
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 50)
                            : null,
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.8),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      nombreCompleto ?? widget.nombreUsuario,
                      style: GoogleFonts.manrope(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      especialidad ?? "Especialidad no configurada",
                      style: GoogleFonts.manrope(
                          color: Colors.white70, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 30),

                  _infoTile(Icons.badge, "Matrícula", matricula),
                  _infoTile(Icons.email, "Email", email),
                  _infoTile(Icons.phone, "Teléfono", telefono),
                  _infoTile(Icons.account_balance_wallet, "Alias / CBU", alias),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DashboardScreen(medicoId: widget.medicoId),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.bar_chart_rounded,
                                  color: Color(0xFF14B8A6), size: 28),
                              title: Text("Mis Ganancias",
                                  style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "Ver tus ingresos semanales y saldo pendiente",
                                  style: GoogleFonts.manrope(
                                      color: Colors.white70, fontSize: 13)),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 👉 BOTÓN ELIMINAR CUENTA
                  Center(
                    child: OutlinedButton.icon(
                      icon:
                          const Icon(Icons.delete_forever, color: Colors.redAccent),
                      label: Text(
                        "Eliminar cuenta",
                        style: GoogleFonts.manrope(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _confirmarEliminacionMedico(context),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: Text("Cerrar sesión",
                          style: GoogleFonts.manrope(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _cerrarSesion,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

