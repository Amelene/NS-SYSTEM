<?php
/* =====================================================================
   NS FINANCE — configuration
   NAVI SHIPPING OPC  ·  Finance and Accounting Portal

   Keep this file OUTSIDE the public web folder if your hosting allows,
   or protect it with the .htaccess rule at the foot of this file.
   It holds database credentials; anyone who reads it can read the books.
   ===================================================================== */

// ---------------------------------------------------------------------
// 1.  DATABASE
// ---------------------------------------------------------------------
define('DB_HOST', 'localhost');
define('DB_NAME', 'ns_finance');
define('DB_USER', 'ns_finance_user');          // not root — give it only this database
define('DB_PASS', 'CHANGE-THIS-BEFORE-GOING-LIVE');
define('DB_PORT', 3306);
define('DB_CHARSET', 'utf8mb4');

// ---------------------------------------------------------------------
// 2.  COMPANY
//     These are fallbacks. Once the settings table is populated it wins,
//     so the office can change them without editing this file.
// ---------------------------------------------------------------------
define('CO_NAME',    'NAVI SHIPPING OPC');
define('CO_TAGLINE', 'NAVIgating Excellence Towards Innovative Shipping');
define('CO_ADDRESS', '18 Leo St., Veraville Homes 1, Almanza Uno, Las Piñas City, NCR 1750, Philippines');
define('CO_PHONE',   '+63 927 621 2975 / +63 2 8894 3101');
define('CO_EMAIL',   'operations@navishipping.com.ph');
define('CO_WEB',     'www.navishipping.com.ph');
define('CO_TIN',     '');                      // fill in
define('CO_RDO',     '');

// ---------------------------------------------------------------------
// 3.  DOCUMENT NUMBERING
//     Every series restarts at 0001 each January.
// ---------------------------------------------------------------------
$NS_SERIES = [
  'INV'  => 'NS/INV',        // sales invoice        NS/INV-2026-0001
  'BILL' => 'NS/BILL',       // payable voucher      NS/BILL-2026-0001
  'EXP'  => 'NS/EXP',        // daily expense        NS/EXP-2026-0001
  'COE'  => 'NS-COE',        // crew contract        NS-COE-2026-00001  (5 digits)
  'PV'   => 'PV',            // payment voucher
  'CR'   => 'CR',            // collection receipt
  'JV'   => 'JV',            // journal voucher
  'CH'   => 'CH',            // charter contract
  'HS'   => 'HS',            // hire / freight statement
  'PR'   => 'PR',            // payroll run
  'PRJ'  => 'PRJ',           // drydock / repair project
  'VOY'  => 'VOY',           // voyage
];
define('COE_DIGITS', 5);     // crew contracts are five digits, the rest four
define('SERIES_DIGITS', 4);

// Control numbers for people — one number per person, for life
define('CCN_PREFIX',      'CCN');   // seafarers
define('SCN_PREFIX',      'SCN');   // shore staff
define('CCN_LAST_ISSUED', 53);      // CMS roster, last number issued
define('SCN_START',       3);       // shore series begins at the third person

// ---------------------------------------------------------------------
// 4.  STATUTORY RATES — Philippines, as at September 2026
//     Update when a circular changes them; nothing else needs touching.
// ---------------------------------------------------------------------
$NS_RATES = [
  'vat'            => 12.0,   // per cent
  'ewt_service'    => 2.0,    // expanded withholding, services
  'ewt_rental'     => 5.0,    // rental

  'sss_total'      => 15.0,   // total rate on the monthly salary credit
  'sss_ee_share'   => 5.0,    // employee share; employer carries the balance
  'sss_msc_min'    => 5000,
  'sss_msc_max'    => 35000,
  'sss_ec_low'     => 10,     // EC premium below 15,000 MSC
  'sss_ec_high'    => 30,

  'ph_rate'        => 5.0,    // PhilHealth, shared equally
  'ph_floor'       => 10000,
  'ph_ceil'        => 100000,

  'pagibig_cap'    => 10000,  // fund salary ceiling
  'pagibig_ee'     => 2.0,
  'pagibig_er'     => 2.0,

  'bonus_exempt'   => 90000,  // 13th month and benefits, tax-exempt ceiling
];

// TRAIN monthly withholding brackets: [floor, base tax, rate on excess]
$NS_WTAX_MONTHLY = [
  [0,        0,        0.00],
  [20833,    0,        0.15],
  [33333,    1875,     0.20],
  [66667,    8541.80,  0.25],
  [166667,   33541.80, 0.30],
  [666667,   183541.80,0.35],
];

// ---------------------------------------------------------------------
// 5.  PAYROLL
//     Semi-monthly. The scale is a full month; each cut-off pays half.
//     Statutory contributions and withholding are taken once, in the
//     first cut-off. Reimbursements belong to the second.
// ---------------------------------------------------------------------
define('PAYROLL_CUTOFF_1', '1-15');
define('PAYROLL_CUTOFF_2', '16-30');
define('STATUTORY_IN_FIRST_CUTOFF', true);
define('REIMBURSEMENTS_IN_SECOND_CUTOFF', true);

// ---------------------------------------------------------------------
// 6.  SECURITY
// ---------------------------------------------------------------------
define('SESSION_NAME',      'nsfinance');
define('SESSION_LIFETIME',  3600);      // seconds of inactivity before sign-out
define('FORCE_HTTPS',       true);      // set false only while testing locally
define('MGMT_CODE_WINDOW',  10);        // minutes a bank/cash approval stays unlocked
define('MGMT_CODE_HASH',    '');        // password_hash() of the approval code; blank = not set

// ---------------------------------------------------------------------
// 7.  UPLOADS — notarised contracts, insurance policies, receipts
//     Files go on disk, not in the database. Keep the folder outside
//     the web root so a scan cannot be fetched by guessing its URL.
// ---------------------------------------------------------------------
define('UPLOAD_DIR',       __DIR__ . '/../ns-finance-files');
define('UPLOAD_MAX_BYTES', 10 * 1024 * 1024);          // 10 MB per file
$NS_UPLOAD_TYPES = ['application/pdf','image/jpeg','image/png','image/webp'];

// ---------------------------------------------------------------------
// 8.  BACKUP
// ---------------------------------------------------------------------
define('BACKUP_DIR',       __DIR__ . '/../ns-finance-backups');
define('BACKUP_KEEP_DAYS', 90);
define('BACKUP_DAILY_AT',  '23:30');    // server time; run by cron

// ---------------------------------------------------------------------
// 9.  RUNTIME
// ---------------------------------------------------------------------
date_default_timezone_set('Asia/Manila');
define('APP_NAME',    'NS FINANCE');
define('APP_VERSION', '1.0');
define('APP_DEBUG',   false);           // never true on the live site
define('CURRENCY',    'PHP');
define('CURRENCY_SYMBOL', '₱');

// ---------------------------------------------------------------------
// 10. DATABASE CONNECTION
// ---------------------------------------------------------------------
function ns_db(): PDO {
    static $pdo = null;
    if ($pdo instanceof PDO) return $pdo;
    $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s',
                   DB_HOST, DB_PORT, DB_NAME, DB_CHARSET);
    try {
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
        $pdo->exec("SET time_zone = '+08:00'");
    } catch (PDOException $e) {
        if (APP_DEBUG) throw $e;
        http_response_code(500);
        exit('Database unavailable. Tell the administrator.');
    }
    return $pdo;
}

/* Settings from the database, falling back to this file. */
function ns_setting(string $key, $fallback = null) {
    static $cache = null;
    if ($cache === null) {
        $cache = [];
        foreach (ns_db()->query('SELECT skey, sval FROM settings') as $r) {
            $cache[$r['skey']] = $r['sval'];
        }
    }
    return $cache[$key] ?? $fallback;
}

/* Next number in a series, restarting each January.
   Locked inside a transaction so two clerks cannot take the same number. */
function ns_next_no(string $prefix): string {
    global $NS_SERIES;
    $db = ns_db();
    $year = (int)date('Y');
    $db->beginTransaction();
    $db->prepare('INSERT INTO counters (prefix, year, last_no) VALUES (?,?,0)
                  ON DUPLICATE KEY UPDATE prefix=prefix')->execute([$prefix, $year]);
    $db->prepare('UPDATE counters SET last_no = last_no + 1 WHERE prefix=? AND year=?')
       ->execute([$prefix, $year]);
    $n = (int)$db->query("SELECT last_no FROM counters
                          WHERE prefix=" . $db->quote($prefix) . " AND year=$year")
                 ->fetchColumn();
    $db->commit();
    $digits = ($prefix === 'COE') ? COE_DIGITS : SERIES_DIGITS;
    $label  = $NS_SERIES[$prefix] ?? $prefix;
    return sprintf('%s-%d-%0' . $digits . 'd', $label, $year, $n);
}

/* Control number as printed: CCN 00028 / SCN 00003 */
function ns_control_no(?string $digits, string $kind = 'Crew (seafarer)'): string {
    if ($digits === null || $digits === '') return '';
    $p = ($kind === 'Shore staff') ? SCN_PREFIX : CCN_PREFIX;
    return $p . ' ' . str_pad(preg_replace('/\D/', '', $digits), 5, '0', STR_PAD_LEFT);
}

/* ---------------------------------------------------------------------
   .htaccess — put this beside config.php if it must live in the web root:

       <Files "config.php">
           Require all denied
       </Files>

   Before going live:
     1. create the database and run ns-finance-schema.sql
     2. create a database user with rights to ns_finance only
     3. set DB_PASS above, and replace the admin password hash in the SQL
     4. chmod 600 config.php
     5. set FORCE_HTTPS true and install a certificate
     6. put UPLOAD_DIR and BACKUP_DIR outside the web root
--------------------------------------------------------------------- */
