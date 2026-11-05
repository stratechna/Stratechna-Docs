
# ── Stratechna (18-10-2026): entrada única pelo portal ─────────────────────────
# O Docs entra pelo portal (OpenID Connect, cliente «docs»; o fornecedor configura-se no ambiente do contentor com
# PAPERLESS_APPS e PAPERLESS_SOCIALACCOUNT_PROVIDERS). Pedido do Vítor: a entrada é pelo EMAIL, não pelo nome de
# utilizador — uma conta que já exista com o mesmo email (verificado pelo portal) fica ligada sozinha, e no
# formulário próprio também se pode escrever o email.
SOCIALACCOUNT_EMAIL_AUTHENTICATION = True
SOCIALACCOUNT_EMAIL_AUTHENTICATION_AUTO_CONNECT = True
ACCOUNT_LOGIN_METHODS = {"email", "username"}
ACCOUNT_SIGNUP_FIELDS = ["email*", "username*", "password1*", "password2*"]
ACCOUNT_UNIQUE_EMAIL = True

# ── Stratechna (05-11-2026): entrar com a palavra-passe da caixa de correio (DP2) ──────────────────────────────
# Último backend da lista: só corre quando a palavra-passe do Docs não serve. Ver paperless/stratechna_caixa.py.
if os.environ.get("PAPERLESS_ENTRADA_CAIXA", "1") != "0":
    AUTHENTICATION_BACKENDS = [*AUTHENTICATION_BACKENDS, "paperless.stratechna_caixa.CaixaBackend"]
