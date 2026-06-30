import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'schedules_screen.dart';

class RotasScreen extends StatefulWidget {
  const RotasScreen({super.key});

  @override
  State<RotasScreen> createState() => _RotasScreenState();
}

class _RotasScreenState extends State<RotasScreen> {
  List<Map<String, dynamic>> _linhas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarLinhas();
  }

  Future<void> _carregarLinhas() async {
    try {
      final linhas = await DatabaseHelper.getLinhas();
      final linhasComParagens = <Map<String, dynamic>>[];
      for (final linha in linhas) {
        final idPlataforma = linha['IDPlataforma'] as int? ?? 0;
        final numParagens = await DatabaseHelper.getNumeroParagens(idPlataforma);
        linhasComParagens.add({...linha, 'numParagens': numParagens});
      }
      setState(() {
        _linhas = linhasComParagens;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERRO ao carregar linhas: $e');
      setState(() => _isLoading = false);
    }
  }

  String _extractRouteCode(String nomeAbrev) {
    try {
      final parts = nomeAbrev.trim().split(RegExp(r'\s+'));
      for (final part in parts) {
        if (RegExp(r'^\d+$').hasMatch(part)) {
          return 'R$part';
        }
      }
    } catch (_) {}
    return 'R?';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fundo de ondas
        Positioned.fill(
          child: Image.asset('assets/images/fundoqrcode.png', fit: BoxFit.cover),
        ),

        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50),

              // Logo
              Container(
                width: 60,
                height: 60,
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

              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: Color(0xFF00399e), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'ROTAS | HORÁRIOS | PERCURSOS',
                      style: TextStyle(
                        color: Color(0xFF00399e),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Lista de linhas
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00399e)),
                      )
                    : _linhas.isEmpty
                        ? const Center(
                            child: Text(
                              'Sem rotas disponíveis',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _linhas.length,
                            itemBuilder: (context, index) {
                              final linha = _linhas[index];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HorariosScreen(
                                        idLinha: linha['IDPlataforma'] as int? ?? 0,
                                        nomeLinha: linha['nomeabrev'] as String? ?? '',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Número da rota
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFe8eeff),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _extractRouteCode(linha['nomeabrev'] as String? ?? ''),
                                            style: const TextStyle(
                                              color: Color(0xFF00399e),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Nome e paragens
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              linha['nome'] as String? ?? '',
                                              style: const TextStyle(
                                                color: Color(0xFF222222),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${linha['numParagens']} Paragens',
                                              style: const TextStyle(
                                                color: Color(0xFF888888),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Badge Ativa
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFe6f9ee),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Ativa',
                                          style: TextStyle(
                                            color: Color(0xFF00b33e),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Seta
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
