<?php
/* =====================================================================
   NS FINANCE — index.php
   NAVI SHIPPING OPC  ·  Finance and Accounting Portal

   The front door. It signs the user in, holds the session, and serves
   the portal. Every other page and the API should begin with
   require_login(), so nothing is reachable without a session.
   ===================================================================== */

require_once __DIR__ . '/config.php';

/* ---------------------------------------------------------------------
   Session and transport
   --------------------------------------------------------------------- */
if (FORCE_HTTPS && empty($_SERVER['HTTPS']) && ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') !== 'https') {
    header('Location: https://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'], true, 301);
    exit;
}
session_name(SESSION_NAME);
session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'secure'   => FORCE_HTTPS,
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();

header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');

/* Sign out anyone idle longer than the configured window. */
if (isset($_SESSION['seen']) && (time() - $_SESSION['seen']) > SESSION_LIFETIME) {
    session_unset();
    session_destroy();
    session_start();
    $_SESSION['flash'] = 'Signed out after a period of inactivity.';
}
$_SESSION['seen'] = time();

/* ---------------------------------------------------------------------
   Helpers
   --------------------------------------------------------------------- */
function csrf_token(): string {
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(32));
    return $_SESSION['csrf'];
}
function csrf_ok(?string $t): bool {
    return !empty($_SESSION['csrf']) && is_string($t) && hash_equals($_SESSION['csrf'], $t);
}
function current_user(): ?array {
    return $_SESSION['user'] ?? null;
}
function require_login(): array {
    $u = current_user();
    if (!$u) { header('Location: index.php'); exit; }
    return $u;
}
function audit(string $action, string $table = 'session', ?string $rec = null, $before = null, $after = null): void {
    $u = current_user();
    $st = ns_db()->prepare(
        'INSERT INTO audit_log (user_id, username, action, table_name, record_id, before_json, after_json, ip)
         VALUES (?,?,?,?,?,?,?,?)');
    $st->execute([
        $u['id'] ?? null, $u['username'] ?? ($_POST['username'] ?? null),
        $action, $table, $rec,
        $before === null ? null : json_encode($before, JSON_UNESCAPED_UNICODE),
        $after  === null ? null : json_encode($after,  JSON_UNESCAPED_UNICODE),
        $_SERVER['REMOTE_ADDR'] ?? null,
    ]);
}
function e(?string $s): string { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

/* ---------------------------------------------------------------------
   Actions
   --------------------------------------------------------------------- */
$action = $_GET['a'] ?? '';
$error  = '';

if ($action === 'logout') {
    if (current_user()) audit('logout');
    session_unset();
    session_destroy();
    header('Location: index.php');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $action === 'login') {
    if (!csrf_ok($_POST['csrf'] ?? null)) {
        $error = 'The sign-in form expired. Try again.';
    } else {
        /* Simple throttle: five attempts, then a minute's wait.
           Slows a guessing attack without locking staff out for long. */
        $tries = $_SESSION['tries'] ?? ['n' => 0, 'at' => 0];
        if ($tries['n'] >= 5 && (time() - $tries['at']) < 60) {
            $error = 'Too many attempts. Wait a minute and try again.';
        } else {
            $username = trim($_POST['username'] ?? '');
            $password = (string)($_POST['password'] ?? '');
            $st = ns_db()->prepare('SELECT * FROM users WHERE username = ? AND active = 1');
            $st->execute([$username]);
            $row = $st->fetch();

            if ($row && password_verify($password, $row['pass_hash'])) {
                session_regenerate_id(true);
                $_SESSION['user'] = [
                    'id'       => $row['id'],
                    'username' => $row['username'],
                    'name'     => $row['full_name'],
                    'role'     => $row['role'],
                ];
                unset($_SESSION['tries']);
                ns_db()->prepare('UPDATE users SET last_login = NOW() WHERE id = ?')->execute([$row['id']]);
                audit('login', 'users', $row['id']);
                header('Location: index.php');
                exit;
            }
            $_SESSION['tries'] = ['n' => $tries['n'] + 1, 'at' => time()];
            audit('login-failed', 'users');
            $error = 'That username and password do not match.';
        }
    }
}

$user = current_user();

/* ---------------------------------------------------------------------
   Signed in — serve the portal
   --------------------------------------------------------------------- */
if ($user) {
    $co = ns_setting('company', CO_NAME);
    ?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e(APP_NAME) ?> — <?= e($co) ?></title>
<style>
  html,body{margin:0;height:100%;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#F4F8F9}
  #bar{display:flex;align-items:center;gap:12px;padding:6px 14px;background:#0B3D56;color:#EAF4F6;font-size:13px}
  #bar b{font-size:14px;letter-spacing:.4px}
  #bar .sp{flex:1}
  #bar a{color:#EAF4F6;text-decoration:none;border:1px solid rgba(255,255,255,.35);
         border-radius:6px;padding:4px 10px}
  #bar a:hover{background:rgba(255,255,255,.12)}
  iframe{display:block;width:100%;height:calc(100vh - 34px);border:0;background:#fff}
</style>
</head>
<body>
  <div id="bar">
    <b>NS FINANCE</b>
    <span><?= e($co) ?></span>
    <span class="sp"></span>
    <span><?= e($user['name']) ?> &middot; <?= e(ucfirst($user['role'])) ?></span>
    <a href="index.php?a=logout">Sign out</a>
  </div>
  <iframe src="portal.html" title="NS FINANCE portal"></iframe>
<script>
  /* Warn a minute before the session lapses, so nobody loses a half-keyed payroll. */
  var idle = <?= (int)SESSION_LIFETIME ?> * 1000;
  setTimeout(function () {
    alert('Your session is about to expire. Save what you are working on, then sign in again.');
  }, Math.max(idle - 60000, 30000));
</script>
</body>
</html><?php
    exit;
}

/* ---------------------------------------------------------------------
   Not signed in — the sign-in page
   --------------------------------------------------------------------- */
$flash = $_SESSION['flash'] ?? '';
unset($_SESSION['flash']);
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign in — <?= e(APP_NAME) ?></title>
<style>
  :root{--navy:#0B3D56;--teal:#0E6B76;--orange:#E1653B;--gold:#C9962B;--line:#D5E0E2}
  html,body{margin:0;height:100%;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;
            background:#EDF3F4;color:#12333B}
  .wrap{min-height:100%;display:flex;align-items:center;justify-content:center;padding:24px}
  .card{width:100%;max-width:380px;background:#fff;border:1px solid var(--line);border-radius:14px;
        box-shadow:0 14px 34px rgba(9,40,46,.12);overflow:hidden}
  .head{background:linear-gradient(90deg,#08323F,var(--teal));color:#fff;padding:18px 20px;
        border-bottom:3px solid var(--gold)}
  .head b{display:block;font-size:19px;letter-spacing:.6px}
  .head span{font-size:12px;color:#A9CFD6;font-style:italic}
  form{padding:20px}
  label{display:block;font-size:12px;color:#456B73;margin:10px 0 4px}
  input{width:100%;box-sizing:border-box;padding:10px 11px;border:1px solid var(--line);
        border-radius:8px;font-size:15px}
  input:focus{outline:2px solid #9CC6CF;border-color:#9CC6CF}
  button{width:100%;margin-top:16px;padding:11px;border:0;border-radius:8px;background:var(--teal);
         color:#fff;font-size:15px;font-weight:600;cursor:pointer}
  button:hover{background:#0B5A64}
  .msg{margin:0 0 6px;padding:9px 11px;border-radius:8px;font-size:13px}
  .err{background:#FDECEA;color:#9F2B20;border:1px solid #F3C9C3}
  .note{background:#F2F7F8;color:#456B73;border:1px solid var(--line)}
  .foot{padding:12px 20px 18px;font-size:11px;color:#6B8A91;text-align:center;border-top:1px solid var(--line)}
</style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <div class="head">
      <b>NS FINANCE</b>
      <span><?= e(CO_TAGLINE) ?></span>
    </div>
    <form method="post" action="index.php?a=login" autocomplete="off">
      <input type="hidden" name="csrf" value="<?= e(csrf_token()) ?>">
      <?php if ($error): ?><p class="msg err"><?= e($error) ?></p><?php endif; ?>
      <?php if ($flash): ?><p class="msg note"><?= e($flash) ?></p><?php endif; ?>

      <label for="u">Username</label>
      <input id="u" name="username" required autofocus autocapitalize="none" spellcheck="false">

      <label for="p">Password</label>
      <input id="p" name="password" type="password" required>

      <button type="submit">Sign in</button>
    </form>
    <div class="foot">
      <?= e(ns_setting('company', CO_NAME)) ?><br>
      Authorised users only. Access is logged.
    </div>
  </div>
</div>
</body>
</html>
