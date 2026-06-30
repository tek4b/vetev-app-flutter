import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  String _qrCodeUrl = '';
  String _mensagem = 'Sem novas mensagens';
  bool _showConfirmButton = false;
  List<int> _mensagensPendentesIds = [];
  String _dayText = '';
  String _timeText = '';

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    final now = DateTime.now();
    _dayText = 'Dia: ${DateFormat('dd/MM/yyyy').format(now)}';
    _timeText = DateFormat('HH:mm').format(now);

    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final mec = prefs.getString('NumeroMecanografico') ?? '';
    final idEmpresa = prefs.getInt('idEmpresa') ?? -1;
    final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
    final clientID = prefs.getInt('ClientID') ?? 0;

    setState(() {
      _qrCodeUrl = '${baseUrl}QrCodes/$idEmpresa/QRCode_$mec.png';
    });

    debugPrint('QR CODE URL: $_qrCodeUrl');

    await _carregarMensagens(prefs, clientID);
  }

  Future<void> _carregarMensagens(SharedPreferences prefs, int clientID) async {
    try {
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final connection = prefs.getString('Connection') ?? '';
      final year = DateTime.now().year;
      final yearToken = '$year-MBMobile';

      final response = await http.post(
        Uri.parse('${endpoint}CheckNotificationClient'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'token': yearToken,
          'ClientID': clientID,
          'companyID': 1,
          'connection': connection,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final d = jsonDecode(data['d']);
        final notifications = d['Notifications'] as List? ?? [];

        if (notifications.isEmpty) {
          if (mounted) {
            setState(() {
              _mensagem = 'Sem novas mensagens';
              _showConfirmButton = false;
            });
          }
        } else {
          _mensagensPendentesIds = notifications.map((n) => n['Id'] as int).toList();
          final msgs = notifications
              .map((n) => '• ${n['Subject']} - ${n['Message']}')
              .join('\n\n');
          if (mounted) {
            setState(() {
              _mensagem = msgs;
              _showConfirmButton = true;
            });
          }
        }
      } else {
        if (mounted) setState(() => _mensagem = 'Erro no servidor');
      }
    } catch (e) {
      debugPrint('ERRO MENSAGENS: $e');
      if (mounted) setState(() => _mensagem = 'Erro de ligação');
    }
  }

  Future<void> _confirmarLeitura() async {
    setState(() {
      _mensagem = 'Sem mensagens de momento';
      _showConfirmButton = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? 'http://vetevb4w.pt/';
      final endpoint = prefs.getString('selected_endpoint') ??
          '${baseUrl}Services/RemoteMotoristLogin.asmx/';
      final connection = prefs.getString('Connection') ?? '';
      final clientID = prefs.getInt('ClientID') ?? 0;
      final year = DateTime.now().year;
      final yearToken = '$year-MBMobile';

      for (final id in _mensagensPendentesIds) {
        await http.post(
          Uri.parse('${endpoint}CheckReadNotificationClient'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'token': yearToken,
            'ClientID': clientID,
            'companyID': 1,
            'messageID': id,
            'connection': connection,
          }),
        );
      }
    } catch (e) {
      debugPrint('Erro ao confirmar leitura: $e');
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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

                const SizedBox(height: 4),

                const Text(
                  'vetev',
                  style: TextStyle(
                    color: Color(0xFF00399e),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 12),

                // Card QR Code
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'O SEU QR Code',
                        style: TextStyle(color: Color(0xFF00399e), fontSize: 13),
                      ),
                      Text(
                        _dayText,
                        style: const TextStyle(
                          color: Color(0xFF00399e),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _timeText,
                        style: const TextStyle(color: Color(0xFF5599dd), fontSize: 12),
                      ),
                      const SizedBox(height: 8),

                      // QR Code com cantos de scanner
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          children: [
                            // QR Code image
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _qrCodeUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _qrCodeUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF00399e),
                                          ),
                                        ),
                                        errorWidget: (_, url, error) {
                                          debugPrint('QR ERROR: $error for $url');
                                          return const Icon(
                                            Icons.qr_code,
                                            size: 120,
                                            color: Colors.grey,
                                          );
                                        },
                                      )
                                    : const Icon(Icons.qr_code, size: 120, color: Colors.grey),
                              ),
                            ),

                            // Cantos verdes de scanner
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _ScannerCornersPainter(),
                              ),
                            ),

                            // Bola animada
                            Positioned.fill(
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (_, child) => Transform.rotate(
                                    angle: _rotationController.value * 2 * math.pi,
                                    child: child,
                                  ),
                                  child: Image.asset(
                                    'assets/images/bola_qrcode.png',
                                    width: 48,
                                    height: 48,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Card Mensagens
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notifications_outlined, color: Color(0xFF00399e), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Mensagens',
                            style: TextStyle(
                              color: Color(0xFF00399e),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFFf0f4ff), height: 16),
                      Text(
                        _mensagem,
                        style: const TextStyle(color: Color(0xFF5A5A5A), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Botão Confirmar Leitura
                if (_showConfirmButton)
                  GestureDetector(
                    onTap: _confirmarLeitura,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00399e),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Confirmar Leitura',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Cantos verdes de scanner
class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00b33e)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const offset = 2.0;

    // Canto superior esquerdo
    canvas.drawLine(const Offset(offset, offset), const Offset(offset + cornerLength, offset), paint);
    canvas.drawLine(const Offset(offset, offset), const Offset(offset, offset + cornerLength), paint);

    // Canto superior direito
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset - cornerLength, offset), paint);
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset, offset + cornerLength), paint);

    // Canto inferior esquerdo
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset + cornerLength, size.height - offset), paint);
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset, size.height - offset - cornerLength), paint);

    // Canto inferior direito
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset - cornerLength, size.height - offset), paint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset, size.height - offset - cornerLength), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
