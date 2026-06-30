import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _numeroMecanografico = 'N/D';
  String _email = 'N/D';
  String _token = 'N/D';
  String _lineName = 'N/D';
  String _stopName = 'N/D';
  String _turno = 'N/D';
  String _idiomaAtual = 'pt';
  bool _showTurno = true;
  double _latParagem = 0;
  double _lonParagem = 0;

  final List<Map<String, String>> _idiomas = [
    {'code': 'pt', 'flag': '🇵🇹', 'name': 'Português'},
    {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
    {'code': 'es', 'flag': '🇪🇸', 'name': 'Español'},
    {'code': 'fr', 'flag': '🇫🇷', 'name': 'Français'},
    {'code': 'ar', 'flag': '🇸🇦', 'name': 'العربية'},
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final idEmpresa = prefs.getInt('idEmpresa') ?? -1;
    final lineID = prefs.getInt('LineID') ?? 0;
    final stopID = prefs.getInt('StopID') ?? 0;

    double lat = 0;
    double lon = 0;
    try {
      lat = await DatabaseHelper.getCoordX(lineID, 1, stopID);
      lon = await DatabaseHelper.getCoordY(lineID, 1, stopID);
    } catch (_) {}

    setState(() {
      _numeroMecanografico = prefs.getString('NumeroMecanografico') ?? 'N/D';
      _email = prefs.getString('Email') ?? 'N/D';
      _token = prefs.getString('Token') ?? 'N/D';
      _lineName = prefs.getString('LineName') ?? 'N/D';
      _stopName = prefs.getString('StopName') ?? 'N/D';
      _turno = prefs.getString('Turno') ?? 'N/D';
      _idiomaAtual = prefs.getString('Idioma') ?? 'pt';
      _showTurno = idEmpresa != 46;
      _latParagem = lat;
      _lonParagem = lon;
    });
  }

  Future<void> _alterarIdioma(String idioma) async {
    if (idioma == _idiomaAtual) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('Idioma', idioma);
    setState(() => _idiomaAtual = idioma);
    // Nota: para mudar o idioma da app é necessário usar um package
    // como 'easy_localization' ou 'flutter_localizations' com restart.
  }

  void _showStopImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Foto da paragem não disponível'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/fundoqrcode.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  Container(
                    width: 60, height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card Dados do utilizador
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Os Meus Dados',
                            style: TextStyle(color: Color(0xFF00399e), fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(color: Color(0xFFf0f4ff), height: 16),
                        _buildInfoRow(Icons.badge_outlined, 'Número Mecanográfico', _numeroMecanografico),
                        _buildInfoRow(Icons.email_outlined, 'Email', _email),
                        _buildInfoRow(Icons.vpn_key_outlined, 'Token', _token),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card Linha/Paragem
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rota Atribuída',
                            style: TextStyle(color: Color(0xFF00399e), fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(color: Color(0xFFf0f4ff), height: 16),
                        _buildInfoRow(Icons.route_outlined, 'Linha', _lineName),

                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(Icons.location_on_outlined, 'Paragem', _stopName),
                            ),
                            // Foto da paragem
                            GestureDetector(
                              onTap: _showStopImage,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf4f8ff),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_outlined, color: Color(0xFF00399e), size: 18),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Ver mapa
                            GestureDetector(
                              onTap: () {
                                // TODO: navegar para mapa da paragem
                              },
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf4f8ff),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.map_outlined, color: Color(0xFF00399e), size: 18),
                              ),
                            ),
                            if (_latParagem != 0 && _lonParagem != 0) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  // TODO: abrir Google Maps com direções
                                },
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFf4f8ff),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.directions_outlined, color: Color(0xFF00399e), size: 18),
                                ),
                              ),
                            ],
                          ],
                        ),

                        if (_showTurno) _buildInfoRow(Icons.access_time_outlined, 'Turno', _turno),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card Idioma
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Idioma',
                            style: TextStyle(color: Color(0xFF00399e), fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(color: Color(0xFFf0f4ff), height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _idiomas.map((idioma) {
                            final ativo = idioma['code'] == _idiomaAtual;
                            return GestureDetector(
                              onTap: () => _alterarIdioma(idioma['code']!),
                              child: Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: ativo ? const Color(0xFF00399e) : const Color(0xFFd0e4ff),
                                    width: ativo ? 3 : 2,
                                  ),
                                ),
                                child: Center(
                                  child: Opacity(
                                    opacity: ativo ? 1.0 : 0.6,
                                    child: Text(idioma['flag']!, style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botão Ajuda / Tutorial
                  GestureDetector(
                    onTap: () {
                      // TODO: abrir PDF tutorial
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.help_outline, color: Color(0xFF00399e)),
                          SizedBox(width: 12),
                          Text(
                            'Ajuda / Tutorial',
                            style: TextStyle(
                              color: Color(0xFF00399e),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Botão voltar
          Positioned(
            top: 40,
            left: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF00399e), size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
