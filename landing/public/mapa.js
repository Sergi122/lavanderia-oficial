/* Mapa + tarjetas de lavanderías reales (colección pública `lavanderias` de Firestore, vía REST).
   Sin SDK ni claves: las reglas permiten lectura pública y se pide solo los campos necesarios
   (se omiten las fotos en base64). Todo el texto se inserta con textContent. */
(() => {
  const PROJECT = 'laundry-app-asustadores';
  const FIELDS = ['nombre', 'direccion', 'lat', 'lng', 'servicios', 'entregaDomicilio', 'activo', 'descripcion'];
  const URL = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents/lavanderias?pageSize=100&` +
    FIELDS.map(f => 'mask.fieldPaths=' + f).join('&');
  const LA_PAZ = [-16.5, -68.15];

  const val = v => {
    if (!v) return undefined;
    if ('stringValue' in v) return v.stringValue;
    if ('doubleValue' in v) return v.doubleValue;
    if ('integerValue' in v) return Number(v.integerValue);
    if ('booleanValue' in v) return v.booleanValue;
    if ('arrayValue' in v) return (v.arrayValue.values || []).map(val);
    return undefined;
  };
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

  const mapEl = document.getElementById('map');
  const labs = document.getElementById('labs');
  if (!mapEl || !labs || !window.L) return;

  const map = L.map(mapEl, { scrollWheelZoom: false, zoomControl: true }).setView(LA_PAZ, 13);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19, attribution: '© OpenStreetMap',
  }).addTo(map);
  // el scroll de la página no debe quedar atrapado por el mapa: zoom con rueda solo tras hacer clic
  map.on('click', () => map.scrollWheelZoom.enable());
  map.on('mouseout', () => map.scrollWheelZoom.disable());

  const clear = () => { labs.textContent = ''; };
  const msg = t => { clear(); const p = el('p', 'msg', t); p.style.gridColumn = '1/-1'; labs.appendChild(p); };

  fetch(URL).then(r => { if (!r.ok) throw new Error(r.status); return r.json(); }).then(d => {
    const items = (d.documents || []).map(doc => {
      const f = {}; for (const k in doc.fields) f[k] = val(doc.fields[k]);
      f.id = doc.name.split('/').pop(); return f;
    }).filter(l => l.activo !== false && l.nombre);

    if (!items.length) return msg('Muy pronto se unirán las primeras lavanderías.');
    clear();

    const markers = new Map(), cards = new Map();
    const select = (l, fly) => {
      markers.forEach((m, id) => m.getElement()?.firstChild?.classList.toggle('on', id === l.id));
      cards.forEach((c, id) => c.classList.toggle('on', id === l.id));
      if (fly && (l.lat || l.lng)) map.flyTo([l.lat, l.lng], 15, { duration: 1.1 });
      markers.get(l.id)?.openPopup();
    };

    const pts = [];
    items.forEach(l => {
      if (l.lat || l.lng) {
        const icon = L.divIcon({ className: '', html: '<div class="pin"></div>', iconSize: [30, 30], iconAnchor: [15, 30], popupAnchor: [0, -28] });
        const m = L.marker([l.lat, l.lng], { icon }).addTo(map);
        const pop = el('div'); const b = el('b', null, l.nombre); pop.appendChild(b); pop.appendChild(el('br')); pop.appendChild(document.createTextNode(l.direccion || ''));
        m.bindPopup(pop);
        m.on('click', () => select(l, false));
        markers.set(l.id, m); pts.push([l.lat, l.lng]);
      }
      const c = el('article', 'lab glass rv');
      c.appendChild(el('h3', null, l.nombre));
      c.appendChild(el('p', null, '📍 ' + (l.direccion || 'La Paz')));
      const chips = el('div', 'chips');
      (l.servicios || []).slice(0, 4).forEach(s => chips.appendChild(el('span', null, s)));
      if (l.entregaDomicilio) chips.appendChild(el('span', 'd', 'Entrega a domicilio'));
      c.appendChild(chips);
      c.addEventListener('click', () => { select(l, true); document.getElementById('map').scrollIntoView({ behavior: 'smooth', block: 'center' }); });
      labs.appendChild(c); cards.set(l.id, c);
      requestAnimationFrame(() => c.classList.add('in'));
    });
    if (pts.length > 1) map.fitBounds(pts, { padding: [60, 60], maxZoom: 15 });
    else if (pts.length === 1) map.setView(pts[0], 15);
  }).catch(() => msg('No pudimos cargar las lavanderías ahora. Intentá de nuevo en un momento.'));

  // el mapa se dibuja mal si se inicializa antes de ser visible
  setTimeout(() => map.invalidateSize(), 400);
  addEventListener('load', () => map.invalidateSize());
})();
