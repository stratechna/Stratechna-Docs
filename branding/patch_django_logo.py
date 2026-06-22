#!/usr/bin/env python3
# patch_django_logo.py — injectar script de logo no template Django
# Correr dentro do container: python3 /tmp/patch_django_logo.py
import os

path = "/usr/src/paperless/src/documents/templates/index.html"

with open(path) as f:
    c = f.read()

if "docs-logo" in c:
    print("Script ja existe — nada a fazer")
    exit(0)

script = [
    "<script>",
    "(function(){",
    "  localStorage.setItem('colorScheme','dark');",
    "  function injectLogo(){",
    "    var b=document.querySelector('.navbar-brand');",
    "    if(b&&!b.querySelector('.docs-logo')){",
    "      var s=b.querySelector('svg');",
    "      if(s){",
    "        var i=document.createElement('img');",
    "        i.src='/static/custom/docs_logo.png';",
    "        i.className='docs-logo';",
    "        i.style.height='28px';",
    "        i.style.width='auto';",
    "        i.style.marginRight='8px';",
    "        i.style.verticalAlign='middle';",
    "        s.parentNode.replaceChild(i,s);",
    "      }",
    "    }",
    "  }",
    "  var t=0,iv=setInterval(function(){injectLogo();if(++t>20)clearInterval(iv);},500);",
    "  document.addEventListener('DOMContentLoaded',function(){",
    "    injectLogo();",
    "    new MutationObserver(injectLogo).observe(document.body,{childList:true,subtree:true});",
    "  });",
    "})();",
    "</script>",
]

script_str = "\n".join(script)
c = c.replace("</head>", script_str + "\n</head>")

with open(path, "w") as f:
    f.write(c)

print("OK script adicionado ao template Django")
