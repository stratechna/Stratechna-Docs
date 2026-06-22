#!/usr/bin/env python3
"""
inject_branding.py
Patcha os index.html do Angular (static/frontend) com fixes de cor.
O logo da navbar e tratado pelo patch_django_logo.py no template Django.
"""
import os

# Apenas fix da cor do search input — o logo e tratado pelo patch_django_logo.py
SCRIPT = """<script>
(function(){
  function fixSearch(){
    document.querySelectorAll(".search-container input").forEach(function(el){
      el.style.setProperty("color","#e0e0e0","important");
    });
  }
  document.addEventListener("DOMContentLoaded",function(){
    fixSearch();
    setTimeout(fixSearch,1000);
    new MutationObserver(fixSearch).observe(document.body,{childList:true,subtree:true});
  });
})();
</script>"""

base = "/usr/src/paperless/static/frontend"
if not os.path.exists(base):
    # Tentar path src
    base = "/usr/src/paperless/src/documents/static/frontend"

patched = 0
for lang in os.listdir(base):
    f = os.path.join(base, lang, "index.html")
    if os.path.exists(f):
        content = open(f).read()
        if "fixSearch" not in content:
            content = content.replace("</body>", SCRIPT + "</body>")
            open(f, "w").write(content)
            patched += 1

print(f"inject_branding: {patched} ficheiros patchados")
