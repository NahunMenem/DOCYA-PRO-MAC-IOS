import 'package:flutter/material.dart';
import 'inicio_screen.dart';
import 'historial_screen.dart';
import 'consultas_en_curso_screen.dart';
import 'perfil_screen.dart';
import 'MedicoEnCasaScreen.dart'; // 👈 asegurate de tener esta pantalla creada

class HomeMenu extends StatefulWidget {
  final String userId;
  final String nombreUsuario;

  const HomeMenu({
    super.key,
    required this.userId,
    required this.nombreUsuario,
  });

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  int _selectedIndex = 0;

  // 📌 Estado de consulta activa
  Map<String, dynamic>? _consultaActiva;

  void _setConsultaActiva(Map<String, dynamic>? consulta) {
    setState(() {
      _consultaActiva = consulta;
    });
  }

  List<Widget> _buildScreens() {
    return [
      InicioScreen(
        userId: widget.userId,
        onAceptarConsulta: _setConsultaActiva, // 👈 callback desde Inicio
      ),
      HistorialScreen(medicoId: int.parse(widget.userId)),
      _consultaActiva != null
          ? MedicoEnCasaScreen(
              consultaId: _consultaActiva!["id"],
              medicoId: _consultaActiva!["medico_id"] ??
                  int.parse(widget.userId), // 👈 fallback al userId
              pacienteUuid: _consultaActiva!["paciente_uuid"],
              pacienteNombre:
                  _consultaActiva!["paciente_nombre"] ?? "Paciente",
              direccion: _consultaActiva!["direccion"],
              telefono: _consultaActiva!["telefono"] ?? "Sin número", // ✅ corregido
              motivo: _consultaActiva!["motivo"],
              lat: _consultaActiva!["lat"] ?? 0.0, // 👈 fallback
              lng: _consultaActiva!["lng"] ?? 0.0, // 👈 fallback
              onFinalizar: () => _setConsultaActiva(null), // limpia al finalizar
            )
          : const ConsultasEnCursoScreen(),
      PerfilScreen(
        nombreUsuario: widget.nombreUsuario,
        medicoId: widget.userId,
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1C1C1E), // gris oscuro tipo iOS
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF14B8A6),
        unselectedItemColor: Colors.grey.shade500,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Consultas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'En curso',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
