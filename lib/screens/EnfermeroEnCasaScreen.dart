import 'package:flutter/material.dart';

class EnfermeroEnCasaScreen extends StatelessWidget {
  final int consultaId;
  final int enfermeroId;
  final String pacienteUuid;
  final String pacienteNombre;
  final String direccion;
  final String telefono;
  final String motivo;
  final double lat;
  final double lng;
  final VoidCallback onFinalizar;

  const EnfermeroEnCasaScreen({
    super.key,
    required this.consultaId,
    required this.enfermeroId,
    required this.pacienteUuid,
    required this.pacienteNombre,
    required this.direccion,
    required this.telefono,
    required this.motivo,
    required this.lat,
    required this.lng,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enfermero en Casa"),
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Consulta #$consultaId", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Paciente: $pacienteNombre"),
            Text("Motivo: $motivo"),
            Text("Dirección: $direccion"),
            Text("Teléfono: $telefono"),
            const Spacer(),
            ElevatedButton(
              onPressed: onFinalizar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Center(
                child: Text("Finalizar Consulta", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
