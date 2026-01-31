import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/sms_service.dart';
import '../models/sms_request.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool autoStart;
  
  const HomeScreen({super.key, this.autoStart = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ApiService _apiService;
  late SmsService _smsService;
  bool _isRunning = false;
  List<SmsRequest> _pendingMessages = [];
  String _status = 'Durdu';
  int _sentCount = 0;
  int _failedCount = 0;
  String? _apiUrl;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _apiUrl = prefs.getString('api_url')!;
    final apiKey = prefs.getString('api_key')!;

    _apiService = ApiService(_apiUrl!, apiKey: apiKey);
    _smsService = SmsService();

    setState(() {});
    
    // Otomatik başlat
    if (widget.autoStart && !_isRunning) {
      _toggleService();
    }
  }

  Future<void> _toggleService() async {
    if (_isRunning) {
      // Servisi durdur
      await SmsService.stopService();
      setState(() {
        _isRunning = false;
        _status = 'Durdu';
      });
    } else {
      try {
        // Önce servisi initialize et
        await SmsService.initializeBackgroundService();
        
        // Servisi başlat
        final started = await SmsService.startService();
        if (started) {
          setState(() {
            _isRunning = true;
            _status = 'Arka planda çalışıyor';
          });
        } else {
          setState(() {
            _status = 'Başlatılamadı';
          });
        }
      } catch (e) {
        setState(() {
          _status = 'Hata: ${e.toString()}';
        });
        debugPrint('Service start error: $e');
      }
    }
  }

  Future<void> _startPolling() async {
    while (_isRunning && mounted) {
      try {
        setState(() {
          _status = 'Mesajlar kontrol ediliyor...';
        });
        
        await _checkAndSendMessages();
        
        setState(() {
          _status = _isRunning ? 'Çalışıyor' : 'Durdu';
        });
        
        await Future.delayed(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Polling error: $e');
        setState(() {
          _status = 'Hata: ${e.toString()}';
        });
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }

  Future<void> _checkAndSendMessages() async {
    try {
      final messages = await _apiService.getPendingMessages();

      setState(() {
        _pendingMessages = messages;
      });

      for (var message in messages) {
        if (!_isRunning || !mounted) break;

        setState(() {
          _status = 'SMS gönderiliyor: ${message.phoneNumber}';
        });

        final success = await _smsService.sendSms(
          phoneNumber: message.phoneNumber,
          message: message.message,
        );

        await _apiService.updateMessageStatus(
          requestId: message.id,
          status: success ? 'sent' : 'failed',
          errorMessage: success ? null : 'SMS gönderilemedi',
        );

        if (success) {
          setState(() {
            _sentCount++;
          });
        } else {
          setState(() {
            _failedCount++;
          });
        }

        // Her SMS arasında bekleme
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      // Mesajları listeden temizle
      if (mounted) {
        setState(() {
          _pendingMessages.clear();
        });
      }
    } catch (e) {
      debugPrint('Check messages error: $e');
      if (mounted) {
        setState(() {
          _status = 'API bağlantı hatası';
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('API bağlantısını kesmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRunning = false;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('SMS Gateway'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Bağlantıyı Kes',
          ),
        ],
      ),
      body: Column(
        children: [
          // Durum Kartı
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRunning 
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.grey.shade400, Colors.grey.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_isRunning ? Colors.green : Colors.grey).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isRunning ? Icons.check_circle : Icons.pause_circle,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _status,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRunning ? 'Servis aktif' : 'Servis kapalı',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        'Gönderilen',
                        _sentCount.toString(),
                        Icons.send,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        'Başarısız',
                        _failedCount.toString(),
                        Icons.error_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        'Bekleyen',
                        _pendingMessages.length.toString(),
                        Icons.schedule,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Kontrol Butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isRunning ? 'Servisi Durdur' : 'Servisi Başlat',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Mesaj Listesi
          Expanded(
            child: _pendingMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.all_inbox,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Bekleyen mesaj yok',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_apiUrl != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'API: $_apiUrl',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _pendingMessages.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final message = _pendingMessages[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: const Icon(
                              Icons.sms,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            message.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              message.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(message.priority),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'P${message.priority}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _isRunning
          ? FloatingActionButton(
              onPressed: _checkAndSendMessages,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }
}
