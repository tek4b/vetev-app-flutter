import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  List<Map<String, dynamic>> _reservas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarReservas();
  }

  Future<void> _carregarReservas() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final clientID = prefs.getInt('ClientID') ?? 0;
      final connection = prefs.getString('Connection') ?? '';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final year = DateTime.now().year;

      final response = await http.post(
        Uri.parse('${endpoint}GetReservationsClient'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'clientID': clientID,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final status = d['Status']?.toString() ?? 'false';

        if (status.toLowerCase() == 'true') {
          final reservasJson = d['Reservations'] as List? ?? [];
          final reservas = reservasJson.map((r) {
            String tripDate = r['TripDate']?.toString() ?? '';
            if (tripDate.contains(' ')) tripDate = tripDate.split(' ')[0];

            final statusCode = r['Status'] ?? 0;
            String estadoTexto;
            switch (statusCode) {
              case 0: estadoTexto = 'Confirmada'; break;
              case 1: estadoTexto = 'Cancelada'; break;
              case 2: estadoTexto = 'Utilizada'; break;
              default: estadoTexto = 'Desconhecido';
            }

            return {
              'reservationId': r['ReservationID'] ?? 0,
              'numero': 'Reserva #${r['ReservationID'] ?? 0}',
              'lineID': r['LineID'] ?? 0,
              'tripDate': tripDate,
              'schedule': r['Schedule'] ?? '',
              'status': estadoTexto,
              'reservationDate': r['ReservationDate'] ?? '',
            };
          }).toList();

          setState(() {
            _reservas = List<Map<String, dynamic>>.from(reservas);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('ERRO reservas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelarReserva(Map<String, dynamic> reserva) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final connection = prefs.getString('Connection') ?? '';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final year = DateTime.now().year;

      final response = await http.post(
        Uri.parse('${endpoint}CancelReservationClient'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'idReserva': reserva['reservationId'],
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final status = d['Status']?.toString() ?? 'false';

        if (status.toLowerCase() == 'true') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reserva cancelada com sucesso'),
                backgroundColor: Color(0xFF00b33e),
              ),
            );
            _carregarReservas();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível cancelar a reserva'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ERRO cancelar: $e');
    }
  }

  void _confirmarCancelamento(Map<String, dynamic> reserva) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('Deseja cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelarReserva(reserva);
            },
            child: const Text('Sim', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmada': return const Color(0xFF00b33e);
      case 'cancelada': return const Color(0xFFe03131);
      default: return const Color(0xFFf59f00);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmada': return const Color(0xFFe6f9ee);
      case 'cancelada': return const Color(0xFFffe0e0);
      default: return const Color(0xFFfff3cd);
    }
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

              // Header com botão nova reserva
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF00399e), size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'RESERVAS',
                        style: TextStyle(
                          color: Color(0xFF00399e),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NovaReservaScreen()),
                        );
                        _carregarReservas();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00399e),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Lista
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00399e)))
                    : _reservas.isEmpty
                        ? const Center(
                            child: Text(
                              'Sem reservas disponíveis',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _reservas.length,
                            itemBuilder: (context, index) {
                              return _buildReservaCard(_reservas[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReservaCard(Map<String, dynamic> r) {
    final status = r['status'] as String;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  r['numero'] as String,
                  style: const TextStyle(
                    color: Color(0xFF00399e),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmarCancelamento(r),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFffe0e0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Color(0xFFe03131), size: 18),
                ),
              ),
            ],
          ),

          const Divider(color: Color(0xFFf0f4ff), height: 16),

          Text('Linha: ${r['lineID']}', style: const TextStyle(color: Color(0xFF00b33e), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Data da Viagem: ${r['tripDate']}', style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
          Text('Horário: ${r['schedule']}', style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
          Text('Data da Reserva: ${r['reservationDate']}', style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        ],
      ),
    );
  }
}

// ===========================
// NOVA RESERVA
// ===========================
class NovaReservaScreen extends StatefulWidget {
  const NovaReservaScreen({super.key});

  @override
  State<NovaReservaScreen> createState() => _NovaReservaScreenState();
}

class _NovaReservaScreenState extends State<NovaReservaScreen> {
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _linhas = [];
  List<Map<String, dynamic>> _horarios = [];
  int? _selectedLinhaId;
  String? _selectedHorarioValue;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarLinhas();
  }

  Future<void> _carregarLinhas() async {
    final linhas = await DatabaseHelper.getLinhas();
    setState(() {
      _linhas = linhas;
      if (linhas.isNotEmpty) {
        _selectedLinhaId = linhas.first['IDPlataforma'] as int?;
        _carregarHorarios(_selectedLinhaId ?? 0);
      }
    });
  }

  Future<void> _carregarHorarios(int idLinha) async {
    final horarios = await DatabaseHelper.getHorarios(idLinha, 1);
    setState(() {
      _horarios = horarios;
      _selectedHorarioValue = horarios.isNotEmpty ? horarios.first['Schedule'] as String? : null;
    });
  }

  Future<void> _enviarReserva() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma data'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedLinhaId == null || _selectedHorarioValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione rota e horário'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final clientID = prefs.getInt('ClientID') ?? 0;
      final connection = prefs.getString('Connection') ?? '';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final year = DateTime.now().year;

      final dataFormatada =
          '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

      final response = await http.post(
        Uri.parse('${endpoint}CreateReservationClient'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'clientID': clientID,
          'lineID': _selectedLinhaId,
          'schedule': _selectedHorarioValue,
          'tripDate': dataFormatada,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final status = d['Status']?.toString() ?? 'false';

        if (mounted) {
          if (status.toLowerCase() == 'true') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reserva criada com sucesso!'),
                backgroundColor: Color(0xFF00b33e),
              ),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível criar a reserva'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ERRO nova reserva: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nova Reserva',
                            style: TextStyle(color: Color(0xFF00399e), fontSize: 18, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 20),

                        // Data
                        const Text('DATA', style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _selectedDate = date);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf4f8ff),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFd0e4ff)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedDate == null
                                      ? 'Selecionar data'
                                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                                  style: TextStyle(
                                    color: _selectedDate == null ? Colors.grey : const Color(0xFF00399e),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Rota
                        const Text('ROTA', style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf4f8ff),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFd0e4ff)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedLinhaId,
                              isExpanded: true,
                              style: const TextStyle(color: Color(0xFF00399e), fontSize: 14),
                              items: _linhas.map((l) => DropdownMenuItem<int>(
                                value: l['IDPlataforma'] as int,
                                child: Text(l['nome'] as String? ?? ''),
                              )).toList(),
                              onChanged: (v) {
                                setState(() => _selectedLinhaId = v);
                                if (v != null) _carregarHorarios(v);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Horário
                        const Text('HORÁRIO', style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf4f8ff),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFd0e4ff)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedHorarioValue,
                              isExpanded: true,
                              style: const TextStyle(color: Color(0xFF00399e), fontSize: 14),
                              items: _horarios.map((h) => DropdownMenuItem<String>(
                                value: h['Schedule'] as String,
                                child: Text(h['Schedule'] as String? ?? ''),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedHorarioValue = v),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _enviarReserva,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00399e),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : const Text('CONFIRMAR RESERVA',
                                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
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
