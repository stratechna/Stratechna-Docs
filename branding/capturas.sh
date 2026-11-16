#!/bin/bash
# Capturas da aplicação com sessão, para ver o aspecto sem mexer na produção.
# Arranca a imagem com PAPERLESS_AUTO_LOGIN_USERNAME (opção oficial do Paperless)
# e fotografa com o Chrome sem ecrã do runner, em claro e em escuro.
# Uso: branding/capturas.sh <imagem> <pasta-de-saida>
set -uo pipefail
IMG=${1:?imagem}; OUT=${2:?pasta}; mkdir -p "$OUT"
ID=capt-docs-$$; PORTA=18100; B=http://127.0.0.1:$PORTA
trap 'docker rm -f $ID-app $ID-redis >/dev/null 2>&1; docker network rm $ID >/dev/null 2>&1' EXIT
docker network create $ID >/dev/null
docker run -d --name $ID-redis --network $ID redis:7-alpine >/dev/null
docker run -d --name $ID-app --network $ID -p 127.0.0.1:$PORTA:8000 \
  -e PAPERLESS_REDIS=redis://$ID-redis:6379 -e PAPERLESS_DBENGINE=sqlite \
  -e PAPERLESS_SECRET_KEY=capturas -e PAPERLESS_ADMIN_USER=verif -e PAPERLESS_ADMIN_PASSWORD=capturas123 \
  -e PAPERLESS_AUTO_LOGIN_USERNAME=verif -e PAPERLESS_APP_TITLE="Stratechna Docs" \
  -e PAPERLESS_APP_LOGO=/static/custom/login_logo.png "$IMG" >/dev/null
for i in $(seq 1 120); do curl -fs -o /dev/null "$B/accounts/login/" && break; sleep 5; done
sleep 10
CH=$(command -v google-chrome || command -v chromium || command -v chromium-browser)
for modo in claro escuro; do
  X=""; [ $modo = escuro ] && X="--force-dark-mode --blink-settings=preferredColorScheme=0"
  for p in "dashboard:/dashboard" "documentos:/documents" "definicoes:/settings"; do
    n=${p%%:*}; u=${p#*:}
    timeout 90 "$CH" --headless=new --no-sandbox --hide-scrollbars --window-size=1440,900 \
      --virtual-time-budget=15000 $X --screenshot="$OUT/docs-$n-$modo.png" "$B$u" >/dev/null 2>&1 || true
  done
  timeout 60 "$CH" --headless=new --no-sandbox --window-size=1440,900 $X --virtual-time-budget=8000 \
    --screenshot="$OUT/docs-login-$modo.png" "$B/accounts/password/reset/" >/dev/null 2>&1 || true
done
ls -la "$OUT"
