import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _mecController = TextEditingController();

  List<String> _empresas = [];
  List<String> _subempresas = [];
  String? _selectedEmpresa;
  String? _selectedSubempresa;

  bool _privacyChecked = false;
  bool _termsChecked = false;
  bool _isLoading = false;
  bool _showRegisterButton = false;

  // Dados das empresas (id, connection)
  List<Map<String, dynamic>> _empresasData = [];

  @override
  void initState() {
    super.initState();
    _carregarEmpresas();
  }

  Future<void> _carregarEmpresas() async {
    // TODO: carregar da BD SQLite local
    // Por agora usa dados de exemplo
    setState(() {
      _empresas = ['HEINEKEN', 'EMPRESA 2'];
      _empresasData = [
        {'nome': 'HEINEKEN', 'idPlataforma': 1, 'connection': 'connectionHNK'},
        {'nome': 'EMPRESA 2', 'idPlataforma': 2, 'connection': 'connectionHNK'},
      ];
      _selectedEmpresa = _empresas.first;
      _carregarSubempresas(_selectedEmpresa!);
    });
  }

  void _carregarSubempresas(String empresa) {
    // TODO: carregar da BD SQLite local
    setState(() {
      _subempresas = ['ADECCO', 'SUBEMPRESA 2'];
      _selectedSubempresa = _subempresas.first;
    });
  }

  void _validateFields() {
    setState(() {
      _showRegisterButton = _emailController.text.trim().isNotEmpty &&
          _mecController.text.trim().isNotEmpty &&
          _privacyChecked &&
          _termsChecked;
    });
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termos e Condições'),
        content: const SingleChildScrollView(
          child: Text(
            'Ao utilizar esta aplicação, o utilizador aceita os termos e condições de utilização do serviço Vetev.',
          ),
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

  void _openPrivacyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
    final idEmpresa = prefs.getInt('idEmpresa') ?? 1;
    final url = '${baseUrl}QrCodes/$idEmpresa/politica_privacidade.pdf';
    // TODO: abrir PDF com flutter_pdfview
  }

  Future<void> _registar() async {
    if (_selectedEmpresa == null || _selectedSubempresa == null) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';

      // Guarda dados da empresa
      final empresaData = _empresasData.firstWhere(
        (e) => e['nome'] == _selectedEmpresa,
        orElse: () => {},
      );
      if (empresaData.isNotEmpty) {
        await prefs.setInt('idEmpresa', empresaData['idPlataforma']);
        await prefs.setString('Connection', empresaData['connection']);
      }

      final connection = prefs.getString('Connection') ?? '';

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/SendRegistration'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'MecanographicNumber': _mecController.text.trim(),
          'Email': _emailController.text.trim(),
          'Connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);

        if (d['Type'] == 0) {
          final token = d['Token'];
          await prefs.setString('Email', _emailController.text.trim());
          await prefs.setString('NumeroMecanografico', _mecController.text.trim());
          await prefs.setString('Token', token);
          await prefs.setString('Empresa', _selectedEmpresa!);
          await prefs.setString('Subempresa', _selectedSubempresa!);

          await _obterDadosAdicionais(prefs);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registo efetuado com sucesso!'),
                backgroundColor: Color(0xFF00b33e),
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        } else {
          _showError('Registo falhado. Verifique os dados.');
        }
      } else {
        _showError('Erro no servidor');
      }
    } catch (e) {
      _showError('Erro de ligação: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _obterDadosAdicionais(SharedPreferences prefs) async {
    try {
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final connection = prefs.getString('Connection') ?? '';

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/GetInfoQRCODE'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientQrCode': _mecController.text.trim(),
          'Companyid': 1,
          'Connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);

        if (d['Status'] == 'true' && d['Info'] != null && d['Info'].length > 0) {
          final info = d['Info'][0];
          await prefs.setInt('LineID', info['LineID'] ?? 0);
          await prefs.setString('LineName', info['LineName'] ?? '');
          await prefs.setInt('StopID', info['StopID'] ?? 0);
          await prefs.setString('StopName', info['StopName'] ?? '');
          await prefs.setString('Turno', info['Turno'] ?? '');
          await prefs.setInt('ClientID', info['ClientID'] ?? 0);
          await prefs.setString('Latitude', info['ClientLat']?.toString() ?? '');
          await prefs.setString('Longitude', info['ClientLong']?.toString() ?? '');
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter dados adicionais: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _mecController.dispose();
    super.dispose();
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFf4f8ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFd0e4ff)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => _validateFields(),
        style: const TextStyle(color: Color(0xFF00399e)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00399e),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFf4f8ff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFd0e4ff)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: const TextStyle(color: Color(0xFF00399e), fontSize: 14),
                    items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Card principal
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Criar conta',
                            style: TextStyle(color: Color(0xFF00399e), fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Preencha os seus dados para se registar',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 20),

                        // Email
                        const Text('EMAIL:', style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _buildInput(controller: _emailController, hint: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),

                        // Empresa
                        _buildDropdown(
                          label: 'EMPRESA',
                          items: _empresas,
                          value: _selectedEmpresa,
                          icon: Icons.business_outlined,
                          onChanged: (v) {
                            setState(() => _selectedEmpresa = v);
                            if (v != null) _carregarSubempresas(v);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Subempresa
                        _buildDropdown(
                          label: 'SUBEMPRESA',
                          items: _subempresas,
                          value: _selectedSubempresa,
                          icon: Icons.business_center_outlined,
                          onChanged: (v) => setState(() => _selectedSubempresa = v),
                        ),
                        const SizedBox(height: 16),

                        // Número mecanográfico
                        const Text('NÚMERO MECANOGRÁFICO', style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _buildInput(controller: _mecController, hint: 'Nº Mecanográfico', icon: Icons.badge_outlined, keyboardType: TextInputType.number),
                        const SizedBox(height: 20),

                        // Checkbox Privacidade
                        Row(
                          children: [
                            Checkbox(
                              value: _privacyChecked,
                              activeColor: const Color(0xFF00399e),
                              onChanged: (v) {
                                setState(() => _privacyChecked = v ?? false);
                                _validateFields();
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _openPrivacyPolicy,
                                child: const Text(
                                  'Eu li e aceito a Política de Privacidade',
                                  style: TextStyle(
                                    color: Color(0xFF00399e),
                                    decoration: TextDecoration.underline,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Checkbox Termos
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _termsChecked,
                              activeColor: const Color(0xFF00399e),
                              onChanged: (v) {
                                setState(() => _termsChecked = v ?? false);
                                _validateFields();
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: _showTermsDialog,
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Eu li, compreendi e aceito os ',
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                      children: [
                                        TextSpan(
                                          text: 'termos e condições',
                                          style: TextStyle(
                                            color: Color(0xFF00399e),
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: ' da APP'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Botão Registar
                        if (_showRegisterButton)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00399e),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : const Text('REGISTAR',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }
}
