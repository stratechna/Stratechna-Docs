FROM ghcr.io/paperless-ngx/paperless-ngx:latest

USER root

# Instalar dependências
RUN apt-get update && apt-get install -y --no-install-recommends brotli curl && \
    rm -rf /var/lib/apt/lists/*

# OCR Português — tessdata (fallback se volume nao estiver montado)
RUN curl -sL https://github.com/tesseract-ocr/tessdata/raw/main/por.traineddata \
    -o /usr/share/tesseract-ocr/5/tessdata/por.traineddata

# Branding — copiar ficheiros estáticos (src — para collectstatic)
COPY branding/logo_horizontal.png        /usr/src/paperless/src/documents/static/custom/logo.png
COPY branding/logo_vertical.png          /usr/src/paperless/src/documents/static/custom/logo_vertical.png
COPY branding/favicon.png                /usr/src/paperless/src/documents/static/custom/favicon.png
COPY branding/login_logo.png             /usr/src/paperless/src/documents/static/custom/login_logo.png
COPY branding/stratechna-vault-icon.png  /usr/src/paperless/src/documents/static/custom/stratechna-vault-icon.png
COPY branding/custom.css                 /tmp/custom.css

# Branding — copiar também para static/ (destino do collectstatic — garante persistência)
COPY branding/logo_horizontal.png        /usr/src/paperless/static/custom/logo.png
COPY branding/login_logo.png             /usr/src/paperless/static/custom/login_logo.png
COPY branding/favicon.png                /usr/src/paperless/static/custom/favicon.png
COPY branding/logo_vertical.png          /usr/src/paperless/static/custom/logo_vertical.png
COPY branding/stratechna-vault-icon.png  /usr/src/paperless/static/custom/stratechna-vault-icon.png

# Branding — substituir textos nos ficheiros JS (todas as línguas)
RUN for lang_dir in /usr/src/paperless/src/documents/static/frontend/*/; do \
      if [ -f "${lang_dir}main.js" ]; then \
        sed -i 's/Paperless-ngx/Stratechna Docs/g' "${lang_dir}main.js"; \
        sed -i 's/Stratechna Vault/Stratechna Docs/g' "${lang_dir}main.js"; \
        sed -i 's|https://docs.paperless-ngx.com|https://stratechna.com|g' "${lang_dir}main.js"; \
        sed -i 's|https://paperless-ngx.readthedocs.io|https://stratechna.com|g' "${lang_dir}main.js"; \
      fi; \
    done

# Branding — template de login
RUN sed -i 's/by Paperless-ngx/by Stratechna/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html && \
    sed -i 's/Stratechna Vault/Stratechna Docs/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html

# Suprimir flash verde do splash screen (substituir cor de fundo)
RUN sed -i 's/background-color:#1aff00/background-color:#111314/g' \
    /usr/src/paperless/src/documents/static/frontend/en-US/main.js 2>/dev/null || true && \
    for lang_dir in /usr/src/paperless/src/documents/static/frontend/*/; do \
      if [ -f "${lang_dir}main.js" ]; then \
        sed -i 's/background:#[0-9a-fA-F]*green[^;]*/background:#111314/g' "${lang_dir}main.js" 2>/dev/null || true; \
      fi; \
    done
