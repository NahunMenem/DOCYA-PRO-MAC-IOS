import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/docya_snackbar.dart'; // 👈 Importa el snackbar

class EditarAliasScreen extends StatefulWidget {
  final String medicoId;
  final String aliasActual;

  const EditarAliasScreen({
    super.key,
    required this.medicoId,
    required this.aliasActual,
  });

  @override
  State<EditarAliasScreen> createState() => _EditarAliasScreenState();
}

class _EditarAliasScreenState extends State<EditarAliasScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aliasController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(text: widget.aliasActual);
  }

  Future<void> _guardarAlias() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/medicos/${widget.medicoId}/alias",
      );

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"alias": _aliasController.text}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          DocYaSnackbar.show(
            context,
            title: "✅ Guardado",
            message: "Alias actualizado correctamente",
            type: SnackType.success,
          );
          Navigator.pop(context, _aliasController.text);
        }
      } else {
        DocYaSnackbar.show(
          context,
          title: "❌ Error",
          message: "No se pudo guardar el alias",
          type: SnackType.error,
        );
      }
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "Error de conexión: $e",
        type: SnackType.warning,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF14B8A6);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Alias / CBU"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: "Alias o CBU",
                  prefixIcon: Icon(Icons.account_balance),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return "Ingresá un alias o CBU válido";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _guardarAlias,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Guardar", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
