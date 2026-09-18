<?php
/* =====================================================================
   NS FLEET — NAVI Shipping Fleet Management System
   config.php — database connection and application settings

   Edit the settings between the lines marked EDIT THIS, upload the three
   files to the same folder on the web host, then open index.php.
   Keep this file out of any public backup: it holds the database password.
   ===================================================================== */

/* ---------------- EDIT THIS — database ---------------------------- */
define('DB_HOST', 'localhost');                 // cPanel hosts almost always use localhost
define('DB_NAME', 'navishi_nsfleet');           // the database created in cPanel
define('DB_USER', 'navishi_nsfleet');           // the database user
define('DB_PASS', 'PUT-THE-DATABASE-PASSWORD-HERE');
define('DB_PORT', 3306);

/* ---------------- EDIT THIS — first administrator ----------------- */
/* Used once, the first time the system is opened, to create the login.
   Change the password immediately after the first sign-in, then set
   FIRST_RUN to false so the account cannot be recreated.               */
define('FIRST_RUN',      true);
define('ADMIN_USER',     'admin');
define('ADMIN_NAME',     'System Administrator');
define('ADMIN_PASSWORD', 'ChangeThisNow2026');

/* ---------------- Application ------------------------------------- */
define('APP_NAME',     'NS FLEET');
define('APP_LONG',     'NAVI Shipping Fleet Management System');
define('COMPANY',      'NAVI SHIPPING OPC');
define('COMPANY_ADDR', '18 Leo St., Veraville Homes 1, Almanza Uno, Las Piñas City, NCR 1750, Philippines');
define('COMPANY_TEL',  '+63 2 8894 3101');
define('COMPANY_MOB',  '+63 927 621 2975');
define('COMPANY_MAIL', 'operations@navishipping.com.ph');
define('COMPANY_WEB',  'www.navishipping.com.ph');
define('APP_TZ',       'Asia/Manila');
define('SESSION_HOURS', 12);        // sign-in lasts this long
define('MAX_UPLOAD_KB', 700);       // certificate and audit attachments

/* ---------------- Nothing below needs editing --------------------- */

date_default_timezone_set(APP_TZ);
mb_internal_encoding('UTF-8');

/* Sessions — name them so they do not collide with other apps on the host */
if (session_status() === PHP_SESSION_NONE) {
    session_name('NSFLEET');
    session_set_cookie_params([
        'lifetime' => SESSION_HOURS * 3600,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
    ]);
    session_start();
}

/* ---------------- Database ---------------------------------------- */
function db() {
    static $pdo = null;
    if ($pdo !== null) return $pdo;
    $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4';
    try {
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        $pdo->exec("SET time_zone = '+08:00'");
    } catch (PDOException $e) {
        http_response_code(500);
        die('<h2 style="font-family:sans-serif">NS FLEET cannot reach the database</h2>'
          . '<p style="font-family:sans-serif">Check DB_NAME, DB_USER and DB_PASS in config.php, '
          . 'and that the database user is assigned to the database in cPanel.</p>'
          . '<pre style="font-family:monospace;color:#b3261e">' . htmlspecialchars($e->getMessage()) . '</pre>');
    }
    return $pdo;
}

/* ---------------- Tables the system syncs -------------------------- */
/* Order matters: vessels first, then anything that points at a vessel,
   then findings which also point at an audit.                          */
function nsfleet_tables() {
    return ['vessels','engines','crew','crewchange','components','pmsjobs','defects',
            'requisitions','drills','incidents','audits','findings','certificates',
            'voyages','bunkers','dailyreports'];
}
/* Fields holding a link to another record — stored with an _id suffix */
function nsfleet_refs() {
    return ['vessel' => 'vessel_id', 'audit' => 'audit_id'];
}
/* Fields holding an attachment — stored across three columns */
function nsfleet_files() {
    return ['certificates' => ['file'], 'audits' => ['file'], 'findings' => ['file']];
}

/* ---------------- Authentication ----------------------------------- */
function current_user() {
    return isset($_SESSION['nsfleet_user']) ? $_SESSION['nsfleet_user'] : null;
}
function require_login() {
    $u = current_user();
    if (!$u) { http_response_code(401); echo json_encode(['error' => 'not signed in']); exit; }
    return $u;
}
function can_write() {
    $u = current_user();
    return $u && $u['role'] !== 'read';
}
function log_change($table, $id, $action) {
    $u = current_user();
    try {
        $st = db()->prepare("INSERT INTO change_log (at, username, table_name, record_id, action, ip)
                             VALUES (NOW(), ?, ?, ?, ?, ?)");
        $st->execute([$u ? $u['username'] : null, $table, $id, $action,
                      isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : null]);
    } catch (Exception $e) { /* logging must never block a save */ }
}

/* ---------------- First run ---------------------------------------- */
function ensure_admin() {
    if (!FIRST_RUN) return;
    try {
        $n = db()->query("SELECT COUNT(*) FROM users")->fetchColumn();
        if ($n > 0) return;
        $st = db()->prepare("INSERT INTO users (username, fullname, position, pass_hash, role, active, created)
                             VALUES (?, ?, 'Administrator', ?, 'admin', 1, NOW())");
        $st->execute([ADMIN_USER, ADMIN_NAME, password_hash(ADMIN_PASSWORD, PASSWORD_DEFAULT)]);
    } catch (Exception $e) { /* the tables may not be imported yet */ }
}

/* ---------------- Company mark (sign-in page) ---------------------- */
function logo_svg() {
    return '<svg viewBox="0 0 132 92" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="NS Fleet">'
      . '<g fill="none" stroke="#0E6B76" stroke-width="4" stroke-linecap="round" opacity=".55">'
      . '<path d="M8 80c6-5 12-5 18 0s12 5 18 0 12-5 18 0 12 5 18 0 12-5 18 0 12 5 18 0"/></g>'
      . '<path d="M6 54h120l-6 6-10 12H22L8 58z" fill="#0B3D56"/>'
      . '<path d="M19 66h93l-5 6H25z" fill="#E1653B"/>'
      . '<rect x="11" y="34" width="22" height="20" rx="2.5" fill="#0B3D56"/>'
      . '<g fill="#EAF4F3"><rect x="14.5" y="38" width="5" height="4" rx="1"/><rect x="22" y="38" width="5" height="4" rx="1"/>'
      . '<rect x="14.5" y="45" width="5" height="4" rx="1"/><rect x="22" y="45" width="5" height="4" rx="1"/></g>'
      . '<rect x="17" y="20" width="10" height="15" rx="2" fill="#E1653B"/>'
      . '<rect x="17" y="24" width="10" height="3.5" fill="#0B3D56"/>'
      . '<g font-family="Segoe UI,Helvetica,Arial,sans-serif" font-weight="800" font-size="40" text-anchor="middle">'
      . '<text x="66" y="53" fill="#0E6B76">N</text><text x="102" y="53" fill="#E1653B">S</text></g>'
      . '</svg>';
}
