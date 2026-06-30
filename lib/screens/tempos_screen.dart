import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/database_helper.dart';

class TemposScreen extends StatefulWidget {
  const TemposScreen({super.key});

  @override
  State<TemposScreen> createState() => _TemposScreenState();
}

class _TemposScreenState extends State<TemposScreen> {
  List<Map<String, dynamic>> _horarios = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarTempos();
    // Atualiza a cada 60 segundos
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _carregarTempos());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarTempos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final lineID = prefs.getInt('LineID') ?? 0;
      final clientLat = prefs.getString('Latitude') ?? '0.0';
      final clientLong = prefs.getString('Longitude') ?? '0.0';
      final connection = prefs.getString('Connection') ?? '';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final year = DateTime.now().year;
      final yearToken = '$year-MBMobile';

      // Vai buscar horários da BD local
      final db = await DatabaseHelper.database;
      final now = DateTime.now();
      final horaLimite = DateTime(now.year, now.month, now.day,
          now.hour - 2, now.minute);
      final horaLimiteStr =
          '${horaLimite.hour.toString().padLeft(2, '0')}:${horaLimite.minute.toString().padLeft(2, '0')}';

      List<Map<String, dynamic>> schedules = await db.rawQuery(
        'SELECT Schedule FROM TabSchedules WHERE LineID=? AND ShowLastTimes=1 AND Schedule >= ? ORDER BY Schedule',
        [lineID, horaLimiteStr],
      );

      if (schedules.isEmpty) {
        schedules = await db.rawQuery(
          'SELECT Schedule FROM TabSchedules WHERE LineID=? AND ShowLastTimes=1 ORDER BY Schedule LIMIT 1',
          [lineID],
        );
      }

      // Limpa tabela de próximos horários
      await db.delete('tabProximosSCHEDULES');

      // Chama o webservice para cada horário
      final List<Future<void>> futures = [];
      for (final s in schedules) {
        final horario = s['Schedule'] as String;
        futures.add(_chamarWebService(
          endpoint: endpoint,
          token: yearToken,
          lineID: lineID,
          horario: horario,
          clientLat: clientLat,
          clientLong: clientLong,
          connection: connection,
        ));
      }
      await Future.wait(futures);

      // Carrega da BD
      await _carregarDaBD(lineID);
    } catch (e) {
      debugPrint('ERRO tempos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _chamarWebService({
    required String endpoint,
    required String token,
    required int lineID,
    required String horario,
    required String clientLat,
    required String clientLong,
    required String connection,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${endpoint}GetTimesToClient'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': token,
          'companyid': 1,
          'LineID': lineID,
          'Schedule': horario,
          'StopX': clientLat.replaceAll('.', ','),
          'StopY': clientLong.replaceAll('.', ','),
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final times = d['TimesClient'] as List? ?? [];

        final db = await DatabaseHelper.database;

        if (times.isEmpty) {
          final destino = await _getLastStop(lineID, horario);
          await db.insert('tabProximosSCHEDULES', {
            'Line': lineID,
            'Schedule': horario,
            'Destino': destino,
            'Viatura': 'N/D',
            'Tempo': 'N/D',
            'Tipo': 0,
            'IdViatura': 0,
          });
        } else {
          for (final obj in times) {
            final idViatura = obj['idViatura'] ?? 0;
            final tempoStr = obj['Tempo']?.toString() ?? '';
            final semRTA = idViatura == 0 ||
                tempoStr.contains('Serviço ainda não chegou');
            final idLinha = obj['idLinha'] ?? lineID;
            final hor = obj['Horario'] ?? horario;
            final destino = await _getLastStop(idLinha, hor);

            await db.insert('tabProximosSCHEDULES', {
              'Line': idLinha,
              'Schedule': hor,
              'Destino': destino,
              'Viatura': semRTA ? 'N/D' : (obj['Viatura'] ?? 'N/D'),
              'Tempo': semRTA ? 'N/D' : tempoStr,
              'Tipo': 0,
              'IdViatura': semRTA ? 0 : idViatura,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('ERRO webservice horário $horario: $e');
    }
  }

  Future<String> _getLastStop(int lineID, String horario) async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery(
      'SELECT Destino FROM TabSchedules WHERE LineID = ? AND Schedule = ?',
      [lineID, horario],
    );
    if (result.isEmpty) return '';
    return result.first['Destino'] as String? ?? '';
  }

  Future<void> _carregarDaBD(int lineID) async {
    try {
      final horarios = await DatabaseHelper.getProximosSchedules();
      final horariosComNome = <Map<String, dynamic>>[];

      for (final h in horarios) {
        final lineIdValue = int.tryParse(h['Line'].toString()) ?? 0;
        final nomeLinha = await DatabaseHelper.getNomeLinha(lineIdValue);
        horariosComNome.add({...h, 'NomeLinha': nomeLinha});
      }

      if (mounted) {
        setState(() {
          _horarios = horariosComNome;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERRO carregar BD: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informação'),
        content: const Text(
          'Os tempos previstos de chegada da viatura à paragem podem apresentar desvios em relação ao tempo real.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFF00399e), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'A MINHA ROTA',
                      style: TextStyle(
                        color: Color(0xFF00399e),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _carregarTempos,
                      child: const Icon(Icons.refresh, color: Color(0xFF00399e), size: 22),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Lista
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

              // Marquee info
              Container(
                color: Colors.white.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF00399e), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Os tempos previstos de chegada da viatura à paragem podem apresentar desvios em relação ao tempo real.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorarioCard(Map<String, dynamic> h) {
    final matricula = h['Viatura']?.toString() ?? 'N/D';
    final tempo = h['Tempo']?.toString() ?? 'N/D';
    final temNd = matricula == 'N/D' || tempo == 'N/D';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horário + Destino
          Row(
            children: [
              Text(
                h['Schedule'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF00399e),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  h['Destino'] ?? '',
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Nome da linha
          Text(
            h['NomeLinha'] ?? '',
            style: const TextStyle(
              color: Color(0xFF00b33e),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Divider(color: Color(0xFFf0f4ff), height: 16),

          // Matrícula + ícones + tempo
          Row(
            children: [
              Expanded(
                child: Text(
                  matricula,
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 13),
                ),
              ),

              // Ícone localizar bus
              GestureDetector(
                onTap: temNd
                    ? null
                    : () {
                        // TODO: abrir mapa da viatura
                      },
                child: Opacity(
                  opacity: temNd ? 0.3 : 1.0,
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF00399e),
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Tempo estimado
              Text(
                tempo,
                style: const TextStyle(
                  color: Color(0xFF00399e),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(width: 6),

              // Ícone info
              GestureDetector(
                onTap: _showInfoDialog,
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF00399e),
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
