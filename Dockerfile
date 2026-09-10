# Stratechna Docs — Paperless-ngx com a marca Stratechna.
#
# A versão do Paperless está FIXA. Actualizar é mudar esta linha, de propósito:
# o aplicar.py falha o build se alguma troca de texto deixar de encaixar, e o
# verificar.sh (no workflow) falha se o nome do upstream ficar visível.
ARG PAPERLESS_VERSION=3.1.3
FROM ghcr.io/paperless-ngx/paperless-ngx:${PAPERLESS_VERSION}
ARG PAPERLESS_VERSION

LABEL org.opencontainers.image.source="https://github.com/stratechna/Stratechna-Docs" \
      org.opencontainers.image.title="Stratechna Docs" \
      org.opencontainers.image.vendor="Stratechna" \
      org.opencontainers.image.version="${PAPERLESS_VERSION}" \
      org.opencontainers.image.base.name="ghcr.io/paperless-ngx/paperless-ngx:${PAPERLESS_VERSION}"

USER root

# OCR em português, do pacote Debian: versão estável, sem downloads soltos
RUN apt-get update \
 && apt-get install -y --no-install-recommends tesseract-ocr-por \
 && rm -rf /var/lib/apt/lists/*

# Ficheiros próprios (logos, favicons, CSS): só se acrescentam
COPY branding/ficheiros/ /usr/src/paperless/static/custom/

# Trocas de texto por padrão, com mínimo de ocorrências; falha se não encaixarem
COPY branding/aplicar.py /tmp/aplicar.py
RUN python3 /tmp/aplicar.py && rm /tmp/aplicar.py
