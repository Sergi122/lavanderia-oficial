#!/usr/bin/env bash
# App Flutter web en la raíz de lavanderia-primera-parte.web.app. Uso: ./deploy_web.sh [--no-deploy]
set -euo pipefail
cd "$(dirname "$0")"
flutter build web --release --no-tree-shake-icons
# sin service worker: cada despliegue se ve al recargar (el SW cacheaba builds viejos)
python3 - <<'PY'
import re
p = 'build/web/flutter_bootstrap.js'
s = open(p).read()
s = re.sub(r'_flutter\.loader\.load\(\{.*?\}\);', '_flutter.loader.load();', s, flags=re.S)
open(p, 'w').write(s)
PY
[ "${1:-}" = "--no-deploy" ] || firebase deploy --only hosting --project compostera-iot
