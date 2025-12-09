import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/docya_snackbar.dart';
import '../services/auth_service.dart';
import 'register_screen_pro.dart';
import 'home_menu.dart';
import 'firma_digital_screen.dart'; // 👈 importá tu pantalla de firma


// (Dejamos tu clase DocYaSnackbar igual)

class LoginScreenPro extends StatefulWidget {
  const LoginScreenPro({super.key});

  @override
  State<LoginScreenPro> createState() => _LoginScreenProState();
}

class _LoginScreenProState extends State<LoginScreenPro>
    with SingleTickerProviderStateMixin {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  final _auth = AuthService();

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token_medico", token);
  }

  Future<void> _enviarFcmTokenAlBackend(String medicoId) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final url = Uri.parse(
            "https://docya-railway-production.up.railway.app/medicos/$medicoId/fcm_token");
        await http.post(url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"fcm_token": fcmToken}));
      }
    } catch (e) {
      debugPrint("⚠️ Error FCM: $e");
    }
  }

  // 🔥 Modificamos esta parte
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final loginData =
        await _auth.loginMedico(_usuario.text.trim(), _password.text.trim());

    setState(() => _loading = false);

    if (loginData != null) {
      await _saveToken(loginData["access_token"]);
      await _enviarFcmTokenAlBackend(loginData["medico_id"].toString());

      final medicoId = int.tryParse(loginData["medico_id"].toString()) ?? 0;
      final nombre = loginData["full_name"];
      final tipo = loginData["tipo"]?.toString() ?? "medico"; // 👈 importante

      DocYaSnackbar.show(context,
          title: "✅ Bienvenido",
          message: "Hola $nombre, inicio de sesión exitoso.");

      // ⚡ Solo si es médico verificamos la firma digital
      if (tipo == "medico") {
        try {
          final prefs = await SharedPreferences.getInstance();
          final tieneFirma = prefs.getBool("tiene_firma_$medicoId") ?? false;

          if (!tieneFirma) {
            final res = await http.get(Uri.parse(
                "https://docya-railway-production.up.railway.app/medicos/$medicoId"));

            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              final firmaUrl = data["firma_url"]?.toString() ?? "";

              if (firmaUrl.isEmpty) {
                // 🔹 Redirigir al setup de firma
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FirmaDigitalScreen(medicoId: medicoId),
                    ),
                  );
                });
                return;
              } else {
                await prefs.setBool("tiene_firma_$medicoId", true);
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error al verificar firma: $e");
        }
      }

      // 🏠 Si ya tiene firma (o no es médico), entrar directo al home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeMenu(
              userId: medicoId.toString(),
              nombreUsuario: nombre,
            ),
          ),
        );
      });
    } else {
      DocYaSnackbar.show(context,
          title: "⚠️ Error",
          message: "Credenciales inválidas.",
          type: SnackType.error);
    }
  }


  void _recuperarContrasena() async {
    final identificadorController = TextEditingController();
    bool cargando = false;

    await showDialog(
      context: context,
      barrierDismissible: !cargando,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("🔑 Recuperar contraseña",
                style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: identificadorController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ingresá tu email o DNI / Pasaporte",
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF14B8A6))),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: cargando ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6)),
                onPressed: cargando
                    ? null
                    : () async {
                        setStateDialog(() => cargando = true);
                        try {
                          final res = await http.post(
                            Uri.parse(
                                "https://docya-railway-production.up.railway.app/auth/forgot_password"),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "identificador":
                                  identificadorController.text.trim()
                            }),
                          );

                          Navigator.pop(ctx);

                          if (res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "📩 Email enviado",
                              message: data["message"] ??
                                  "Enviamos un correo con las instrucciones.",
                              type: SnackType.success,
                            );
                          } else {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "⚠️ Error",
                              message: data["detail"] ??
                                  "No se encontró ningún usuario con esos datos.",
                              type: SnackType.error,
                            );
                          }
                        } catch (e) {
                          Navigator.pop(ctx);
                          DocYaSnackbar.show(
                            context,
                            title: "⚠️ Error",
                            message:
                                "Hubo un problema al conectar con el servidor.",
                            type: SnackType.error,
                          );
                        }
                      },
                child: cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Enviar",
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF14B8A6);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
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
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Image.asset("assets/DOCYAPROBLANCO.png",
                          height: 120),
                    ),
                  ),
                  const SizedBox(height: 50),
                  _glassContainer(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usuario,
                            style: GoogleFonts.manrope(color: Colors.white),
                            decoration: _inputDecoration(
                              "Email o DNI / Pasaporte",
                              PhosphorIconsRegular.identificationCard,
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Ingresá tu email o documento'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            style: GoogleFonts.manrope(color: Colors.white),
                            decoration: _inputDecoration(
                              "Contraseña",
                              PhosphorIconsRegular.lock,
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _recuperarContrasena,
                              child: const Text("¿Olvidaste tu contraseña?",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      decoration: TextDecoration.underline)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildLoginButton(kPrimary),
                          const SizedBox(height: 18),
                          _registerLink(context),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
                  const SizedBox(height: 40),
                  Text("DocYa Pro © 2025 – Profesionales a domicilio",
                      style: GoogleFonts.manrope(
                          color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2),
        ),
      );

  Widget _glassContainer({required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: child,
          ),
        ),
      );

  Widget _buildLoginButton(Color kPrimary) => GestureDetector(
        onTap: _loading ? null : _submit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF0F2027)],
            ),
          ),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : Text("Ingresar",
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ),
      );

  Widget _registerLink(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("¿No tenés cuenta?",
              style: GoogleFonts.manrope(color: Colors.white70)),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterScreenPro()),
            ),
            child: Text("Registrate",
                style: GoogleFonts.manrope(
                    color: const Color(0xFF14B8A6),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      );
}
