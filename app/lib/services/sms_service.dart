import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SmsService {
  final Telephony telephony = Telephony.instance;

  static Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    
    // Android notification channel oluştur
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sms_gateway_channel',
      'SMS Gateway Service',
      description: 'SMS gönderme servisi için notification',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'sms_gateway_channel',
        initialNotificationTitle: 'SMS Gateway',
        initialNotificationContent: 'Servis başlatılıyor...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> startService() async {
    final service = FlutterBackgroundService();
    return await service.startService();
  }

  static Future<bool> stopService() async {
    final service = FlutterBackgroundService();
    return service.isRunning().then((running) {
      if (running) {
        service.invoke('stop');
      }
      return true;
    });
  }

  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      await telephony.sendSms(
        to: phoneNumber,
        message: message,
      );
      return true;
    } catch (e) {
      print('SMS gönderme hatası: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    final permissions = await telephony.requestPhoneAndSmsPermissions;
    return permissions ?? false;
  }
}

// Arka plan servisi başlangıç fonksiyonu
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('stop').listen((event) {
      service.stopSelf();
    });
    
    service.setForegroundNotificationInfo(
      title: 'SMS Gateway',
      content: 'Servis başlatıldı...',
    );
  }

  int sentCount = 0;
  int failedCount = 0;

  // Recursive polling fonksiyonu
  Future<void> pollMessages() async {
    try {
      if (service is AndroidServiceInstance) {
        try {
          if (!await service.isForegroundService()) {
            await Future.delayed(const Duration(seconds: 15));
            pollMessages();
            return;
          }
        } catch (_) {
          await Future.delayed(const Duration(seconds: 15));
          pollMessages();
          return;
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          final apiUrl = prefs.getString('api_url');
          final apiKey = prefs.getString('api_key');

          if (apiUrl == null || apiKey == null) {
            service.setForegroundNotificationInfo(
              title: 'SMS Gateway',
              content: 'Yapılandırma bekleniyor...',
            );
            await Future.delayed(const Duration(seconds: 15));
            pollMessages();
            return;
          }

          // Bekleyen mesajları al - timeout ile
          final response = await http.get(
            Uri.parse('$apiUrl?request=pending'),
            headers: {'X-API-Key': apiKey},
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return http.Response('{"error":"timeout"}', 408);
            },
          );

          if (response.statusCode == 200) {
            try {
              final data = json.decode(response.body);
              
              // API hatası kontrolü
              if (data['error'] != null) {
                service.setForegroundNotificationInfo(
                  title: 'SMS Gateway',
                  content: 'API Hatası: ${data['error']}',
                );
                await Future.delayed(const Duration(seconds: 15));
                pollMessages();
                return;
              }

              final messages = data['messages'] as List? ?? [];

              service.setForegroundNotificationInfo(
                title: 'SMS Gateway Aktif',
                content: 'Gönderilen: $sentCount | Bekleyen: ${messages.length}',
              );

              // Mesajları gönder
              for (var msg in messages) {
                try {
                  final telephony = Telephony.instance;
                  
                  await telephony.sendSms(
                    to: msg['phone_number'],
                    message: msg['message'],
                  );

                  // Durumu güncelle
                  try {
                    await http.post(
                      Uri.parse('$apiUrl?request=update-status'),
                      headers: {
                        'X-API-Key': apiKey,
                        'Content-Type': 'application/json',
                      },
                      body: json.encode({
                        'request_id': msg['id'],
                        'status': 'sent',
                      }),
                    ).timeout(const Duration(seconds: 5));
                  } catch (_) {
                    // Status update hatası önemli değil
                  }

                  sentCount++;
                } catch (e) {
                  failedCount++;
                  
                  // Hata durumunu güncelle
                  try {
                    await http.post(
                      Uri.parse('$apiUrl?request=update-status'),
                      headers: {
                        'X-API-Key': apiKey,
                        'Content-Type': 'application/json',
                      },
                      body: json.encode({
                        'request_id': msg['id'],
                        'status': 'failed',
                        'error_message': e.toString(),
                      }),
                    ).timeout(const Duration(seconds: 5));
                  } catch (_) {
                    // Hata güncelleme başarısız olsa bile devam et
                  }
                }

                // Mesajlar arası bekleme
                await Future.delayed(const Duration(milliseconds: 2000));
              }
            } catch (e) {
              // JSON parse hatası
              service.setForegroundNotificationInfo(
                title: 'SMS Gateway',
                content: 'Veri hatası - devam ediyor...',
              );
            }
          } else {
            service.setForegroundNotificationInfo(
              title: 'SMS Gateway',
              content: 'API yanıt: ${response.statusCode}',
            );
          }
        } catch (e) {
          // Network veya diğer hatalar
          service.setForegroundNotificationInfo(
            title: 'SMS Gateway',
            content: 'Bekleniyor... (${sentCount} gönderildi)',
          );
        }
      }
    } catch (e) {
      // En üst seviye hata yakalama - hiçbir şey servis'i çökertmemeli
      if (service is AndroidServiceInstance) {
        try {
          service.setForegroundNotificationInfo(
            title: 'SMS Gateway',
            content: 'Aktif (${sentCount} SMS)',
          );
        } catch (_) {
          // Notification update bile başarısız olsa devam et
        }
      }
    }
    
    // 15 saniye bekle ve tekrar kontrol et
    await Future.delayed(const Duration(seconds: 15));
    pollMessages();
  }
  
  // İlk polling'i başlat
  pollMessages();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}