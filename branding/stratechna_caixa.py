"""Stratechna Docs (05-11-2026): entrar com a palavra-passe da caixa de correio.

Decisão DP2 do plano das pendências (docs/PLANO-PENDENCIAS-ORBIT-PRIMEIRO.md): no Docs entra-se com o EMAIL e a
palavra-passe da CAIXA, como no Orbit (orbit.entrada_unica.antes_de_entrar, R3). Quando a palavra-passe do Docs não
serve, confirma-se no IMAP do BDS (rede privada 10.0.0.4, certificado próprio StratechnaHostingBDS — o mesmo que o
SOGo e o Orbit aceitam) e, se a caixa a aceitar, grava-se no Docs: a partir daí entra-se como sempre.

Só para utilizadores que JÁ existem e estão activos (nascem no aprovisionamento, R4) — nunca cria contas.
No máximo 5 confirmações no correio por pessoa a cada 10 minutos. Desliga-se com PAPERLESS_ENTRADA_CAIXA=0.
"""
import imaplib
import logging
import os
import socket
import ssl

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db.models import Q

log = logging.getLogger("paperless.stratechna_caixa")

_IMAP = {"host": os.environ.get("PAPERLESS_ENTRADA_CAIXA_HOST", "10.0.0.4"),
         "porta": int(os.environ.get("PAPERLESS_ENTRADA_CAIXA_PORTA", "993")),
         "nome": "StratechnaHostingBDS"}
_CERT = os.path.join(os.path.dirname(__file__), "bds-mail.crt")
_FORA = ("consumer", "AnonymousUser")


def caixa_aceita(endereco: str, pwd: str) -> bool:
    ctx = ssl.create_default_context(cafile=_CERT)

    class _Imap(imaplib.IMAP4_SSL):
        # liga ao endereço privado mas verifica o certificado pelo nome do BDS (não há DNS para ele aqui)
        def _create_socket(self, timeout):
            return self.ssl_context.wrap_socket(socket.create_connection((_IMAP["host"], _IMAP["porta"]), timeout),
                                                server_hostname=_IMAP["nome"])

    try:
        m = _Imap(_IMAP["nome"], _IMAP["porta"], ssl_context=ctx, timeout=10)
    except Exception as e:  # noqa: BLE001 — sem correio, a entrada só não usa a caixa
        log.warning("caixa: IMAP indisponível (%s)", e.__class__.__name__)
        return False
    try:
        m.login(endereco, pwd)
        return True
    except imaplib.IMAP4.error:
        return False
    finally:
        try:
            m.logout()
        except Exception:  # noqa: BLE001
            pass


class CaixaBackend:
    """Backend de autenticação do Django: o último da lista, só corre se os outros recusarem."""

    def authenticate(self, request, username=None, password=None, email=None, **kwargs):
        login = (email or username or kwargs.get("login") or "").strip().lower()
        if "@" not in login or not password or len(password) > 128:
            return None
        User = get_user_model()
        u = (User.objects.filter(Q(username__iexact=login) | Q(email__iexact=login), is_active=True)
             .exclude(username__in=_FORA).first())
        if u is None:
            return None
        chave = f"stratechna_caixa:tentativas:{u.pk}"
        n = cache.get(chave, 0)
        if n >= 5:
            return None
        cache.set(chave, n + 1, 600)
        if not caixa_aceita((u.email or login).lower(), password):
            return None
        u.set_password(password)
        u.save(update_fields=["password"])
        cache.delete(chave)
        log.info("caixa: palavra-passe do Docs gravada a partir da caixa (utilizador %s)", u.pk)
        return u

    def get_user(self, user_id):
        User = get_user_model()
        try:
            return User.objects.get(pk=user_id, is_active=True)
        except User.DoesNotExist:
            return None
