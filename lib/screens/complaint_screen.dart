import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _assuntoController = TextEditingController();
  final _descricaoController = TextEditingController();

  int _tipo = 2; // 2 = Sugestão, 1 = Reclamação (default)
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<Map<String, dynamic>> _typeClaims = [];
  int? _selectedTypeClaimId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarTypeClaims();
  }

  Future<void> _carregarTypeClaims() async {
    final typeClaims = await DatabaseHelper.getTypeClaims();
    setState(() {
      _typeClaims = typeClaims;
      if (typeClaims.isNotEmpty) {
        _selectedTypeClaimId = typeClaims.first['IDPlataforma'] as int?;
      }
    });
  }

  void _limparCampos() {
    _assuntoController.clear();
    _descricaoController.clear();
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _tipo = 2;
    });
  }

  Future<void> _enviarReclamacao() async {
    final assunto = _assuntoController.text.trim();
    final descricao = _descricaoController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('NumeroMecanografico') ?? '';
    final email = prefs.getString('Email') ?? '';

    if (name.isEmpty || email.isEmpty || descricao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedTypeClaimId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de ocorrência'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final lineID = prefs.getInt('LineID') ?? 0;
      final stopID = prefs.getInt('StopID') ?? 0;
      final clientID = prefs.getInt('ClientID') ?? 0;
      final connection = prefs.getString('Connection') ?? '';
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final year = DateTime.now().year;

      final dateOccurrence = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : '';
      final hourOccurrence = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : '';

      final subject = _tipo == 1 ? 'Nova Reclamação de $name' : 'Nova Sugestão de $name';

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/SendInfoClaimPBI'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'clientID': clientID,
          'name': name,
          'email': email,
          'contactTel': '0',
          'contactMob': '0',
          'address': '',
          'postalCode': '',
          'locality': '',
          'busFrom': lineID.toString(),
          'busTo': stopID.toString(),
          'motoristNumber': '',
          'motoristName': '',
          'vehicleNumber': 0,
          'dateOccurrence': dateOccurrence,
          'hourOccurrence': hourOccurrence,
          'localOccurrence': '',
          'type': _tipo,
          'claimtype': _selectedTypeClaimId,
          'description': descricao,
          'attachment': '',
          'filename': '',
          'comercial': '',
          'exploration': '',
          'maintenance': '',
          'subject': subject,
          'DescriptionAbrev': assunto,
          'others': '',
          'identification': 1,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final outer = jsonDecode(response.body);
        String innerStr = (outer['d'] ?? '').toString().trim();

        // Corrige JSON malformado removendo '}' extra no fim
        String fixed = innerStr;
        Map<String, dynamic>? inner;
        while (true) {
          try {
            inner = jsonDecode(fixed);
            break;
          } catch (_) {
            if (fixed.endsWith('}')) {
              fixed = fixed.substring(0, fixed.length - 1).trim();
            } else {
              break;
            }
          }
        }

        final statusStr = inner?['Status']?.toString() ?? '';
        final ok = statusStr.toLowerCase() == 'true';

        if (mounted) {
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reclamação enviada com sucesso!'),
                backgroundColor: Color(0xFF00b33e),
              ),
            );
            _limparCampos();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao enviar reclamação'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ERRO enviar reclamação: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha na comunicação com o servidor'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _assuntoController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF00399e),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
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

                  // Card principal
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
                        // Tipo
                        _buildLabel('TIPO'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tipo = 2),
                                child: Container(
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: _tipo == 2 ? const Color(0xFF00399e) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFd0e4ff)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sugestão',
                                      style: TextStyle(
                                        color: _tipo == 2 ? Colors.white : const Color(0xFF00399e),
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
                                onTap: () => setState(() => _tipo = 1),
                                child: Container(
                                  height: 44,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: _tipo == 1 ? const Color(0xFF00399e) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFd0e4ff)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Reclamação',
                                      style: TextStyle(
                                        color: _tipo == 1 ? Colors.white : const Color(0xFF00399e),
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

                        const SizedBox(height: 16),

                        // Assunto
                        _buildLabel('ASSUNTO'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFf4f8ff),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFd0e4ff)),
                          ),
                          child: TextField(
                            controller: _assuntoController,
                            style: const TextStyle(color: Color(0xFF00399e)),
                            decoration: const InputDecoration(
                              hintText: 'Assunto',
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Tipo de Ocorrência
                        _buildLabel('TIPO DE OCORRÊNCIA'),
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
                              value: _selectedTypeClaimId,
                              isExpanded: true,
                              hint: const Text('Selecione...'),
                              style: const TextStyle(color: Color(0xFF00399e), fontSize: 14),
                              items: _typeClaims.map((t) => DropdownMenuItem<int>(
                                value: t['IDPlataforma'] as int,
                                child: Text(t['nome'] as String? ?? ''),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedTypeClaimId = v),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Data e Hora
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('DATA DA OCORRÊNCIA'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) setState(() => _selectedDate = date);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFf4f8ff),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFd0e4ff)),
                                      ),
                                      child: Text(
                                        _selectedDate == null
                                            ? 'DD/MM/AAAA'
                                            : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                                        style: TextStyle(
                                          color: _selectedDate == null ? Colors.grey : const Color(0xFF00399e),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('HORA'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (time != null) setState(() => _selectedTime = time);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFf4f8ff),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFd0e4ff)),
                                      ),
                                      child: Text(
                                        _selectedTime == null
                                            ? 'HH:MM'
                                            : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: _selectedTime == null ? Colors.grey : const Color(0xFF00399e),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Anexos
                        _buildLabel('ANEXOS'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () {
                                // TODO: anexar ficheiro
                              },
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf4f8ff),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFd0e4ff)),
                                ),
                                child: const Icon(Icons.attach_file, color: Color(0xFF00399e), size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                // TODO: tirar foto
                              },
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf4f8ff),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFd0e4ff)),
                                ),
                                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF00399e), size: 20),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Descrição
                        _buildLabel('DESCRIÇÃO'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFf4f8ff),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFd0e4ff)),
                          ),
                          child: TextField(
                            controller: _descricaoController,
                            maxLines: 4,
                            style: const TextStyle(color: Color(0xFF00399e)),
                            decoration: const InputDecoration(
                              hintText: 'Descreva a sua sugestão ou reclamação...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botão Enviar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _enviarReclamacao,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00399e),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('ENVIAR',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
