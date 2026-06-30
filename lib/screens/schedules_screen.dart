import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class HorariosScreen extends StatefulWidget {
  final int idLinha;
  final String nomeLinha;

  const HorariosScreen({
    super.key,
    required this.idLinha,
    required this.nomeLinha,
  });

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  int _sentido = 1;
  List<Map<String, dynamic>> _horarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarHorarios();
  }

  Future<void> _carregarHorarios() async {
    setState(() => _isLoading = true);
    try {
      final horarios = await DatabaseHelper.getHorarios(widget.idLinha, _sentido);
      setState(() {
        _horarios = horarios;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERRO horários: $e');
      setState(() => _isLoading = false);
    }
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

                // Nome da linha
                Text(
                  widget.nomeLinha,
                  style: const TextStyle(
                    color: Color(0xFF00399e),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Botões Ida / Volta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_sentido != 1) {
                              setState(() => _sentido = 1);
                              _carregarHorarios();
                            }
                          },
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _sentido == 1 ? const Color(0xFF00399e) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFd0e4ff)),
                            ),
                            child: Center(
                              child: Text(
                                'IDA',
                                style: TextStyle(
                                  color: _sentido == 1 ? Colors.white : const Color(0xFF00399e),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_sentido != 2) {
                              setState(() => _sentido = 2);
                              _carregarHorarios();
                            }
                          },
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: _sentido == 2 ? const Color(0xFF00399e) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFd0e4ff)),
                            ),
                            child: Center(
                              child: Text(
                                'VOLTA',
                                style: TextStyle(
                                  color: _sentido == 2 ? Colors.white : const Color(0xFF00399e),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Lista de horários
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00399e)))
                      : _horarios.isEmpty
                          ? const Center(
                              child: Text(
                                'Sem horários disponíveis',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _horarios.length,
                              itemBuilder: (context, index) {
                                return _buildHorarioCard(_horarios[index]);
                              },
                            ),
                ),

                // Legenda
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00b33e), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Efetua-se', style: TextStyle(color: Color(0xFF00b33e), fontSize: 12)),
                      const SizedBox(width: 20),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF00399e), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Não se efetua', style: TextStyle(color: Color(0xFF00399e), fontSize: 12)),
                    ],
                  ),
                ),
              ],
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
                  width: 36,
                  height: 36,
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

  Widget _buildHorarioCard(Map<String, dynamic> h) {
    final dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM', 'FER'];
    final valores = [
      h['Monday'] == 1,
      h['Tuesday'] == 1,
      h['Wednesday'] == 1,
      h['Thursday'] == 1,
      h['Friday'] == 1,
      h['Saturday'] == 1,
      h['Sunday'] == 1,
      h['Holydays'] == 1,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                h['Schedule'] ?? '',
                style: const TextStyle(color: Color(0xFF00399e), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text(' — ', style: TextStyle(color: Color(0xFFcccccc), fontSize: 14)),
              Expanded(
                child: Text(
                  h['Destino'] ?? '',
                  style: const TextStyle(color: Color(0xFF00b33e), fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 32, height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf4f8ff),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFd0e4ff)),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFF00399e)),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 32, height: 32,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf4f8ff),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFd0e4ff)),
                  ),
                  child: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF00399e)),
                ),
              ),
            ],
          ),

          const Divider(color: Color(0xFFf0f4ff), height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dias.length, (i) {
              final ativo = valores[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: ativo ? const Color(0xFFe6f9ee) : const Color(0xFFe8eeff),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dias[i],
                  style: TextStyle(
                    color: ativo ? const Color(0xFF00b33e) : const Color(0xFF00399e),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
