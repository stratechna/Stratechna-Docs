#!/usr/bin/env python3
FILE = "/usr/src/paperless/src/documents/templates/index.html"

with open(FILE) as f:
    content = f.read()

# Substituir SVG logo pelo nosso PNG
content = content.replace(
    '{% include "paperless-ngx/snippets/svg_logo.html" with extra_attrs="class=\'logo mb-2\' height=\'6em\'" %}',
    '<img src="/static/custom/login_logo.png" class="logo mb-2" height="96" width="96" style="object-fit:contain">'
)

# Substituir fundo branco por escuro
content = content.replace(
    'class="bg-light w-100 h-100 d-flex align-items-center"',
    'class="w-100 h-100 d-flex align-items-center" style="background-color:#111314"'
)

# Corrigir link docs
content = content.replace(
    'href="https://docs.paperless-ngx.com"',
    'href="https://stratechna.com"'
)

# Corrigir cor do texto do loader para branco
content = content.replace(
    '.app-loader svg, .app-loader h6 {\nopacity: 0.1;',
    '.app-loader svg, .app-loader h6 {\nopacity: 0.1;\ncolor: #e0e0e0 !important;'
)


# Injectar link ao CSS de overrides no <head>
if 'stratechna_overrides' not in content:
    content = content.replace(
        '</head>',
        '<link rel="stylesheet" href="/static/custom/stratechna_overrides.css"></head>'
    )

with open(FILE, "w") as f:
    f.write(content)

print("Feito.")
