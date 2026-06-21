#!/bin/bash
# Corre após collectstatic — patch nos ficheiros estáticos servidos
echo "[Stratechna] A aplicar patch de branding..."

for lang_dir in /usr/src/paperless/static/frontend/*/; do
  if [ -f "${lang_dir}main.js" ]; then
    # Substituir apenas strings de texto visível (entre aspas)
    sed -i 's/"Paperless-ngx"/"Stratechna Docs"/g' "${lang_dir}main.js"
    sed -i "s/'Paperless-ngx'/'Stratechna Docs'/g" "${lang_dir}main.js"
    sed -i 's/`Paperless-ngx`/`Stratechna Docs`/g' "${lang_dir}main.js"
    # Substituir textos concatenados
    sed -i 's/O Paperless-ngx /O Stratechna Docs /g' "${lang_dir}main.js"
    sed -i 's/ Paperless-ngx est/ Stratechna Docs est/g' "${lang_dir}main.js"
    sed -i 's/do Paperless-ngx/do Stratechna Docs/g' "${lang_dir}main.js"
    sed -i 's/o Paperless-ngx /o Stratechna Docs /g' "${lang_dir}main.js"
    sed -i 's/Stratechna Vault/Stratechna Docs/g' "${lang_dir}main.js"
    sed -i 's|https://docs.paperless-ngx.com|https://stratechna.com|g' "${lang_dir}main.js"
    sed -i 's|https://paperless-ngx.readthedocs.io|https://stratechna.com|g' "${lang_dir}main.js"
  fi
  if [ -f "${lang_dir}index.html" ]; then
    sed -i 's/<title>Paperless-ngx<\/title>/<title>Stratechna Docs<\/title>/g' "${lang_dir}index.html"
    sed -i 's/theme-color" content="#17541f"/theme-color" content="#111314"/g' "${lang_dir}index.html"
  fi
done

echo "[Stratechna] Patch concluído."
