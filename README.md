# SMS Gateway Sistemi

SMS Gateway, Android cihazlar üzerinden REST API aracılığıyla otomatik SMS gönderimi sağlayan bir sistemdir. Sistem, MySQL veritabanına bağlı PHP tabanlı bir backend API ve arkaplanda çalışan Flutter Android uygulamasından oluşur.

## Sistem Bileşenleri

### Backend (web/)

PHP ile yazılmış REST API sunucusu. SMS isteklerini yönetir ve cihaz doğrulama işlemlerini gerçekleştirir.

**Dosyalar:**
- `api.php` - REST API endpoint'leri
- `database.sql` - Veritabanı şeması
- `config.php` - MySQL bağlantı ayarları (örnek dosya)

**Gereksinimler:**
- PHP 8.0 veya üzeri
- MySQL 5.7 veya üzeri
- PDO MySQL eklentisi

### Android Uygulaması (app/)

Flutter ile geliştirilmiş Android uygulaması. Arkaplan servisi olarak çalışır, düzenli aralıklarla API'yi kontrol eder ve bekleyen SMS'leri gönderir.

**Özellikler:**
- 15 saniyede bir API kontrolü
- Otomatik cihaz kaydı
- API anahtarı ile kimlik doğrulama
- Ön plan bildirimi (foreground service)
- Otomatik SMS gönderimi

**Gereksinimler:**
- Flutter SDK 3.0+
- Android SDK (API 23+)
- Java 17+

## Kurulum

### Backend Kurulumu

**1. Veritabanı Oluşturma**

MySQL'de yeni veritabanı ve kullanıcı oluşturun:

```bash
mysql -u root -p
CREATE DATABASE smsgateway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'smsgateway'@'localhost' IDENTIFIED BY 'zxc123123+a';
GRANT ALL PRIVILEGES ON smsgateway.* TO 'smsgateway'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**2. Veritabanı Şemasını Yükleme**

```bash
mysql -u smsgateway -p smsgateway < web/database.sql
```

**3. API Yapılandırması**

`web/config.php` dosyasını düzenleyin:

```php
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'smsgateway');
define('DB_USER', 'smsgateway');
define('DB_PASS', 'pass');
```

**4. API'yi Sunucuya Yükleme**

`web/` klasörünün içeriğini web sunucunuza yükleyin. Yerel test için:

```bash
cd web
php -S 0.0.0.0:8000
```

API adresi: `http://sunucu-adresi/api.php`

### Android Uygulaması Kurulumu

**1. Bağımlılıkları Yükleme**

```bash
cd app
flutter pub get
```

**2. APK Oluşturma**

```bash
flutter build apk --release
```

APK dosyası: `app/build/app/outputs/flutter-apk/app-release.apk`

**3. Android Cihaza Yükleme**

- APK dosyasını Android cihaza aktarın
- Bilinmeyen kaynaklardan yüklemeye izin verin
- APK'yı yükleyin
- SMS ve bildirim izinlerini verin

**4. Uygulamayı Yapılandırma**

- Uygulamayı açın
- API URL'sini girin (örnek: `https://sunucu.com/sms/api.php`)
- Cihaz otomatik olarak kaydedilir ve API anahtarı alır
- Servis otomatik başlar

## API Kullanımı

### Temel URL

```
https://sunucu.com/sms/api.php
```

### Endpoint'ler

#### 1. Cihaz Kaydı

Yeni bir cihaz kaydeder ve API anahtarı oluşturur.

**İstek:**
```http
POST /api.php?request=register-device
Content-Type: application/json

{
  "device_id": "benzersiz_cihaz_kimlik",
  "device_name": "Cihaz Adı",
  "phone_number": "+905551234567"
}
```

**Yanıt:**
```json
{
  "success": true,
  "message": "Cihaz kaydedildi",
  "api_key": "64_karakterlik_api_anahtari"
}
```

#### 2. Bekleyen Mesajları Getirme

Cihaz için bekleyen SMS'leri getirir.

**İstek:**
```http
GET /api.php?request=pending
X-API-Key: api_anahtariniz
```

**Yanıt:**
```json
{
  "success": true,
  "count": 1,
  "messages": [
    {
      "id": 1,
      "phone_number": "+905551234567",
      "message": "Test mesajı",
      "priority": 5,
      "scheduled_at": null
    }
  ]
}
```

#### 3. SMS Durumu Güncelleme

Gönderilen SMS'in durumunu günceller.

**İstek:**
```http
POST /api.php?request=update-status
X-API-Key: api_anahtariniz
Content-Type: application/json

{
  "request_id": 1,
  "status": "sent",
  "error_message": null
}
```

**Durum değerleri:** `pending`, `sent`, `failed`, `delivered`

**Yanıt:**
```json
{
  "success": true,
  "message": "Durum güncellendi"
}
```

#### 4. SMS Gönderme Talebi

Belirli bir cihaz için SMS kuyruğuna mesaj ekler.

**İstek:**
```http
POST /api.php?request=send-sms
Content-Type: application/json

{
  "device_id": "cihaz_kimlik",
  "phone_number": "+905551234567",
  "message": "Gönderilecek mesaj",
  "priority": 5
}
```

**Öncelik:** 1-10 arası (10 en yüksek)

**Yanıt:**
```json
{
  "success": true,
  "message": "SMS kuyruğa eklendi",
  "request_id": 1
}
```

## Veritabanı Yapısı

### devices Tablosu

Kayıtlı cihaz bilgilerini saklar.

| Sütun | Tip | Açıklama |
|-------|-----|----------|
| id | INT AUTO_INCREMENT | Birincil anahtar |
| device_id | VARCHAR(255) | Benzersiz cihaz kimliği |
| device_name | VARCHAR(255) | Cihaz adı |
| phone_number | VARCHAR(20) | Cihaz telefon numarası |
| api_key | VARCHAR(255) | Kimlik doğrulama anahtarı |
| is_active | TINYINT(1) | Cihaz aktif durumu |
| last_seen | TIMESTAMP | Son API isteği zamanı |
| created_at | TIMESTAMP | Kayıt zamanı |
| updated_at | TIMESTAMP | Son güncelleme zamanı |

### sms_requests Tablosu

SMS gönderim isteklerini saklar.

| Sütun | Tip | Açıklama |
|-------|-----|----------|
| id | INT AUTO_INCREMENT | Birincil anahtar |
| device_id | VARCHAR(255) | Cihaz kimliği (foreign key) |
| phone_number | VARCHAR(20) | Alıcı telefon numarası |
| message | TEXT | SMS içeriği |
| status | VARCHAR(20) | Durum (pending/sent/failed/delivered) |
| priority | SMALLINT | Öncelik (1-10) |
| scheduled_at | TIMESTAMP | Planlanan gönderim zamanı |
| sent_at | TIMESTAMP | Gerçek gönderim zamanı |
| delivered_at | TIMESTAMP | Teslim edilme zamanı |
| error_message | TEXT | Hata mesajı (varsa) |
| created_at | TIMESTAMP | Oluşturulma zamanı |
| updated_at | TIMESTAMP | Son güncelleme zamanı |

## Kullanım Örneği

**1. Android cihazınızı kaydedin**

Uygulamayı açın, API URL'sini girin. Cihaz otomatik kaydedilir.

**2. API üzerinden SMS gönderin**

```bash
curl -X POST "https://sunucu.com/sms/api.php?request=send-sms" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "cihaz_kimliginiz",
    "phone_number": "+905551234567",
    "message": "Test mesajı",
    "priority": 8
  }'
```

**3. SMS otomatik gönderilir**

Uygulama 15 saniyede bir kontrol eder, mesajı algılar ve otomatik gönderir.

## Yapılandırma

### Servis Ayarları

`app/lib/services/sms_service.dart` dosyasında:

- Kontrol aralığı: Varsayılan 15 saniye
- İstek zaman aşımı: 10 saniye
- Toplu mesaj limiti: Her istekte maksimum 10 mesaj

### Güvenlik Ayarları

- API anahtarları 64 karakterlik hexadecimal dizelerdir
- Üretim ortamında HTTPS kullanılmalıdır
- Veritabanı sorguları prepared statement ile korunur
- CORS varsayılan olarak açıktır (üretimde kısıtlanmalıdır)

## Sorun Giderme

**Uygulama çöküyor:**
- Tüm izinlerin verildiğinden emin olun (SMS, Telefon, Bildirimler)
- API URL'sinin doğru ve erişilebilir olduğunu kontrol edin
- Arkaplan servis izinlerini kontrol edin

**SMS gönderilmiyor:**
- Cihazın SMS izni olduğunu kontrol edin
- API anahtarının geçerli olduğunu doğrulayın
- device_id'nin kayıtlı cihazla eşleştiğini kontrol edin
- İnternet bağlantısını kontrol edin

**API 401 hatası veriyor:**
- X-API-Key header'ının gönderildiğini kontrol edin
- API anahtarının veritabanında olduğunu doğrulayın
- Cihazın aktif olduğundan emin olun (is_active = true)

## Yasal Uyarı ve Sorumluluk Reddi

Bu yazılım, SMS gönderim altyapısı oluşturmak amacıyla geliştirilmiş açık kaynaklı bir projedir. Yazılımın kullanımından doğacak her türlü sorumluluk kullanıcıya aittir.

**Önemli Hususlar:**

1. Bu yazılım "OLDUĞU GİBİ" sunulmaktadır. Yazılımın kullanımından kaynaklanan hiçbir doğrudan veya dolaylı zarar için geliştirici sorumluluk kabul etmez.

2. Yazılımı kullanarak, bulunduğunuz ülkenin telekomünikasyon ve veri koruma yasalarına uymayı kabul etmiş sayılırsınız.

3. Toplu SMS gönderimi, spam, izinsiz pazarlama veya yasadışı faaliyetler için kullanılması kesinlikle yasaktır.

4. Yazılım, yalnızca meşru ve yasal amaçlar için kullanılmalıdır. İzinsiz SMS gönderimi, kişisel verilerin korunması kanunlarının ihlali ve benzeri yasadışı faaliyetlerden kullanıcı sorumludur.

5. Ticari kullanım için ilgili telekomünikasyon otoritelerinden gerekli izinlerin alınması kullanıcının sorumluluğundadır.

6. Yazılımın kullanımı sonucu oluşabilecek hukuki, mali veya cezai sorumluluklar tamamen kullanıcıya aittir.

7. Geliştirici, yazılımın kesintisiz çalışacağını, hatasız olduğunu veya belirli bir amaca uygun olduğunu garanti etmez.

**Yazılımı kullanarak bu şartları kabul etmiş sayılırsınız. Eğer bu şartları kabul etmiyorsanız, yazılımı kullanmayınız.**

## Lisans

Bu proje eğitim ve araştırma amaçlı olarak paylaşılmıştır. Kullanım sorumluluğu tamamen kullanıcıya aittir.
