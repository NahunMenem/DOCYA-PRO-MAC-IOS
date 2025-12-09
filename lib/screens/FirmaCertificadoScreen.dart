// lib/screens/FirmaCertificadoScreen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart'; // 👈 esto trae MediaType

class FirmaCertificadoScreen extends StatefulWidget {
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;
  final String contenidoCertificado;

  const FirmaCertificadoScreen({
    super.key,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
    required this.contenidoCertificado,
  });

  @override
  State<FirmaCertificadoScreen> createState() => _FirmaCertificadoScreenState();
}

class _FirmaCertificadoScreenState extends State<FirmaCertificadoScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _saving = false;

  Future<void> _guardarFirma() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Debes firmar antes de continuar")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      Uint8List? firmaBytes = await _controller.toPngBytes();
      if (firmaBytes == null) {
        throw Exception("Error al generar imagen de la firma");
      }

      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/certificado_pdf");

      final request = http.MultipartRequest("POST", url);
      request.fields["medico_id"] = widget.medicoId.toString();
      request.fields["paciente_uuid"] = widget.pacienteUuid;
      request.fields["contenido"] = widget.contenidoCertificado;

      // Adjuntamos firma como archivo
      request.files.add(
        http.MultipartFile.fromBytes(
          "firma",
          firmaBytes,
          filename: "firma.png",
          contentType: MediaType("image", "png"),
        ),
      );

      final resp = await request.send();
      setState(() => _saving = false);

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Certificado PDF generado con firma")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Error: ${resp.statusCode}")),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al generar PDF: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firma digital"),
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Certificado Médico",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF14B8A6),
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(widget.contenidoCertificado),
            ),
            const SizedBox(height: 20),

            // Área para firmar
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _controller.clear(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text("Borrar firma"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _guardarFirma,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Confirmar firma y generar PDF"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
