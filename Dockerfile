FROM ghcr.io/paperless-ngx/paperless-ngx:latest

USER root

# Instalar dependências
RUN apt-get update && apt-get install -y --no-install-recommends brotli curl perl && \
    rm -rf /var/lib/apt/lists/*

# OCR Português
RUN curl -sL https://github.com/tesseract-ocr/tessdata/raw/main/por.traineddata \
    -o /usr/share/tesseract-ocr/5/tessdata/por.traineddata

# Branding — custom.css e favicon
RUN mkdir -p /custom
COPY branding/custom.css  /custom/custom.css
COPY branding/favicon.png /custom/favicon.png

# Branding — logos
COPY branding/logo_horizontal.png       /usr/src/paperless/src/documents/static/custom/logo.png
COPY branding/logo_vertical.png         /usr/src/paperless/src/documents/static/custom/logo_vertical.png
COPY branding/favicon.png               /usr/src/paperless/src/documents/static/custom/favicon.png
COPY branding/login_logo.png            /usr/src/paperless/src/documents/static/custom/login_logo.png
COPY branding/stratechna-vault-icon.png /usr/src/paperless/src/documents/static/custom/stratechna-vault-icon.png
COPY branding/logo_horizontal.png       /usr/src/paperless/static/custom/logo.png
COPY branding/login_logo.png            /usr/src/paperless/static/custom/login_logo.png
COPY branding/favicon.png               /usr/src/paperless/static/custom/favicon.png
COPY branding/logo_vertical.png         /usr/src/paperless/static/custom/logo_vertical.png
COPY branding/stratechna-vault-icon.png /usr/src/paperless/static/custom/stratechna-vault-icon.png

# Branding — patch JS com perl (suporta linhas longas minificadas) em src/ e static/
RUN for base_dir in \
      /usr/src/paperless/src/documents/static/frontend \
      /usr/src/paperless/static/frontend; do \
      for lang_dir in ${base_dir}/*/; do \
        if [ -f "${lang_dir}main.js" ]; then \
          perl -i -pe 's/Paperless-ngx/Stratechna Docs/g' "${lang_dir}main.js"; \
          perl -i -pe 's/Stratechna Vault/Stratechna Docs/g' "${lang_dir}main.js"; \
          perl -i -pe 's|https://docs\.paperless-ngx\.com|https://stratechna.com|g' "${lang_dir}main.js"; \
          perl -i -pe 's|https://paperless-ngx\.readthedocs\.io|https://stratechna.com|g' "${lang_dir}main.js"; \
          perl -i -pe 's|https://github\.com/paperless-ngx/paperless-ngx|https://stratechna.com|g' "${lang_dir}main.js"; \
        fi; \
        if [ -f "${lang_dir}main.js.br" ]; then \
          brotli -d -o "${lang_dir}main.js.tmp" "${lang_dir}main.js.br" 2>/dev/null && \
          perl -i -pe 's/Paperless-ngx/Stratechna Docs/g' "${lang_dir}main.js.tmp" && \
          perl -i -pe 's|https://docs\.paperless-ngx\.com|https://stratechna.com|g' "${lang_dir}main.js.tmp" && \
          perl -i -pe 's|https://github\.com/paperless-ngx/paperless-ngx|https://stratechna.com|g' "${lang_dir}main.js.tmp" && \
          brotli -f -o "${lang_dir}main.js.br" "${lang_dir}main.js.tmp" && \
          cp "${lang_dir}main.js.tmp" "${lang_dir}main.js" && \
          rm -f "${lang_dir}main.js.tmp"; \
        fi; \
        if [ -f "${lang_dir}index.html" ]; then \
          perl -i -pe 's/<title>Paperless-ngx<\/title>/<title>Stratechna Docs<\/title>/g' "${lang_dir}index.html"; \
          perl -i -pe 's/theme-color" content="#17541f"/theme-color" content="#111314"/g' "${lang_dir}index.html"; \
        fi; \
      done; \
    done

# Branding — injectar JS de branding no index.html (logo + pesquisa)
COPY branding/inject_branding.py /tmp/inject_branding.py
RUN python3 /tmp/inject_branding.py

# Branding — template de login
RUN perl -i -pe 's/by Paperless-ngx/by Stratechna/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html && \
    perl -i -pe 's/Paperless-ngx/Stratechna Docs/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html && \
    perl -i -pe 's/Stratechna Vault/Stratechna Docs/g' \
    /usr/src/paperless/src/documents/templates/paperless-ngx/base.html

# Branding — patch no template Django index.html (página principal)
COPY branding/patch_django_index.py /tmp/patch_django_index.py
RUN python3 /tmp/patch_django_index.py
