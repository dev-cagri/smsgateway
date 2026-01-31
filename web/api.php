<?php
require_once 'config.php';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key');

// OPTIONS request için
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// API İstek Metodunu Al
$method = $_SERVER['REQUEST_METHOD'];
$request = isset($_GET['request']) ? $_GET['request'] : '';

// API Key Kontrolü
function checkApiKey() {
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    $apiKey = $headers['x-api-key'] ?? '';
    
    if (empty($apiKey)) {
        return ['error' => 'API Key gerekli', 'code' => 401];
    }
    
    $db = getDBConnection();
    $stmt = $db->prepare("SELECT device_id, is_active FROM devices WHERE api_key = ?");
    $stmt->execute([$apiKey]);
    $device = $stmt->fetch();
    
    if (!$device) {
        return ['error' => 'Geçersiz API Key', 'code' => 401];
    }
    
    if ($device['is_active'] != true) {
        return ['error' => 'Cihaz aktif değil', 'code' => 403];
    }
    
    return ['success' => true, 'device_id' => $device['device_id']];
}

// JSON Response Gönder
function sendResponse($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// GET İstekleri - Bekleyen SMS'leri Al
if ($method === 'GET' && $request === 'pending') {
    $auth = checkApiKey();
    if (isset($auth['error'])) {
        sendResponse($auth, $auth['code']);
    }
    
    $deviceId = $auth['device_id'];
    
    // Son görülme zamanını güncelle
    $db = getDBConnection();
    $stmt = $db->prepare("UPDATE devices SET last_seen = CURRENT_TIMESTAMP WHERE device_id = ?");
    $stmt->execute([$deviceId]);
    
    // Bekleyen SMS'leri getir
    $stmt = $db->prepare("
        SELECT id, phone_number, message, priority, scheduled_at 
        FROM sms_requests 
        WHERE device_id = ? AND status = 'pending' 
        AND (scheduled_at IS NULL OR scheduled_at <= CURRENT_TIMESTAMP)
        ORDER BY priority DESC, created_at ASC 
        LIMIT 10
    ");
    $stmt->execute([$deviceId]);
    $messages = $stmt->fetchAll();
    
    sendResponse([
        'success' => true,
        'count' => count($messages),
        'messages' => $messages
    ]);
}

// POST İstekleri - SMS Durumunu Güncelle
if ($method === 'POST' && $request === 'update-status') {
    $auth = checkApiKey();
    if (isset($auth['error'])) {
        sendResponse($auth, $auth['code']);
    }
    
    $input = json_decode(file_get_contents('php://input'), true);
    $requestId = $input['request_id'] ?? 0;
    $status = $input['status'] ?? '';
    $errorMessage = $input['error_message'] ?? null;
    
    if (empty($requestId) || empty($status)) {
        sendResponse(['error' => 'request_id ve status gerekli'], 400);
    }
    
    $db = getDBConnection();
    
    $updateFields = ['status = ?'];
    $params = [$status];
    
    if ($status === 'sent') {
        $updateFields[] = 'sent_at = CURRENT_TIMESTAMP';
    } elseif ($status === 'delivered') {
        $updateFields[] = 'delivered_at = CURRENT_TIMESTAMP';
    }
    
    if ($errorMessage) {
        $updateFields[] = "error_message = ?";
        $params[] = $errorMessage;
    }
    
    $params[] = $requestId;
    $params[] = $auth['device_id'];
    
    $sql = "UPDATE sms_requests SET " . implode(', ', $updateFields) . " WHERE id = ? AND device_id = ?";
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    
    sendResponse(['success' => true, 'message' => 'Durum güncellendi']);
}

// POST İstekleri - Cihaz Kaydı
if ($method === 'POST' && $request === 'register-device') {
    $input = json_decode(file_get_contents('php://input'), true);
    $deviceId = $input['device_id'] ?? '';
    $deviceName = $input['device_name'] ?? '';
    $phoneNumber = $input['phone_number'] ?? '';
    
    if (empty($deviceId)) {
        sendResponse(['error' => 'device_id gerekli'], 400);
    }
    
    $db = getDBConnection();
    
    // Cihaz zaten kayıtlı mı kontrol et
    $stmt = $db->prepare("SELECT api_key FROM devices WHERE device_id = ?");
    $stmt->execute([$deviceId]);
    $existing = $stmt->fetch();
    
    if ($existing) {
        sendResponse([
            'success' => true,
            'message' => 'Cihaz zaten kayıtlı',
            'api_key' => $existing['api_key']
        ]);
    }
    
    // Yeni API key oluştur
    $apiKey = bin2hex(random_bytes(32));
    
    $stmt = $db->prepare("
        INSERT INTO devices (device_id, device_name, phone_number, api_key, last_seen) 
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    ");
    $stmt->execute([$deviceId, $deviceName, $phoneNumber, $apiKey]);
    
    sendResponse([
        'success' => true,
        'message' => 'Cihaz kaydedildi',
        'api_key' => $apiKey
    ], 201);
}

// POST İstekleri - SMS Kuyruğuna Ekle (Harici kullanım için)
if ($method === 'POST' && $request === 'send-sms') {
    $input = json_decode(file_get_contents('php://input'), true);
    $deviceId = $input['device_id'] ?? '';
    $phoneNumber = $input['phone_number'] ?? '';
    $message = $input['message'] ?? '';
    $priority = $input['priority'] ?? 5;
    
    if (empty($deviceId) || empty($phoneNumber) || empty($message)) {
        sendResponse(['error' => 'device_id, phone_number ve message gerekli'], 400);
    }
    
    $db = getDBConnection();
    
    // Cihazın var olduğunu kontrol et
    $stmt = $db->prepare("SELECT is_active FROM devices WHERE device_id = ?");
    $stmt->execute([$deviceId]);
    $device = $stmt->fetch();
    
    if (!$device) {
        sendResponse(['error' => 'Cihaz bulunamadı'], 404);
    }
    
    if ($device['is_active'] != true) {
        sendResponse(['error' => 'Cihaz aktif değil'], 403);
    }
    
    // SMS isteğini ekle
    $stmt = $db->prepare("
        INSERT INTO sms_requests (device_id, phone_number, message, priority, status) 
        VALUES (?, ?, ?, ?, 'pending')
        RETURNING id
    ");
    $stmt->execute([$deviceId, $phoneNumber, $message, $priority]);
    $result = $stmt->fetch();
    
    sendResponse([
        'success' => true,
        'message' => 'SMS kuyruğa eklendi',
        'request_id' => $result['id']
    ], 201);
}

// Geçersiz İstek
sendResponse(['error' => 'Geçersiz API isteği'], 404);
?>
