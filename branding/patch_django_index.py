#!/usr/bin/env python3
"""Patch ao template Django index.html principal"""

SCRIPT = """<script>
(function(){
  function brand(){
    var b=document.querySelector(".navbar-brand");
    if(b&&!b.querySelector(".docs-logo")){
      var s=b.querySelector("svg");
      if(s){
        var i=document.createElement("img");
        i.src="/static/custom/login_logo.png";
        i.className="docs-logo";
        i.style.cssText="height:28px;width:auto;margin-right:8px;vertical-align:middle";
        s.parentNode.replaceChild(i,s);
      }
    }
    document.querySelectorAll(".search-container input").forEach(function(el){
      el.style.setProperty("color","#e0e0e0","important");
    });
  }
  document.addEventListener("DOMContentLoaded",function(){
    brand();setTimeout(brand,500);setTimeout(brand,1500);setTimeout(brand,3000);
    new MutationObserver(brand).observe(document.body,{childList:true,subtree:true});
  });
})();
</script>"""

for path in [
    "/usr/src/paperless/src/documents/templates/index.html",
]:
    try:
        content = open(path).read()
        if "docs-logo" not in content:
            content = content.replace("</body>", SCRIPT + "</body>")
            open(path, "w").write(content)
            print(f"Patched: {path}")
        else:
            print(f"Already patched: {path}")
    except Exception as e:
        print(f"Error {path}: {e}")
