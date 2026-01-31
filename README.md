# SMS Gateway System

SMS Gateway is an automated SMS sending system that uses an Android device to send SMS messages via a RESTful API. The system consists of a PHP backend API connected to PostgreSQL and a Flutter Android application that runs as a background service.

## Project Structure

### web/ - Backend API (PHP)

PHP-based REST API for managing SMS requests and device authentication.

**Files:**
- `config.php` - PostgreSQL database configuration
- `database.sql` - Database schema (devices, sms_requests tables)
- `api.php` - REST API endpoints

**Technology Stack:**
- PHP 8.0+
- PostgreSQL 12+
- PDO for database connections

### app/ - Android Application (Flutter)

Flutter-based Android application that runs as a foreground service to poll the API and send SMS messages.

**Key Features:**
- Background service with 15-second polling interval
- Foreground notification showing sent/pending count
- API key authentication
- Automatic device registration
- SMS sending via telephony package

**Technology Stack:**
- Flutter 3.0+
- Dart
- flutter_background_service
- telephony package

## Installation

### Prerequisites

**For Web API:**
- PHP 8.0 or higher
- PostgreSQL 12 or higher
- PDO PostgreSQL extension enabled

**For Android App:**
- Flutter SDK 3.0+
- Android SDK (API 23+)
- Java 17+

### Backend Setup

**1. Database Configuration**

Create PostgreSQL database and user:
```bash
psql -U postgres
CREATE DATABASE smspush;
```

**2. Import Database Schema**

```bash
PGPASSWORD='your_password' psql -h your_host -p 5432 -U postgres -d smspush -f web/database.sql
```

**3. Configure Database Connection**

Edit `web/config.php`:
```php
define('DB_HOST', 'your_host');
define('DB_PORT', '5432');
define('DB_NAME', 'smspush');
define('DB_USER', 'postgres');
define('DB_PASS', 'your_password');
```

**4. Deploy API**

Upload `web/` directory contents to your web server or test locally:
```bash
cd web
php -S 0.0.0.0:8000
```

API will be available at: `http://your-server/api.php`

### Android Application Setup

**1. Install Dependencies**

```bash
cd app
flutter pub get
```

**2. Build Release APK**

```bash
flutter build apk --release
```

Output location: `app/build/app/outputs/flutter-apk/app-release.apk`

**3. Install on Android Device**

- Transfer APK to Android device
- Enable "Install from Unknown Sources"
- Install APK
- Grant SMS and notification permissions

**4. Configure Application**

- Open application
- Enter API URL (e.g., `https://your-domain.com/sms/api.php`)
- Device will auto-register and receive API key
- Start background service

## API Documentation

### Base URL
```
https://your-domain.com/sms/api.php
```

### Endpoints

#### 1. Register Device

Register a new device and obtain API key.

**Request:**
```http
POST /api.php?request=register-device
Content-Type: application/json

{
  "device_id": "unique_device_identifier",
  "device_name": "Device Name",
  "phone_number": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Cihaz kaydedildi",
  "api_key": "generated_64_char_api_key"
}
```

#### 2. Get Pending Messages

Retrieve pending SMS messages for authenticated device.

**Request:**
```http
GET /api.php?request=pending
X-API-Key: your_api_key
```

**Response:**
```json
{
  "success": true,
  "count": 2,
  "messages": [
    {
      "id": 1,
      "phone_number": "+1234567890",
      "message": "Test message",
      "priority": 5,
      "scheduled_at": null
    }
  ]
}
```

#### 3. Update SMS Status

Update the status of a sent SMS.

**Request:**
```http
POST /api.php?request=update-status
X-API-Key: your_api_key
Content-Type: application/json

{
  "request_id": 1,
  "status": "sent",
  "error_message": null
}
```

**Status values:** `pending`, `sent`, `failed`, `delivered`

**Response:**
```json
{
  "success": true,
  "message": "Durum güncellendi"
}
```

#### 4. Queue SMS for Sending

Add a new SMS to the queue for a specific device.

**Request:**
```http
POST /api.php?request=send-sms
Content-Type: application/json

{
  "device_id": "unique_device_identifier",
  "phone_number": "+1234567890",
  "message": "Your message here",
  "priority": 5
}
```

**Priority:** 1-10 (10 = highest priority)

**Response:**
```json
{
  "success": true,
  "message": "SMS kuyruğa eklendi",
  "request_id": 1
}
```

## Database Schema

### devices Table

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| device_id | VARCHAR(255) | Unique device identifier |
| device_name | VARCHAR(255) | Device display name |
| phone_number | VARCHAR(20) | Device phone number |
| api_key | VARCHAR(255) | Authentication key |
| is_active | BOOLEAN | Device active status |
| last_seen | TIMESTAMP | Last API request time |
| created_at | TIMESTAMP | Registration time |
| updated_at | TIMESTAMP | Last update time |

### sms_requests Table

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| device_id | VARCHAR(255) | Foreign key to devices |
| phone_number | VARCHAR(20) | Recipient number |
| message | TEXT | SMS content |
| status | VARCHAR(20) | pending/sent/failed/delivered |
| priority | SMALLINT | Priority (1-10) |
| scheduled_at | TIMESTAMP | Scheduled send time |
| sent_at | TIMESTAMP | Actual send time |
| delivered_at | TIMESTAMP | Delivery confirmation time |
| error_message | TEXT | Error details if failed |
| created_at | TIMESTAMP | Request creation time |
| updated_at | TIMESTAMP | Last update time |

## Usage Example

**1. Register your Android device:**

Run the app on your device and it will auto-register.

**2. Send SMS via API:**

```bash
curl -X POST "https://your-domain.com/sms/api.php?request=send-sms" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "your_device_id",
    "phone_number": "+1234567890",
    "message": "Test message from SMS Gateway",
    "priority": 8
  }'
```

**3. Monitor:**

The Android app polls every 15 seconds, detects the message, and sends it automatically.

## Configuration

### Background Service Settings

Edit `app/lib/services/sms_service.dart` to adjust:

- Polling interval: Default 15 seconds
- Request timeout: 10 seconds for API calls
- Batch size: Maximum 10 messages per request

### API Rate Limiting

No rate limiting is implemented by default. Add middleware if needed for production use.

## Security Considerations

- API keys are 64-character hexadecimal strings
- Use HTTPS in production
- API key is stored securely in SharedPreferences on Android
- Database uses prepared statements to prevent SQL injection
- CORS is enabled by default (restrict in production)

## Troubleshooting

**App crashes on start:**
- Ensure all permissions are granted (SMS, Phone, Notifications)
- Check API URL is correct and accessible
- Verify background service permissions in Android settings

**SMS not sending:**
- Check device has SMS permissions
- Verify API key is valid
- Ensure device_id matches registered device
- Check network connectivity

**API returns 401 Unauthorized:**
- Verify X-API-Key header is sent
- Check API key exists in database
- Ensure device is active (is_active = true)

## License

This project is provided as-is for educational and commercial purposes.

## Support

For issues and questions, please check the database logs and API error responses.
- Otomatik olarak çalışmaya başlar

## 📱 Uygulama Kullanımı

1. Uygulamayı açın
2. API URL'nizi girin (örn: `https://sunucu.com/api.php`)
3. "Bağlan ve Başlat" butonuna basın
4. Uygulama otomatik olarak arka planda çalışmaya başlar
5. API'den gelen SMS istekleri otomatik gönderilir

## 🔌 API Kullanımı

### SMS Gönder

```bash
curl -X POST http://sunucu.com/api.php?request=send-sms \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "cihaz-id",
    "phone_number": "+905551234567",
    "message": "Test mesajı",
    "priority": 5
  }'
```

### Cihaz Listesi

```sql
SELECT * FROM devices WHERE is_active = true;
```

### SMS Durumu Sorgula

```sql
SELECT * FROM sms_requests WHERE status = 'pending';
```

## 🗄️ Veritabanı

**Bağlantı Bilgileri:**
```
Host: 31.57.154.24
Port: 5432
Database: smspush
User: postgres
Password: 15625533+a
```

**Tablolar:**
- `devices` - Kayıtlı cihazlar
- `sms_requests` - SMS istekleri ve durumları

## ✨ Özellikler

### Web API
✅ PostgreSQL desteği  
✅ RESTful API  
✅ Otomatik cihaz kaydı  
✅ API key güvenliği  
✅ SMS kuyruğu sistemi  
✅ Öncelik bazlı gönderim  
✅ Durum takibi  

### Android App
✅ Basit kurulum (sadece API URL)  
✅ Otomatik başlatma  
✅ Arka plan çalışma  
✅ Gerçek zamanlı durum gösterimi  
✅ Öncelik sistemi  
✅ Hata yönetimi  
✅ SMS izinleri  

## 📊 API Endpoints

| Endpoint | Method | Açıklama |
|----------|--------|----------|
| `/api.php?request=register-device` | POST | Cihaz kaydı |
| `/api.php?request=pending` | GET | Bekleyen SMS'leri al |
| `/api.php?request=update-status` | POST | SMS durumu güncelle |
| `/api.php?request=send-sms` | POST | SMS kuyruğa ekle |

Detaylı API dokümantasyonu: [web/README.md](web/README.md)

## 🔐 Güvenlik

⚠️ **Önemli Notlar:**
- API anahtarlarını güvenli saklayın
- Üretim ortamında HTTPS kullanın
- Veritabanı şifrelerini değiştirin
- API'yi firewall ile koruyun
- CORS ayarlarını kısıtlayın

## 💡 Kullanım Senaryosu

1. Web sunucusuna PHP API'yi kurun
2. PostgreSQL veritabanını oluşturun
3. Android telefona APK'yi yükleyin
4. Telefonda uygulamayı açıp API URL'ini girin
5. Uygulama otomatik çalışmaya başlar
6. Web uygulamanızdan API'ye SMS isteği gönderin
7. Android telefon otomatik olarak SMS'i gönderir

## 📋 Gereksinimler

### Web
- PHP 7.4+
- PostgreSQL 12+
- PDO PostgreSQL extension

### App
- Flutter 3.0+
- Android SDK
- Minimum Android 6.0 (API 23)
- SMS izni
- Telefon durumu okuma izni

## 🆘 Sorun Giderme

**Uygulama SMS gönderemiyor:**
- SMS izinlerini kontrol edin
- Arka plan kısıtlamalarını kapatın
- Pil optimizasyonunu devre dışı bırakın

**API bağlanamıyor:**
- URL'nin doğru olduğundan emin olun
- Sunucu erişilebilir olmalı
- CORS ayarlarını kontrol edin

**Veritabanı bağlantı hatası:**
- PostgreSQL servisinin çalıştığından emin olun
- Bağlantı bilgilerini kontrol edin
- Firewall ayarlarını kontrol edin

## 📝 Lisans

Bu proje özel kullanım içindir.

