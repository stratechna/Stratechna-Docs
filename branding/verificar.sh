#!/bin/bash
# Teste depois do build: arranca a imagem como um cliente a veria e falha se o
# nome do upstream estiver visível ou se faltar alguma peça da marca.
# Uso: branding/verificar.sh <imagem>     (corre no workflow antes de publicar)
set -uo pipefail
IMG=${1:?uso: verificar.sh <imagem>}
DIR=$(cd "$(dirname "$0")" && pwd)
ID=verif-docs-$$
PORTA=${PORTA:-18000}
B=http://127.0.0.1:$PORTA
SENHA=$(head -c 18 /dev/urandom | base64 | tr -dc A-Za-z0-9)
JAR=$(mktemp)
FALHAS=()
falha() { FALHAS+=("$1"); echo "  FALHA: $1"; }
ok() { echo "  ok: $1"; }

limpar() { docker rm -f $ID-app $ID-redis >/dev/null 2>&1; docker network rm $ID >/dev/null 2>&1; rm -f "$JAR"; }
trap limpar EXIT

docker network create $ID >/dev/null
docker run -d --name $ID-redis --network $ID redis:7-alpine >/dev/null
docker run -d --name $ID-app --network $ID -p 127.0.0.1:$PORTA:8000 \
  -e PAPERLESS_REDIS=redis://$ID-redis:6379 \
  -e PAPERLESS_DBENGINE=sqlite \
  -e PAPERLESS_SECRET_KEY="verif-$SENHA" \
  -e PAPERLESS_ADMIN_USER=verif -e PAPERLESS_ADMIN_PASSWORD="$SENHA" \
  -e PAPERLESS_APP_TITLE="Stratechna Docs" \
  -e PAPERLESS_APP_LOGO=/static/custom/login_logo.png \
  "$IMG" >/dev/null

echo "== à espera do arranque =="
for i in $(seq 1 120); do
  curl -fs -o /dev/null "$B/accounts/login/" && break
  if [ "$i" = 120 ]; then docker logs --tail 40 $ID-app; echo "FALHA: não arrancou em 10 min"; exit 1; fi
  sleep 5
done
ok "arrancou"

sem_upstream() { # $1 descrição, $2 conteúdo (argumento, não stdin: num pipe a falha perdia-se)
  local c; c=$(printf '%s' "$2" | grep -oiE ".{0,40}paperless-ngx.{0,20}" | head -3)
  [ -z "$c" ] && ok "$1 sem o nome do upstream" || falha "$1 mostra o upstream: $c"
}
titulo() { tr '\n' ' ' | sed -nE 's/.*<title>[[:space:]]*([^<]*[^[:space:]<])[[:space:]]*<\/title>.*/\1/p'; }

echo "== páginas de conta (sem sessão) =="
for L in pt-PT en-US; do
  for P in /accounts/login/ /accounts/password/reset/; do
    H=$(curl -fsS -H "Accept-Language: $L" "$B$P")
    T=$(echo "$H" | titulo)
    [[ "$T" == *"Stratechna Docs"* ]] && ok "título $P [$L]: $T" || falha "título $P [$L]: «$T»"
    sem_upstream "$P [$L]" "$H"
  done
done
H=$(curl -fsS "$B/accounts/login/")
echo "$H" | grep -q "custom/stratechna_login.css" && ok "login carrega stratechna_login.css" || falha "login sem stratechna_login.css"
echo "$H" | grep -q "/static/custom/login_logo.png" && ok "login mostra login_logo.png" || falha "login sem login_logo.png"
echo "$H" | grep -qi "by Stratechna" && ok "byline «by Stratechna»" || falha "byline em falta"

echo "== ficheiros próprios e favicon =="
for f in custom/login_logo.png custom/stratechna_login.css custom/stratechna_overrides.css custom/favicon.png; do
  curl -fs -o /dev/null "$B/static/$f" && ok "/static/$f" || falha "/static/$f não é servido"
done
[ "$(curl -fs "$B/favicon.ico" | sha256sum | cut -c1-16)" = "$(sha256sum < "$DIR/ficheiros/favicon.ico" | cut -c1-16)" ] \
  && ok "favicon.ico é o nosso" || falha "favicon.ico não é o nosso"

echo "== aplicação com sessão iniciada =="
curl -fs -c "$JAR" -b "$JAR" -o /tmp/$ID-login.html "$B/accounts/login/"
CSRF=$(sed -nE 's/.*name="csrfmiddlewaretoken" value="([^"]+)".*/\1/p' /tmp/$ID-login.html | head -1)
curl -fs -c "$JAR" -b "$JAR" -o /dev/null -e "$B/accounts/login/" \
  --data-urlencode "csrfmiddlewaretoken=$CSRF" --data-urlencode "login=verif" \
  --data-urlencode "password=$SENHA" "$B/accounts/login/"
rm -f /tmp/$ID-login.html
for L in pt-PT en-US; do
  H=$(curl -fsS -b "$JAR" -H "Accept-Language: $L" "$B/")
  if echo "$H" | grep -q "<pngx-root"; then
    T=$(echo "$H" | titulo)
    [[ "$T" == "Stratechna Docs" ]] && ok "título da aplicação [$L]" || falha "título da aplicação [$L]: «$T»"
    sem_upstream "aplicação [$L]" "$H"
    echo "$H" | grep -q "custom/stratechna_overrides.css" && ok "aplicação carrega stratechna_overrides.css [$L]" || falha "aplicação sem overrides [$L]"
    JS=$(echo "$H" | grep -oE 'src="[^"]*frontend/[^"]*/main\.js"' | head -1 | sed -E 's/^src="//;s/"$//')
    [ -n "$JS" ] || { falha "main.js não referenciado [$L]"; continue; }
    case $JS in /*) U="$B$JS";; http*) U=$JS;; *) U="$B/$JS";; esac
    sem_upstream "main.js [$L]" "$(curl -fsS "$U")"
    for ENC in br gzip; do  # o que o whitenoise serve comprimido tem de ser igual ao patchado
      N=$(curl -fsS -H "Accept-Encoding: $ENC" "$U" | docker exec -i $ID-app python3 -c "
import sys, gzip, brotli
d = sys.stdin.buffer.read()
d = brotli.decompress(d) if '$ENC' == 'br' else gzip.decompress(d)
print(d.count(b'Paperless-ngx'), int(b'Stratechna Docs' in d))" 2>&1)
      [ "$N" = "0 1" ] && ok "main.js servido em $ENC [$L]" || falha "main.js em $ENC [$L]: $N (esperado «0 1»)"
    done
  else
    falha "sem sessão na aplicação [$L] — o login do teste falhou"
  fi
done
H=$(curl -fsS -b "$JAR" -H "Accept-Language: pt-PT" "$B/admin/")
sem_upstream "admin [pt-PT]" "$H"

echo
if [ ${#FALHAS[@]} -gt 0 ]; then
  echo "VERIFICAÇÃO FALHOU (${#FALHAS[@]}) — a imagem não deve ser publicada"
  exit 1
fi
echo "VERIFICAÇÃO OK — a marca está visível e o nome do upstream não aparece"
