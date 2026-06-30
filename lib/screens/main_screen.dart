import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'rotas_screen.dart';
import 'tempos_screen.dart';
import 'reservas_screen.dart';
import 'complaint_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _reservasEnabled = true;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RotasScreen(),
    const TemposScreen(),
    const ReservasScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkEmpresa();
  }

  Future<void> _checkEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    final idEmpresa = prefs.getInt('idEmpresa') ?? -1;
    setState(() => _reservasEnabled = idEmpresa != 46);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _buildNavItem(0, Icons.home_outlined, Icons.home, 'Início'),
                    _buildNavItem(1, Icons.route_outlined, Icons.route, 'Rotas'),
                    _buildNavItem(2, Icons.access_time_outlined, Icons.access_time, 'Tempos'),
                    _buildNavItem(3, Icons.calendar_month_outlined, Icons.calendar_month, 'Reservas', enabled: _reservasEnabled),
                    _buildMoreItem(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData iconActive, String label, {bool enabled = true}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF00399e) : Colors.grey;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _currentIndex = index) : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                top: 0,
                left: 8,
                right: 8,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00399e),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            Center(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? iconActive : icon,
                      color: color,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? color : Colors.grey.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem() {
    return Expanded(
      child: GestureDetector(
        onTap: _showMoreMenu,
        behavior: HitTestBehavior.opaque,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu, color: Colors.grey, size: 24),
              SizedBox(height: 2),
              Text('...', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined, color: Color(0xFF00399e)),
                title: const Text('Reclamações'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ComplaintScreen()),
                  );
                },
              ),
             ListTile(
  leading: const Icon(Icons.person_outline, color: Color(0xFF00399e)),
  title: const Text('Perfil'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  },
),
            ],
          ),
        ),
      ),
    );
  }
}
