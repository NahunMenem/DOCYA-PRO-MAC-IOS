import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'terminos_screen.dart';
import '../widgets/docya_snackbar.dart';

class RegisterScreenPro extends StatefulWidget {
  const RegisterScreenPro({super.key});

  @override
  State<RegisterScreenPro> createState() => _RegisterScreenProState();
}

class _RegisterScreenProState extends State<RegisterScreenPro> {
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final _auth = AuthService();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _matricula = TextEditingController();
  final _especialidad = TextEditingController();
  final _phone = TextEditingController();
  final _dni = TextEditingController();

  bool _aceptaCondiciones = false;
  bool _loading = false;
  String? _error;
  String _tipo = "Médico";

  String? _fotoPerfil;
  String? _fotoDniFrente;
  String? _fotoDniDorso;
  String? _selfieDni;

  List<Map<String, String>> _provincias = [
    {"nombre": "Buenos Aires"},
    {"nombre": "Ciudad Autónoma de Buenos Aires"},
    {"nombre": "Córdoba"},
    {"nombre": "Santa Fe"},
    {"nombre": "Mendoza"},
    {"nombre": "Tucumán"},
    {"nombre": "Entre Ríos"},
    {"nombre": "Salta"},
    {"nombre": "Misiones"},
    {"nombre": "Chaco"},
    {"nombre": "Corrientes"},
    {"nombre": "Santiago del Estero"},
    {"nombre": "San Juan"},
    {"nombre": "Jujuy"},
    {"nombre": "Río Negro"},
    {"nombre": "Neuquén"},
    {"nombre": "Formosa"},
    {"nombre": "Chubut"},
    {"nombre": "San Luis"},
    {"nombre": "Catamarca"},
    {"nombre": "La Rioja"},
    {"nombre": "La Pampa"},
    {"nombre": "Santa Cruz"},
    {"nombre": "Tierra del Fuego"},
  ];

  List _localidades = [];
  List _comunas = [];

  String? _provincia;
  String? _localidad;
  String? _comuna;

  @override
  void initState() {
    super.initState();
  }

  // =====================================================
  // 📌 CARGAR LOCALIDADES DESDE TU BACK
  // =====================================================
  Future<void> _cargarLocalidades(String provincia) async {
    try {
      final provEncoded = Uri.encodeComponent(provincia);
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/localidades/$provEncoded");

      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final locs = data["localidades"] ?? [];

        setState(() {
          _localidades = locs.map((e) => {"nombre": e}).toList();
          _localidad = null;
          _comuna = null;
        });
      }
    } catch (_) {
      setState(() => _localidades = []);
    }
  }

  // =====================================================
  // 📌 CARGAR COMUNAS DE CABA
  // =====================================================
  Future<void> _cargarComunas() async {
    setState(() {
      _comunas = List.generate(
        15,
        (i) => {"nombre": "Comuna ${i + 1}", "numero": "${i + 1}"},
      );
      _comuna = null;
    });
  }

  // =====================================================
  // 📌 SUBIR FOTO (BACK DE DOCYA)
  // =====================================================
  Future<void> _pickAndUpload(Function(String) callback) async {
    try {
      final XFile? img =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

      if (img == null) return;

      final bytes = await img.readAsBytes();

      final req = http.MultipartRequest(
        "POST",
        Uri.parse(
            "https://docya-railway-production.up.railway.app/upload_foto"),
      );

      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: img.name,
        ),
      );

      final resp = await req.send();

      if (resp.statusCode == 200) {
        final body = await resp.stream.bytesToString();
        final data = json.decode(body);

        if (data["url"] != null) {
          setState(() => callback(data["url"]));

          DocYaSnackbar.show(
            context,
            title: "✔ Imagen cargada",
            message: "La foto se subió correctamente.",
          );
        }
      } else {
        DocYaSnackbar.show(
          context,
          title: "Error",
          message: "No se pudo subir la imagen.",
          type: SnackType.error,
        );
      }
    } catch (_) {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: "Ocurrió un problema procesando la imagen.",
        type: SnackType.error,
      );
    }
  }

  // =====================================================
  // 📌 INPUT STYLE
  // =====================================================
  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF14B8A6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
        ),
        labelStyle: TextStyle(color: Colors.white70),
      );

  // =====================================================
  // 📌 SUBMIT FINAL
  // =====================================================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_provincia == null ||
        (_provincia == "Ciudad Autónoma de Buenos Aires" && _comuna == null) ||
        (_provincia != "Ciudad Autónoma de Buenos Aires" &&
            _localidad == null)) {
      setState(() => _error = "Selecciona tu provincia y localidad/comuna.");
      return;
    }

    if (!_aceptaCondiciones) {
      setState(() => _error = "Debes aceptar los términos y condiciones.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final resp = await _auth.registerMedico(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
      matricula: _matricula.text.trim(),
      especialidad: _especialidad.text.trim(),
      telefono: _phone.text.trim(),
      provincia: _provincia!,
      localidad: _provincia == "Ciudad Autónoma de Buenos Aires"
          ? _comuna!
          : _localidad!,
      dni: _dni.text.trim(),
      tipo: _tipo.toLowerCase(),
      fotoPerfil: _fotoPerfil,
      fotoDniFrente: _fotoDniFrente,
      fotoDniDorso: _fotoDniDorso,
      selfieDni: _selfieDni,
    );

    setState(() => _loading = false);

    if (!mounted) return;

    if (resp["ok"] == true) {
      Navigator.pop(context);
      DocYaSnackbar.show(
        context,
        title: "✔ Registro exitoso",
        message: "Revisa tu correo para activar tu cuenta.",
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠ Error",
        message: resp["detail"] ?? "No se pudo registrar.",
        type: SnackType.error,
      );
    }
  }

  // =====================================================
  // 📌 UI COMPLETA
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                Image.asset("assets/DOCYAPROBLANCO.png", height: 90)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.3),

                const SizedBox(height: 20),

                Text("Registrate en DocYa Pro",
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),

                const SizedBox(height: 20),

                _glass(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // TIPO
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _tipo,
                          decoration: _inputStyle(
                              "Tipo de profesional",
                              PhosphorIconsRegular.stethoscope),
                          dropdownColor: const Color(0xFF203A43),
                          items: const [
                            DropdownMenuItem(
                                value: "Médico",
                                child: Text("Médico",
                                    style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(
                                value: "Enfermero",
                                child: Text("Enfermero",
                                    style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (v) => setState(() => _tipo = v!),
                        ),

                        const SizedBox(height: 16),

                        _field(_name, "Nombre y apellido",
                            PhosphorIconsRegular.user),
                        _field(_dni, "DNI / Pasaporte",
                            PhosphorIconsRegular.identificationCard),
                        _field(_matricula, "Matrícula profesional",
                            PhosphorIconsRegular.identificationCard),
                        _field(_especialidad, "Especialidad",
                            PhosphorIconsRegular.stethoscope),
                        _field(_phone, "Teléfono de contacto",
                            PhosphorIconsRegular.phone),
                        _field(_email, "Correo electrónico",
                            PhosphorIconsRegular.envelopeSimple),
                        _field(_password, "Contraseña",
                            PhosphorIconsRegular.lock,
                            obscure: true),
                        _field(_confirm, "Confirmar contraseña",
                            PhosphorIconsRegular.checkCircle,
                            obscure: true),

                        const SizedBox(height: 16),

                        // PROVINCIA
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _provincia,
                          decoration: _inputStyle(
                              "Provincia", PhosphorIconsRegular.mapPin),
                          dropdownColor: const Color(0xFF203A43),
                  
                          items: _provincias
                            .map<DropdownMenuItem<String>>(
                              (p) => DropdownMenuItem<String>(
                                value: p["nombre"]!,
                                child: Text(p["nombre"]!, style: TextStyle(color: Colors.white)),
                              ),
                            )
                            .toList(),

                          onChanged: (v) {
                            setState(() {
                              _provincia = v;
                              _localidad = null;
                              _comuna = null;
                            });

                            if (v == "Ciudad Autónoma de Buenos Aires") {
                              _cargarComunas();
                            } else {
                              _cargarLocalidades(v!);
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // ============================
                        // CABA → COMUNAS
                        // ============================
                        if (_provincia ==
                            "Ciudad Autónoma de Buenos Aires")
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _comuna,
                            decoration: _inputStyle("Comuna",
                                PhosphorIconsRegular.mapPinArea),
                            dropdownColor: const Color(0xFF203A43),
                
                            items: _comunas
                                .map<DropdownMenuItem<String>>(
                                  (c) => DropdownMenuItem<String>(
                                    value: c["nombre"],
                                    child: Text(c["nombre"], style: TextStyle(color: Colors.white)),
                                  ),
                                )
                                .toList(),

                            onChanged: (v) =>
                                setState(() => _comuna = v),
                          ),

                        // ============================
                        // OTRA PROVINCIA → LOCALIDAD
                        // ============================
                        if (_provincia !=
                                "Ciudad Autónoma de Buenos Aires" &&
                            _localidades.isNotEmpty)
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _localidad,
                            decoration: _inputStyle("Localidad",
                                PhosphorIconsRegular.mapPinLine),
                            dropdownColor: const Color(0xFF203A43),
            
                            items: _localidades
                                .map<DropdownMenuItem<String>>(
                                  (l) => DropdownMenuItem<String>(
                                    value: l["nombre"],
                                    child: Text(l["nombre"], style: TextStyle(color: Colors.white)),
                                  ),
                                )
                                .toList(),

                            onChanged: (v) =>
                                setState(() => _localidad = v),
                          ),

                        const SizedBox(height: 20),

                        _uploadButton("Foto de perfil",
                            PhosphorIconsRegular.userCircle,
                            (u) => _fotoPerfil = u, _fotoPerfil),

                        _uploadButton(
                            "DNI Frente",
                            PhosphorIconsRegular.identificationCard,
                            (u) => _fotoDniFrente = u,
                            _fotoDniFrente),

                        _uploadButton(
                            "DNI Dorso",
                            PhosphorIconsRegular.identificationCard,
                            (u) => _fotoDniDorso = u,
                            _fotoDniDorso),

                        _uploadButton("Selfie con documento",
                            PhosphorIconsRegular.camera,
                            (u) => _selfieDni = u, _selfieDni),

                        CheckboxListTile(
                          value: _aceptaCondiciones,
                          activeColor: Color(0xFF14B8A6),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    "Acepto los Términos y Condiciones",
                                    style: TextStyle(color: Colors.white70)),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => TerminosScreen()),
                                ),
                                child: Text("Ver",
                                    style: TextStyle(
                                        color: Color(0xFF14B8A6),
                                        decoration:
                                            TextDecoration.underline)),
                              )
                            ],
                          ),
                          onChanged: (v) =>
                              setState(() => _aceptaCondiciones = v!),
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        ),

                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(color: Colors.redAccent)),

                        const SizedBox(height: 20),

                        _submitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 📌 HELPER UI ELEMENTS
  // =====================================================
  Widget _glass({required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: child,
          ),
        ),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: Colors.white),
        decoration: _inputStyle(label, icon),
        validator: (v) => v == null || v.isEmpty ? "Requerido" : null,
      ),
    );
  }

  Widget _uploadButton(
          String label, IconData icon, Function(String) cb, String? val) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                val != null ? Color(0xFF14B8A6) : Colors.white.withOpacity(0.1),
            minimumSize: Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(icon, color: Colors.white),
          label: Text(
            val != null ? "✔ $label cargado" : "Subir $label",
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () => _pickAndUpload(cb),
        ),
      );

  Widget _submitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF14B8A6),
            padding: EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? CircularProgressIndicator(color: Colors.white)
              : Text(
                  "Crear cuenta",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
        ),
      );
}
