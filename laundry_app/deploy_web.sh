#!/usr/bin/env bash
# Landing estática en la raíz + app Flutter en /app/. Uso: ./deploy_web.sh [--no-deploy]
set -euo pipefail
cd "$(dirname "$0")"
flutter build web --release --no-tree-shake-icons --base-href /app/
# sin service worker: cada despliegue se ve al recargar (el SW cacheaba builds viejos)
python3 - <<'PY'
import re
p = 'build/web/flutter_bootstrap.js'
s = open(p).read()
s = re.sub(r'_flutter\.loader\.load\(\{.*?\}\);', '_flutter.loader.load();', s, flags=re.S)
open(p, 'w').write(s)
PY
python3 tool/gen_legal_html.py
rm -rf build/hosting && mkdir -p build/hosting/app
cp -R ../landing/public/. build/hosting/
cp -R build/web/. build/hosting/app/
# el service worker de la app antigua vivía en la raíz: este lo desinstala en los navegadores que lo tengan
cat > build/hosting/flutter_service_worker.js <<'SW'
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil((async()=>{
  for(const k of await caches.keys())await caches.delete(k);
  await self.registration.unregister();
  for(const c of await self.clients.matchAll())c.navigate(c.url);
})()));
SW
[ "${1:-}" = "--no-deploy" ] || firebase deploy --only hosting --project laundry-app-asustadores
