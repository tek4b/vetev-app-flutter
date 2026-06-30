import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_helper.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mecController = TextEditingController();
  bool _isLoading = false;
  String _loadingMessage = 'A sincronizar...';

  static const String _demoUser = 'demo001';
  static const String _demoToken = 'LyxTTSyugjb7RG+BR1gyfjhLuwJb42j6IL6KsRnpfjcBTtfWKBWBaFdPC+/rTOr7';

  Future<void> _login() async {
    final mec = _mecController.text.trim();
    if (mec.isEmpty) {
      _showError('Introduza o número mecanográfico');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'A validar...';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      String token = prefs.getString('Token') ?? '';
      String connection = prefs.getString('Connection') ?? '';

      // Utilizador demo
      if (mec.toLowerCase() == _demoUser) {
        token = _demoToken;
        await prefs.setString('Email', 'bruno.ferreira.tadim@gmail.com');
        await prefs.setString('NumeroMecanografico', mec);
        await prefs.setString('Token', token);
        await prefs.setString('Empresa', 'HEINEKEN');
        await prefs.setString('Subempresa', 'VETEV');
        await prefs.setString('Connection', 'connectionhnk');
        connection = 'connectionhnk';
      }

      if (token.isEmpty) {
        _showError('Token não configurado. Registe-se primeiro.');
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/ValidateLogin'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'MecanographicNumber': mec,
          'Token': token,
          'Connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final type = d['Type'];

        if (type == 0) {
          await prefs.setString('NumeroMecanografico', mec);
          if (d['ClientID'] != null) {
            await prefs.setInt('ClientID', d['ClientID']);
          }

          // Sincroniza a BD
          await _sincronizarBD(prefs, baseUrl, connection);

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        } else {
          _showError('Login inválido. Verifique os seus dados.');
          setState(() => _isLoading = false);
        }
      } else {
        _showError('Erro no servidor: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('ERRO LOGIN: $e');
      _showError('Erro de ligação: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sincronizarBD(SharedPreferences prefs, String baseUrl, String connection) async {
    try {
      debugPrint('SYNC: a iniciar...');
      setState(() => _loadingMessage = 'A carregar linhas...');
      await _atualizarLinhas(prefs, baseUrl, connection);
      debugPrint('SYNC: linhas ok');

      setState(() => _loadingMessage = 'A carregar horários...');
      await _atualizarHorarios(prefs, baseUrl, connection);
      debugPrint('SYNC: horários ok');

      setState(() => _loadingMessage = 'A carregar percursos...');
      await _atualizarPercursos(prefs, baseUrl, connection);
      debugPrint('SYNC: percursos ok');

      setState(() => _loadingMessage = 'Concluído!');
      debugPrint('SYNC: concluído!');
    } catch (e) {
      debugPrint('SYNC ERRO: $e');
    }
  }

  Future<void> _atualizarLinhas(SharedPreferences prefs, String baseUrl, String connection) async {
    try {
      debugPrint('LINHAS: a chamar ${baseUrl}Services/RemoteMotoristLogin.asmx/GetListLines');
      debugPrint('LINHAS: connection=$connection');
      final year = DateTime.now().year;

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/GetListLines'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'connection': connection,
        }),
      );

      debugPrint('LINHAS STATUS: ${response.statusCode}');
      debugPrint('LINHAS BODY: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);

        if (d['Status'] == 'true' || d['Status'] == true) {
          final lines = d['BusLines'] as List;
          final linhasToInsert = lines.map((l) => {
            'IDPlataforma': l['LineID'],
            'nomeabrev': l['DescriptionShort'] ?? '',
            'nome': l['Description'] ?? '',
          }).toList();

          await DatabaseHelper.clearAndInsertLinhas(linhasToInsert);
          debugPrint('Linhas sincronizadas: ${linhasToInsert.length}');
        }
      }
    } catch (e) {
      debugPrint('ERRO linhas: $e');
    }
  }

  Future<void> _atualizarHorarios(SharedPreferences prefs, String baseUrl, String connection) async {
    try {
      final year = DateTime.now().year;

      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/GetListSchedules'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);

        if (d['Status'] == 'true' || d['Status'] == true) {
          final schedules = d['BusSchedule'] as List;
          final schedulesToInsert = schedules.map((s) => {
            'ID': s['ID'],
            'LineID': s['LineID'],
            'Schedule': s['Schedule'],
            'Destino': s['Destino'] ?? '',
            'Monday': (s['Monday'] == true || s['Monday'] == 1) ? 1 : 0,
            'Tuesday': (s['Tuesday'] == true || s['Tuesday'] == 1) ? 1 : 0,
            'Wednesday': (s['Wednesday'] == true || s['Wednesday'] == 1) ? 1 : 0,
            'Thursday': (s['Thursday'] == true || s['Thursday'] == 1) ? 1 : 0,
            'Friday': (s['Friday'] == true || s['Friday'] == 1) ? 1 : 0,
            'Saturday': (s['Saturday'] == true || s['Saturday'] == 1) ? 1 : 0,
            'Sunday': (s['Sunday'] == true || s['Sunday'] == 1) ? 1 : 0,
            'Holydays': (s['Holidays'] == true || s['Holidays'] == 1) ? 1 : 0,
            'Type': s['ScheduleType'] ?? s['Type'] ?? 0,
            'ShowNotifications': (s['ShowNotifications'] == true || s['ShowNotifications'] == 1) ? 1 : 0,
            'ShowLastTimes': (s['ShowLastTimes'] == true || s['ShowLastTimes'] == 1) ? 1 : 0,
          }).toList();

          await DatabaseHelper.clearAndInsertSchedules(schedulesToInsert);
          debugPrint('Horários sincronizados: ${schedulesToInsert.length}');
        }
      }
    } catch (e) {
      debugPrint('ERRO horários: $e');
    }
  }

  Future<void> _atualizarPercursos(SharedPreferences prefs, String baseUrl, String connection) async {
    try {
      final year = DateTime.now().year;
      final response = await http.post(
        Uri.parse('${baseUrl}Services/RemoteMotoristLogin.asmx/GetListCourses'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': '$year-MBMobile',
          'companyid': 1,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);

        if (d['Status'] == 'true' || d['Status'] == true) {
          final courses = d['BusCourses'] as List;
          final coursesToInsert = courses.map((c) => {
            'ID': c['ID'],
            'OrderStop': c['OrderStop'],
            'ScheduleID': c['ScheduleBegin'] ?? c['ScheduleID'],
            'LineID': c['LineID'],
            'Schedule': c['Schedule'] ?? '',
            'BusStop': c['DescriptionShort'] ?? c['BusStop'] ?? '',
            'CoordX': c['Latitude']?.toString() ?? '',
            'CoordY': c['Longitude']?.toString() ?? '',
            'DIRECTION': c['Direction'],
            'SourceID': c['SourceID'] ?? 0,
          }).toList();

          await DatabaseHelper.clearAndInsertCourses(coursesToInsert);
          debugPrint('Percursos sincronizados: ${coursesToInsert.length}');
        }
      }
    } catch (e) {
      debugPrint('ERRO percursos: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _mecController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/fundoqrcode.png', fit: BoxFit.cover),
          ),

          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF00399e)),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          color: Color(0xFF00399e),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset('assets/images/logo.png'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'vetev',
                    style: TextStyle(
                      color: Color(0xFF00399e),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Card de login
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bem-vindo',
                          style: TextStyle(color: Color(0xFF00399e), fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Introduza o seu número mecanográfico',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'NÚMERO MECANOGRÁFICO',
                          style: TextStyle(color: Color(0xFF00399e), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFf4f8ff),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFd0e4ff)),
                          ),
                          child: TextField(
                            controller: _mecController,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: Color(0xFF00399e)),
                            decoration: const InputDecoration(
                              hintText: 'Nº Mecanográfico',
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00399e),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'ENTRAR',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou', style: TextStyle(color: Colors.grey[500])),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Não tem conta? ', style: TextStyle(color: Colors.grey[600])),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                  );
                                },
                                child: const Text(
                                  'Registar',
                                  style: TextStyle(color: Color(0xFF00b33e), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
