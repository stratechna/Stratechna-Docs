#!/usr/bin/env python3
"""Aplica a marca Stratechna ao Paperless-ngx, durante o build da imagem.

Regras (ver README):
- Nunca substitui por inteiro um ficheiro de código ou template do upstream:
  troca texto por padrão. A única excepção são os favicon.ico (imagens, sem lógica).
- Cada troca declara quantas ocorrências espera no mínimo. Se o upstream mudar e
  um padrão desaparecer, o build FALHA em vez de publicar uma imagem sem marca.
- Depois de mexer num ficheiro estático, regenera as versões .gz e .br que o
  whitenoise serve; sem isso os browsers receberiam a versão antiga comprimida.
"""
import gettext
import gzip
import pathlib
import re
import subprocess
import sys

import brotli

RAIZ = pathlib.Path("/usr/src/paperless")
SRC = RAIZ / "src"
STATIC_ROOT = RAIZ / "static"
FRONTEND = SRC / "documents/static/frontend"
TEMPLATES = SRC / "documents/templates"
LOCALE = SRC / "locale"
PROPRIOS = STATIC_ROOT / "custom"

UPSTREAM = "Paperless-ngx"
MARCA = "Stratechna Docs"
SITE = "https://stratechna.com"
# Links para a documentação e o repositório do upstream, com caminho incluído
URL_UPSTREAM = (r"https://(?:docs\.paperless-ngx\.com|paperless-ngx\.readthedocs\.io"
                r"|github\.com/paperless-ngx/paperless-ngx)[^\"'`\s)<]*")

erros = []
alterados = set()


def trocar(ficheiro, padrao, novo, minimo=1, regex=False):
    p = pathlib.Path(ficheiro)
    if not p.exists():
        erros.append(f"{p}: ficheiro não existe")
        return 0
    texto = p.read_text(encoding="utf-8")
    if regex:
        novo_texto, n = re.subn(padrao, lambda _m: novo, texto)
    else:
        n = texto.count(padrao)
        novo_texto = texto.replace(padrao, novo)
    if n < minimo:
        erros.append(f"{p.relative_to(RAIZ)}: «{padrao[:70]}» aparece {n}x, esperado >= {minimo}")
        return 0
    if n:
        p.write_text(novo_texto, encoding="utf-8")  # escreve no alvo, mesmo por symlink
        alterados.add(p.resolve())
    return n


# ── 1. Frontend Angular: um main.js por idioma ──────────────────────────────
idiomas = sorted(d for d in FRONTEND.iterdir() if (d / "main.js").exists())
if len(idiomas) < 30:
    erros.append(f"frontend: só {len(idiomas)} idiomas com main.js — estrutura do upstream mudou?")
for d in idiomas:
    trocar(d / "main.js", URL_UPSTREAM, SITE, minimo=1, regex=True)
    trocar(d / "main.js", "by " + UPSTREAM, "by Stratechna", minimo=0)
    trocar(d / "main.js", "por " + UPSTREAM, "por Stratechna", minimo=0)
    trocar(d / "main.js", UPSTREAM, MARCA, minimo=1)
    trocar(d / "index.html", f"<title>{UPSTREAM}</title>", f"<title>{MARCA}</title>", minimo=1)
    trocar(d / "manifest.webmanifest", UPSTREAM, MARCA, minimo=1)

# ── 2. Template da aplicação (o index.html que o Django serve) ─────────────
idx = TEMPLATES / "index.html"
trocar(idx, f"<title>{UPSTREAM}</title>", f"<title>{MARCA}</title>")
trocar(idx, 'content="The Paperless-ngx Team"', 'content="Stratechna"')
trocar(idx, r'\{% include "paperless-ngx/snippets/svg_logo\.html" with extra_attrs="[^"]*" %\}',
       '<img src="{% static \'custom/login_logo.png\' %}" class="logo mb-2" height="96" width="96"'
       ' style="object-fit:contain" alt="Stratechna Docs">', regex=True)
trocar(idx, 'class="bg-light w-100 h-100 d-flex align-items-center"',
       'class="w-100 h-100 d-flex align-items-center" style="background-color:#111314"')
trocar(idx, URL_UPSTREAM, SITE, regex=True)
trocar(idx, "</head>",
       "\t<link rel=\"stylesheet\" href=\"{% static 'custom/stratechna_overrides.css' %}\">\n</head>")

# ── 3. Template do login e das restantes páginas de conta ──────────────────
base = TEMPLATES / "paperless-ngx/base.html"
trocar(base, "by " + UPSTREAM, "by Stratechna", minimo=2)
trocar(base, 'content="Paperless-ngx project and contributors"', 'content="Stratechna"')
trocar(base, "</head>",
       "    <link href=\"{% static 'custom/stratechna_login.css' %}\" rel=\"stylesheet\">\n    </head>")

# Cabeçalho e título do admin do Django (o index_title vai pelas traduções)
urls = SRC / "paperless/urls.py"
trocar(urls, f'admin.site.site_header = "{UPSTREAM}"', f'admin.site.site_header = "{MARCA}"')
trocar(urls, f'admin.site.site_title = "{UPSTREAM}"', f'admin.site.site_title = "{MARCA}"')


# ── 4. Traduções do backend (títulos das páginas de conta, admin, loader) ──
def blocos(linhas):
    """Divide um .po em entradas (listas de linhas) separadas por linhas vazias."""
    atual = []
    for l in linhas:
        if l.strip():
            atual.append(l)
        elif atual:
            yield atual
            atual = []
    if atual:
        yield atual


def campos(entrada):
    """{palavra-chave: (índice da 1.ª linha, índice da última, valor em bruto)}"""
    res, chave, ini, partes = {}, None, None, []
    for i, l in enumerate(entrada):
        m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?) "(.*)"$', l)
        if m:
            if chave:
                res[chave] = (ini, i - 1, "".join(partes))
            chave, ini, partes = m.group(1), i, [m.group(2)]
        elif chave and l.startswith('"') and l.endswith('"'):
            partes.append(l[1:-1])
        elif chave:
            res[chave] = (ini, i - 1, "".join(partes))
            chave = None
    if chave:
        res[chave] = (ini, len(entrada) - 1, "".join(partes))
    return res


def marcar_po(po, ids):
    saida, n, vistos = [], 0, set()
    for e in blocos(po.read_text(encoding="utf-8").splitlines()):
        c = campos(e)
        if "msgid" not in c or not c["msgid"][2] or e[0].startswith("#~"):
            saida.append("\n".join(e))
            continue
        msgid = c["msgid"][2]
        if "msgctxt" not in c:
            vistos.add(msgid)
        plural = c.get("msgid_plural", (0, 0, msgid))[2]
        fuzzy = any(l.startswith("#,") and "fuzzy" in l for l in e)
        no_id = UPSTREAM in msgid or UPSTREAM in plural
        novas = {}
        for k, (a, b, v) in c.items():
            if not k.startswith("msgstr"):
                continue
            origem = plural if k not in ("msgstr", "msgstr[0]") else msgid
            if no_id and (not v or fuzzy):
                v = origem          # sem tradução (inglês) ou tradução duvidosa
            if UPSTREAM in v:
                novas[k] = (a, b, v.replace(UPSTREAM, MARCA))
        if not novas:
            saida.append("\n".join(e))
            continue
        n += 1
        linhas = list(e)
        for k, (a, b, v) in sorted(novas.items(), key=lambda x: -x[1][0]):
            linhas[a:b + 1] = [f'{k} "{v}"']
        if fuzzy:  # a tradução passou a ser a nossa: deixa de ser ignorada pelo msgfmt
            linhas = [re.sub(r",\s*fuzzy", "", l) if l.startswith("#,") else l for l in linhas]
            linhas = [l for l in linhas if l.strip() != "#,"]
        saida.append("\n".join(linhas))
    # Idiomas a que faltam estas frases (ex. en_GB) mostrariam o msgid original
    for i in ids:
        if i not in vistos:
            saida.append(f'msgid "{i}"\nmsgstr "{i.replace(UPSTREAM, MARCA)}"')
            n += 1
    po.write_text("\n\n".join(saida) + "\n", encoding="utf-8")
    r = subprocess.run(["msgfmt", "-o", str(po.with_suffix(".mo")), str(po)],
                       capture_output=True, text=True)
    if r.returncode:
        erros.append(f"msgfmt {po.relative_to(RAIZ)}: {r.stderr.strip()[:200]}")
    return n


# As frases do upstream com o nome dele, lidas do ficheiro de origem (en_US)
ids_upstream = [c["msgid"][2] for e in blocos((LOCALE / "en_US/LC_MESSAGES/django.po")
                .read_text(encoding="utf-8").splitlines())
                if (c := campos(e)).get("msgid") and UPSTREAM in c["msgid"][2]
                and "msgctxt" not in c and "msgid_plural" not in c]
if len(ids_upstream) < 5:
    erros.append(f"traduções: só {len(ids_upstream)} msgids com o nome do upstream — estrutura mudou?")

pos = sorted(LOCALE.glob("*/LC_MESSAGES/django.po"))
total_po = sum(marcar_po(p, ids_upstream) for p in pos)
if total_po < len(pos):
    erros.append(f"traduções: só {total_po} entradas marcadas em {len(pos)} idiomas")

# Prova: nenhuma frase do upstream com o nome dele sai traduzida com esse nome
for idioma in (p.parent.parent.name for p in pos):
    t = gettext.translation("django", localedir=LOCALE, languages=[idioma])
    for i in ids_upstream:
        s = t.gettext(i.encode().decode("unicode_escape"))
        if UPSTREAM in s:
            erros.append(f"tradução {idioma}: «{s[:60]}» continua com o nome do upstream")

# ── 5. Favicons (imagens: aqui a substituição inteira é aceitável) ─────────
nosso = (PROPRIOS / "favicon.ico").read_bytes()
favicons = [d / "favicon.ico" for d in idiomas] + [SRC / "paperless/static/paperless/img/favicon.ico"]
for f in favicons:
    if f.exists():
        f.write_bytes(nosso)
        alterados.add(f.resolve())
    else:
        erros.append(f"favicon em falta: {f.relative_to(RAIZ)}")

# ── 6. Versões comprimidas servidas pelo whitenoise ────────────────────────
regeneradas = 0
for comp in list(STATIC_ROOT.rglob("*.gz")) + list(STATIC_ROOT.rglob("*.br")):
    orig = comp.with_suffix("")
    if orig.exists() and orig.resolve() in alterados:
        dados = orig.read_bytes()
        comp.write_bytes(gzip.compress(dados, 9) if comp.suffix == ".gz"
                         else brotli.compress(dados))
        regeneradas += 1
        volta = gzip.decompress if comp.suffix == ".gz" else brotli.decompress
        if volta(comp.read_bytes()) != dados:
            erros.append(f"compressão diferente do original: {comp}")

# ── 7. Verificação final: o nome do upstream não pode sobrar ───────────────
sobras = {str(f.relative_to(RAIZ)): f.read_text(encoding="utf-8").count(UPSTREAM)
          for d in idiomas for f in (d / "main.js", d / "manifest.webmanifest", d / "index.html")}
sobras = {k: v for k, v in sobras.items() if v}
if sobras:
    erros.append(f"nome do upstream ainda presente em: {list(sobras.items())[:5]}")

if erros:
    print("BRANDING FALHOU — o upstream mudou e estas trocas já não encaixam:", file=sys.stderr)
    for e in erros:
        print("  - " + e, file=sys.stderr)
    sys.exit(1)
print(f"branding: {len(idiomas)} idiomas no frontend, {total_po} traduções em {len(pos)} idiomas, "
      f"{len(favicons)} favicons, {regeneradas} ficheiros comprimidos regenerados")
