FROM ghcr.io/paperless-ngx/paperless-ngx:latest

USER root

# Instalar dependências
RUN apt-get update && apt-get install -y --no-install-recommends brotli curl && \
    rm -rf /var/lib/apt/lists/*

# OCR Português — tessdata (fallback se volume nao estiver montado)
RUN curl -sL https://github.com/tesseract-ocr/tessdata/raw/main/por.traineddata \
    -o /usr/share/tesseract-ocr/5/tessdata/por.traineddata

# Branding — custom.css e favicon para /custom/
RUN mkdir -p /custom
COPY branding/custom.css  /custom/custom.css
COPY branding/favicon.png /custom/favicon.png

# Branding — logos para static/custom/ (src + static)
COPY branding/logo_horizontal.png        /usr/src/paperless/src/documents/static/custom/logo.png
COPY branding/logo_vertical.png          /usr/src/paperless/src/documents/static/custom/logo_vertical.png
COPY branding/favicon.png                /usr/src/paperless/src/documents/static/custom/favicon.png
COPY branding/login_logo.png             /usr/src/paperless/src/documents/static/custom/login_logo.png
COPY branding/stratechna-vault-icon.png  /usr/src/paperless/src/documents/static/custom/stratechna-vault-icon.png

COPY branding/logo_horizontal.png        /usr/src/paperless/static/custom/logo.png
COPY branding/login_logo.png             /usr/src/paperless/static/custom/login_logo.png
COPY branding/favicon.png                /usr/src/paperless/static/custom/favicon.png
COPY branding/logo_vertical.png          /usr/src/paperless/static/custom/logo_vertical.png
COPY branding/stratechna-vault-icon.png  /usr/src/paperless/static/custom/stratechna-vault-icon.png

# Branding — patch em src/ (base para collectstatic)
RUN for lang_dir in /usr/src/paperless/src/documents/static/frontend/*/; do \
      if [ -f "${lang_dir}main.js" ]; then \
        sed -i 's/"Paperless-ngx"/"Stratechna Docs"/g' "${lang_dir}main.js"; \
        sed -i "s/'Paperless-ngx'/'Stratechna Docs'/g" "${lang_dir}main.js"; \
        sed -i 's/O Paperless-ngx /O Stratechna Docs /g' "${lang_dir}main.js"; \
        sed -i 's/ Paperless-ngx est/ Stratechna Docs est/g' "${lang_dir}main.js"; \
        sed -i 's/do Paperless-ngx/do Stratechna Docs/g' "${lang_dir}main.js"; \
        sed -i 's/o Paperless-ngx /o Stratechna Docs /g' "${lang_dir}main.js"; \
        sed -i 's/Stratechna Vault/Stratechna Docs/g' "${lang_dir}main.js"; \
        sed -i 's|https://docs.paperless-ngx.com|https://stratechna.com|g' "${lang_dir}main.js"; \
        sed -i 's|https://paperless-ngx.readthedocs.io|https://stratechna.com|g' "${lang_dir}main.js"; \
      fi; \
      if [ -f "${lang_dir}index.html" ]; then \
        sed -i 's/<title>Paperless-ngx<\/title>/<title>Stratechna Docs<\/title>/g' "${lang_dir}index.html"; \
        sed -i 's/theme-color" content="#17541f"/theme-color" content="#111314"/g' "${lang_dir}index.html"; \
      fi; \
    done

# Branding — template de login
RUN sed -i 's/by Paperless-ngx/by Stratechna/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html && \
    sed -i 's/Stratechna Vault/Stratechna Docs/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html && \
    sed -i 's/Paperless-ngx/Stratechna Docs/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html

# Script de patch pós-collectstatic (corre no arranque após o collectstatic)
COPY --chmod=755 branding/99-stratechna-patch.sh /docker-entrypoint.d/99-stratechna-patch.sh
