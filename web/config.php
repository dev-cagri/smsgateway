<?php
// MySQL Veritabanı Konfigürasyonu
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'smsgateway');
define('DB_USER', 'smsgateway');
define('DB_PASS', 'smsgateway');

// Timezone
date_default_timezone_set('Europe/Istanbul');

// MySQL Bağlantısı
function getDBConnection() {
    try {
        $pdo = new PDO(
            "mysql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME . ";charset=utf8mb4",
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
        return $pdo;
    } catch (PDOException $e) {
        error_log("Database Connection Error: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Veritabanı bağlantı hatası']);
        exit;
    }
}
?>
