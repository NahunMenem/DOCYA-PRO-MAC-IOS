import 'package:flutter/material.dart';
import 'inicio_screen.dart';

class HomeScreen extends StatelessWidget {
  final String nombreUsuario;
  final String userId; // UUID del médico

  const HomeScreen({
    super.key,
    required this.nombreUsuario,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenido $nombreUsuario"),
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Siempre médicos → va directo a InicioScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InicioScreen(
                  userId: userId,
                ),
              ),
            );
          },
          child: const Text("Entrar como Médico"),
        ),
      ),
    );
  }
}
