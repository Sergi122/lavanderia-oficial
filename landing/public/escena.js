/* Escena isométrica animada de la lavandería (puerto a canvas de escena_lavanderia.dart).
   Historia en bucle: moto recoge → lleva → recepción → lavando/secando → lista → vuelve a casa → entregada. */
(function () {
  const cv = document.getElementById('escena');
  if (!cv || window.__webgl) return;
  const ctx = cv.getContext('2d');
  const reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;
  const PRIMARY = '#2F7FE0', TINTA = '#0A1C33', ALTO = 0.9;
  const NOMBRE = 'Lavandería Central';

  const CAPITULOS = [
    ['Tu repartidor va a recoger la ropa', { motos: [['recogiendo']] }],
    ['Camino a la lavandería', { motos: [['llevando']] }],
    ['Recibida en recepción', { colgadas: 3, mia: true }],
    ['Lavando y secando', { ciclo: true, colgadas: 2, mia: true }],
    ['Ropa limpia, doblada y lista', { listas: 3, colgadas: 1 }],
    ['Vuelve a tu casa', { motos: [['devolviendo']], listas: 1 }],
    ['¡Entregada en tu puerta!', { paquete: true }],
  ];
  let cap = 0, t = 0, W = 0, H = 0, a = 10, ox = 0, oy = 0;
  let zoom = 1, panX = 0, panY = 0;
  const capEl = document.getElementById('escena-cap');
  const dotsEl = document.getElementById('escena-dots');
  if (dotsEl) dotsEl.innerHTML = CAPITULOS.map(() => '<i></i>').join('');
  function pintaCap() {
    if (capEl) { capEl.textContent = CAPITULOS[cap][0]; }
    if (dotsEl) [...dotsEl.children].forEach((d, i) => d.className = i === cap ? 'on' : '');
  }
  pintaCap();
  setInterval(() => { cap = (cap + 1) % CAPITULOS.length; pintaCap(); }, 6000);

  function resize() {
    const r = cv.getBoundingClientRect(), dpr = Math.min(devicePixelRatio || 1, 2);
    W = r.width; H = r.height;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  addEventListener('resize', resize); resize();

  const p = (x, y, z = 0) => [ox + (x - y) * a, oy + (x + y) * a * 0.5 - z * a * ALTO];
  const sombra = (hex, f) => {
    const n = parseInt(hex.slice(1), 16), k = f;
    const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    const m = (v, to) => Math.round(v * k + to * (1 - k));
    return `rgb(${m(r, 10)},${m(g, 28)},${m(b, 51)})`;
  };
  function poly(pts, fill) {
    ctx.beginPath(); ctx.moveTo(...pts[0]); for (let i = 1; i < pts.length; i++) ctx.lineTo(...pts[i]);
    ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
  }
  function caja(x0, y0, x1, y1, z0, z1, col) {
    poly([p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), p(x1, y0, z1)], sombra(col, .78));
    poly([p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)], sombra(col, .9));
    poly([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)], col);
  }
  function enCaraY(x0, y, z0, fn) {
    const o = p(x0, y, z0);
    ctx.save(); ctx.transform(a, a * .5, 0, a * ALTO, o[0], o[1]); fn(); ctx.restore();
  }
  function rrect(x, y, w, h, r) {
    ctx.beginPath(); ctx.roundRect ? ctx.roundRect(x, y, w, h, r) : ctx.rect(x, y, w, h);
  }
  const circ = (x, y, r, fill) => { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fillStyle = fill; ctx.fill(); };
  function etiqueta(txt, c, fs) {
    ctx.font = `800 ${fs}px Geist, system-ui, sans-serif`;
    const w = ctx.measureText(txt).width + a * .5, h = fs * 1.5;
    ctx.fillStyle = 'rgba(255,255,255,.93)'; rrect(c[0] - w / 2, c[1] - h / 2, w, h, h / 2); ctx.fill();
    ctx.fillStyle = TINTA; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(txt, c[0], c[1] + 1);
  }
  function marcador(punta, txt) {
    const fs = a * .52, pul = 1 + Math.sin(t * 4) * .06;
    ctx.font = `800 ${fs}px Geist, system-ui, sans-serif`;
    const w = ctx.measureText(txt).width * pul + a * .6, h = fs * 1.6, cy = punta[1] - a * .55;
    ctx.fillStyle = PRIMARY; rrect(punta[0] - w / 2, cy - h / 2, w, h, h / 2); ctx.fill();
    ctx.beginPath(); ctx.moveTo(punta[0] - a * .16, cy + h / 2 - 1); ctx.lineTo(punta[0] + a * .16, cy + h / 2 - 1); ctx.lineTo(punta[0], cy + h / 2 + a * .2); ctx.fill();
    ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(txt, punta[0], cy + 1);
  }
  function brillos(c, r) {
    for (let i = 0; i < 3; i++) {
      const ph = ((t * .8) + i / 3) % 1, ang = i * 2.1 + .6;
      const x = c[0] + Math.cos(ang) * r * .7, y = c[1] + Math.sin(ang) * r * .5 - ph * r * .4, k = r * .16 * Math.sin(ph * Math.PI);
      ctx.fillStyle = '#FFE27A'; ctx.beginPath();
      ctx.moveTo(x, y - k); ctx.lineTo(x + k * .3, y - k * .3); ctx.lineTo(x + k, y); ctx.lineTo(x + k * .3, y + k * .3);
      ctx.lineTo(x, y + k); ctx.lineTo(x - k * .3, y + k * .3); ctx.lineTo(x - k, y); ctx.lineTo(x - k * .3, y - k * .3); ctx.fill();
    }
  }

  function suelo() {
    poly([p(-.5, -.5), p(10.5, -.5), p(10.5, 9.2), p(-.5, 9.2)], '#E6F1FC');
    poly([p(-.5, 6.7), p(10.5, 6.7), p(10.5, 7.2), p(-.5, 7.2)], '#D2E1F2');
    poly([p(-.5, 7.2), p(10.5, 7.2), p(10.5, 8.5), p(-.5, 8.5)], '#5E6E85');
    for (let x = -.2; x < 10.4; x += 1.4) poly([p(x, 7.8), p(x + .7, 7.8), p(x + .7, 7.9), p(x, 7.9)], '#E9EEF5');
    poly([p(-.5, 8.5), p(10.5, 8.5), p(10.5, 9.2), p(-.5, 9.2)], '#D2E1F2');
  }
  function arbol(x, y, s) {
    const b = p(x, y), bal = Math.sin(t * 1.3 + x) * a * .03;
    ctx.fillStyle = '#8A6A4F'; ctx.fillRect(b[0] - a * .07 * s, b[1] - a * .5 * s, a * .14 * s, a * .5 * s);
    circ(b[0] + bal, b[1] - a * .8 * s, a * .42 * s, '#4FB286');
    circ(b[0] + bal - a * .14 * s, b[1] - a * .68 * s, a * .28 * s, '#6CC79D');
  }
  function paquete(base, s, limpio) {
    ctx.fillStyle = limpio ? '#fff' : '#C49A6C'; rrect(base[0] - s / 2, base[1] - s, s, s, s * .12); ctx.fill();
    ctx.strokeStyle = PRIMARY; ctx.lineWidth = s * .06; ctx.stroke();
    ctx.beginPath(); ctx.moveTo(base[0], base[1] - s); ctx.lineTo(base[0], base[1]); ctx.stroke();
  }
  function casa(d) {
    const x0 = .5, x1 = 2.5, y0 = 4.6, y1 = 6.4;
    caja(x0, y0, x1, y1, 0, 1.2, '#FFF4E0');
    enCaraY(x0, y1, 0, () => {
      ctx.fillStyle = PRIMARY; rrect(.35, -.75, .5, .75, .05); ctx.fill();
      ctx.fillStyle = '#BFE4FF'; rrect(1.15, -.85, .55, .4, .05); ctx.fill();
    });
    const apex = p((x0 + x1) / 2, (y0 + y1) / 2, 2.2);
    const e = [p(x0 - .15, y0 - .15, 1.2), p(x1 + .15, y0 - .15, 1.2), p(x1 + .15, y1 + .15, 1.2), p(x0 - .15, y1 + .15, 1.2)];
    poly([e[3], e[2], apex], '#E2705A'); poly([e[2], e[1], apex], sombra('#E2705A', .8));
    etiqueta('Tu casa', p((x0 + x1) / 2, y1 + .2, 2.9), a * .4);
    if (d.paquete) {
      const b = p(1.2, 7.0), reb = Math.abs(Math.sin(t * 3)) * a * .12;
      paquete([b[0], b[1] - reb], a * .6, true); brillos([b[0], b[1] - a * .6], a * .5);
    }
  }

  const LX0 = 4.4, LX1 = 9.7, LY0 = .6, LY1 = 6;
  function recepcion(d) {
    const y = 1.35, x0 = 4.8, x1 = 6.3;
    ctx.strokeStyle = '#7C8DA6'; ctx.lineWidth = a * .07; ctx.lineCap = 'round';
    const L = (A, B) => { ctx.beginPath(); ctx.moveTo(...A); ctx.lineTo(...B); ctx.stroke(); };
    L(p(x0, y), p(x0, y, 1.9)); L(p(x1, y), p(x1, y, 1.9)); L(p(x0, y, 1.9), p(x1, y, 1.9));
    const cols = ['#6C8CFF', '#FF8E72', '#46C2A5', '#F2B84B', '#B98BF2', '#58B7F0'];
    const n = Math.min(d.colgadas || 0, 6);
    for (let i = 0; i < n; i++) {
      const g = p(x0 + .2 + i * ((x1 - x0 - .3) / 5), y, 1.9), sw = Math.sin(t * 1.8 + i * 1.3) * a * .05;
      ctx.lineWidth = a * .03; L(g, [g[0] + sw * .4, g[1] + a * .25]);
      prenda([g[0] + sw, g[1] + a * .25], a * .5, cols[i % 6]);
    }
    if (d.mia && n > 0) marcador(p((x0 + x1) / 2, y, 2.9), 'Tu ropa');
  }
  function prenda(top, s, col) {
    const [x, y] = top;
    ctx.beginPath(); ctx.moveTo(x - s * .18, y); ctx.lineTo(x - s * .5, y + s * .2); ctx.lineTo(x - s * .36, y + s * .42); ctx.lineTo(x - s * .26, y + s * .34);
    ctx.lineTo(x - s * .26, y + s * .95); ctx.lineTo(x + s * .26, y + s * .95); ctx.lineTo(x + s * .26, y + s * .34); ctx.lineTo(x + s * .36, y + s * .42);
    ctx.lineTo(x + s * .5, y + s * .2); ctx.lineTo(x + s * .18, y); ctx.quadraticCurveTo(x, y + s * .14, x - s * .18, y); ctx.closePath();
    ctx.fillStyle = col; ctx.fill(); ctx.strokeStyle = sombra(col.length === 7 ? col : '#6C8CFF', .7); ctx.lineWidth = a * .025; ctx.stroke();
  }
  function maquina(d, x, y, tipo, idx) {
    const esLav = tipo === 'lavadora', W_ = 1.1, D = .95, Hh = 1.15;
    let activa;
    if (d.ciclo) { const lav = (t % 12) < 6; activa = idx === 0 && (esLav ? lav : !lav); }
    else activa = idx < (esLav ? (d.lavando || 0) : (d.secando || 0));
    caja(x, y, x + W_, y + D, 0, Hh, esLav ? '#FFFFFF' : '#F4F1EC');
    enCaraY(x, y + D, 0, () => {
      ctx.fillStyle = esLav ? '#8FC3F5' : '#F2B27A'; ctx.fillRect(0, -Hh + .02, W_, .22);
      circ(.2, -Hh + .13, .05, '#fff'); circ(.38, -Hh + .13, .05, '#fff'); circ(W_ - .2, -Hh + .13, .05, activa ? '#3DDC84' : '#B8C4D4');
      const cx = W_ / 2, cy = -.52;
      circ(cx, cy, .36, '#C9D6E6'); circ(cx, cy, .3, '#1E3350');
      ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, .3, 0, 7); ctx.clip();
      if (activa) {
        if (esLav) { const nv = cy + .08 + Math.sin(t * 3) * .03; ctx.fillStyle = 'rgba(91,182,255,.85)'; ctx.fillRect(cx - .3, nv, .6, .6); }
        else { ctx.fillStyle = 'rgba(255,176,103,.35)'; ctx.fillRect(cx - .3, cy - .3, .6, .6); }
        const giro = t * (esLav ? 5 : 7.5), cs = ['#FF8E72', '#F2B84B', '#6C8CFF', '#46C2A5'];
        for (let i = 0; i < 4; i++) { const an = giro + i * Math.PI / 2; circ(cx + Math.cos(an) * .14, cy + Math.sin(an) * .14, .085, cs[i]); }
      }
      ctx.restore();
      ctx.beginPath(); ctx.arc(cx, cy, .3, 0, 7); ctx.strokeStyle = '#9FB4CC'; ctx.lineWidth = .03; ctx.stroke();
    });
    if (activa) {
      const cima = p(x + W_ / 2, y + D / 2, Hh);
      if (esLav) for (let i = 0; i < 4; i++) {
        const ph = ((t * .7) + i * .25) % 1;
        circ(cima[0] + Math.sin(ph * 6 + i) * a * .3, cima[1] - ph * a * .9, a * (.07 + .04 * (i % 2)), `rgba(143,215,255,${(1 - ph) * .9})`);
      } else for (let i = 0; i < 3; i++) {
        const ph = ((t * .6) + i * .33) % 1, sx = cima[0] + (i - 1) * a * .25, sy = cima[1] - ph * a * .9;
        ctx.beginPath(); ctx.moveTo(sx, sy); ctx.bezierCurveTo(sx + a * .12, sy - a * .12, sx - a * .12, sy - a * .22, sx, sy - a * .34);
        ctx.strokeStyle = `rgba(255,154,90,${(1 - ph) * .8})`; ctx.lineWidth = a * .05; ctx.stroke();
      }
      if (d.mia && d.ciclo) marcador(p(x + W_ / 2, y + D / 2, Hh + 1), 'Tu ropa');
    }
  }
  function mesa(d) {
    const x0 = 4.9, x1 = 6.3, y0 = 3.9, y1 = 5.3;
    caja(x0, y0, x1, y1, 0, .7, '#E9D8BF');
    const n = Math.min(d.listas || 0, 4), cs = ['#7FB8F5', '#FFC6A8', '#B7E3C6', '#F7E49A'];
    for (let i = 0; i < n; i++) {
      const cx = x0 + .35 + (i % 2) * .65, cy = y0 + .35 + Math.floor(i / 2) * .65;
      for (let k = 0; k < 3; k++) caja(cx - .22, cy - .22, cx + .22, cy + .22, .7 + k * .1, .78 + k * .1, cs[(i + k) % 4]);
    }
    if (n > 0) { brillos(p((x0 + x1) / 2, (y0 + y1) / 2, 1.5), a * .5); if (d.mia) marcador(p((x0 + x1) / 2, (y0 + y1) / 2, 2.2), 'Tu ropa lista'); }
  }
  function lavanderia(d) {
    poly([p(LX0, LY0), p(LX1, LY0), p(LX1, LY1), p(LX0, LY1)], '#F7FBFF');
    ctx.strokeStyle = '#DCEAF8'; ctx.lineWidth = 1;
    for (let x = LX0; x <= LX1 + .01; x += .9) { ctx.beginPath(); ctx.moveTo(...p(x, LY0)); ctx.lineTo(...p(x, LY1)); ctx.stroke(); }
    for (let y = LY0; y <= LY1 + .01; y += .9) { ctx.beginPath(); ctx.moveTo(...p(LX0, y)); ctx.lineTo(...p(LX1, y)); ctx.stroke(); }
    caja(LX0 - .15, LY0 - .15, LX1 + .15, LY0, 0, 2.1, '#BFD9F5');
    caja(LX0 - .15, LY0 - .15, LX0, LY1 + .15, 0, 2.1, '#CFE3F8');
    [5.5, 7.4, 9].forEach(x => enCaraY(x, LY0, 1.1, () => {
      ctx.fillStyle = '#EAF6FF'; rrect(0, -.7, .9, .7, .06); ctx.fill();
      ctx.strokeStyle = '#8FC3F5'; ctx.lineWidth = .05; ctx.strokeRect(0, -.7, .9, .7);
    }));
    caja(LX0 - .15, LY1, LX1 + .15, LY1 + .15, 0, .18, '#9CBBDD');
    caja(LX1, LY0 - .15, LX1 + .15, LY1 + .15, 0, .18, '#9CBBDD');
    etiqueta(NOMBRE, p((LX0 + LX1) / 2, LY0, 3.4), a * .62);
    [[7, () => recepcion(d)], [8.9, () => maquina(d, 6.6, 1, 'lavadora', 0)], [10.1, () => maquina(d, 8, 1, 'lavadora', 1)],
     [10.7, () => maquina(d, 6.6, 3, 'secadora', 0)], [11.9, () => maquina(d, 8, 3, 'secadora', 1)], [10.2, () => mesa(d)]]
      .sort((x, y) => x[0] - y[0]).forEach(o => o[1]());
    const pu = p(7, LY1 + .45), fl = Math.sin(t * 4) * a * .08;
    ctx.fillStyle = 'rgba(47,127,224,.55)'; ctx.beginPath();
    ctx.moveTo(pu[0] - a * .25, pu[1] - a * .1 + fl); ctx.lineTo(pu[0] + a * .25, pu[1] - a * .1 + fl); ctx.lineTo(pu[0], pu[1] + a * .22 + fl); ctx.fill();
  }
  function moto(rol, prog) {
    const xC = 1.6, xL = 7, yC = 7.85; let x, dir = 1;
    if (rol === 'recogiendo') x = -1 + (xC + 1) * prog;
    else if (rol === 'llevando') x = xC + (xL - xC) * prog;
    else { x = xL - (xL - xC) * prog; dir = -1; }
    const b = p(x, yC), s = a * .95, reb = Math.sin(t * 14) * s * .012, dura = '#1E3350';
    ctx.save(); ctx.translate(b[0], b[1] + reb);
    ctx.fillStyle = 'rgba(0,0,0,.18)'; ctx.beginPath(); ctx.ellipse(0, s * .02, s * .85, s * .14, 0, 0, 7); ctx.fill();
    ctx.rotate(.4636); ctx.scale(dir, 1); ctx.scale(s, s);
    for (const wx of [-.55, .55]) {
      circ(wx, -.28, .28, dura); circ(wx, -.28, .12, '#C9D6E6');
      const r = t * 22 * dir; ctx.strokeStyle = dura; ctx.lineWidth = .04; ctx.beginPath();
      ctx.moveTo(wx + Math.cos(r) * .1, -.28 + Math.sin(r) * .1); ctx.lineTo(wx - Math.cos(r) * .1, -.28 - Math.sin(r) * .1); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(-.72, -.42); ctx.quadraticCurveTo(-.7, -.78, -.3, -.76); ctx.lineTo(.2, -.72); ctx.quadraticCurveTo(.5, -.7, .62, -.38);
    ctx.lineTo(.3, -.34); ctx.lineTo(-.2, -.3); ctx.closePath(); ctx.fillStyle = PRIMARY; ctx.fill();
    ctx.lineCap = 'round'; ctx.strokeStyle = dura; ctx.lineWidth = .07;
    ctx.beginPath(); ctx.moveTo(.5, -.5); ctx.lineTo(.42, -1.05); ctx.moveTo(.3, -1.08); ctx.lineTo(.52, -1.08); ctx.stroke();
    ctx.fillStyle = dura; rrect(-.62, -.88, .62, .14, .07); ctx.fill();
    const carga = rol !== 'recogiendo';
    ctx.fillStyle = carga ? (rol === 'devolviendo' ? '#fff' : '#C49A6C') : PRIMARY; rrect(-1, -1.36, .6, .5, .06); ctx.fill();
    ctx.strokeStyle = sombra(PRIMARY, .8); ctx.lineWidth = .03; ctx.stroke();
    if (rol === 'devolviendo') circ(-.7, -1.11, .1, '#3DDC84');
    ctx.strokeStyle = '#FF8E72'; ctx.lineWidth = .3; ctx.beginPath(); ctx.moveTo(-.12, -.82); ctx.lineTo(-.02, -1.42); ctx.stroke();
    ctx.lineWidth = .1; ctx.beginPath(); ctx.moveTo(.05, -1.25); ctx.lineTo(.42, -1.07); ctx.stroke();
    circ(0, -1.62, .17, '#F2C6A0');
    ctx.beginPath(); ctx.arc(0, -1.64, .2, Math.PI, 0); ctx.closePath(); ctx.fillStyle = '#F2B84B'; ctx.fill();
    circ(.62, -.62, .07, '#FFF3B0');
    ctx.restore();
  }

  function dibuja() {
    ctx.clearRect(0, 0, W, H);
    const d = CAPITULOS[cap][1], ancho = 21.2, alto = 11.6;
    a = Math.min(W / ancho, H / alto) * zoom;
    ox = W / 2 - .65 * a + panX; oy = (H - alto * a) / 2 + 1.1 * a + panY;
    suelo(); arbol(.2, 2.4, 1.1); arbol(2.6, .6, .9); arbol(3, 5.6, .8); arbol(10.1, 6.3, .9);
    casa(d); lavanderia(d);
    (d.motos || []).forEach(([rol]) => {
      const fase = (t % 7) / 7, prog = Math.min(fase / .85, 1);
      moto(rol, prog < .5 ? 2 * prog * prog : 1 - Math.pow(-2 * prog + 2, 2) / 2);
    });
    const chip = document.getElementById('escena-fase');
    if (chip) chip.textContent = d.ciclo ? ((t % 12) < 6 ? '💧 Lavando' : '🔥 Secando') : '';
  }
  let ult = performance.now(), visible = true;
  new IntersectionObserver(e => visible = e[0].isIntersecting).observe(cv);
  (function bucle(ahora) {
    t += Math.min((ahora - ult) / 1000, .1); ult = ahora;
    if (visible) dibuja();
    requestAnimationFrame(bucle);
  })(ult);
  if (reduce) { cap = 3; pintaCap(); }

  /* mover (arrastrar), zoom (botones / rueda con Ctrl) e inclinación 3D */
  const caja3d = cv.closest('.escena');
  let drag = null;
  cv.addEventListener('pointerdown', e => { drag = [e.clientX, e.clientY, panX, panY]; cv.setPointerCapture(e.pointerId); cv.classList.add('grab'); });
  cv.addEventListener('pointermove', e => { if (drag) { panX = drag[2] + e.clientX - drag[0]; panY = drag[3] + e.clientY - drag[1]; } });
  const fin = () => { drag = null; cv.classList.remove('grab'); };
  cv.addEventListener('pointerup', fin); cv.addEventListener('pointercancel', fin);
  cv.addEventListener('dblclick', () => { zoom = 1; panX = panY = 0; });
  cv.addEventListener('wheel', e => { if (e.ctrlKey) { e.preventDefault(); zoom = Math.min(3, Math.max(1, zoom * (e.deltaY < 0 ? 1.1 : .9))); } }, { passive: false });
  document.querySelectorAll('[data-zoom]').forEach(b => b.addEventListener('click', () => {
    const k = b.dataset.zoom; if (k === '0') { zoom = 1; panX = panY = 0; } else { const nz = Math.min(3, Math.max(1, zoom * (k === '+' ? 1.25 : .8))), r = nz / zoom; panX *= r; panY *= r; zoom = nz; if (zoom === 1) panX = panY = 0; }
  }));
  if (caja3d && !reduce) {
    caja3d.addEventListener('pointermove', e => {
      if (e.pointerType === 'touch') return;
      const r = caja3d.getBoundingClientRect();
      caja3d.style.setProperty('--ry', (((e.clientX - r.left) / r.width) - .5) * 10 + 'deg');
      caja3d.style.setProperty('--rx', (-(((e.clientY - r.top) / r.height) - .5)) * 8 + 'deg');
    });
    caja3d.addEventListener('pointerleave', () => { caja3d.style.setProperty('--ry', '0deg'); caja3d.style.setProperty('--rx', '0deg'); });
  }
})();
