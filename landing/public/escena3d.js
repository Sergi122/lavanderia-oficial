/* Ciudad en miniatura (Three.js): casa → calles → lavandería con interior, autos y moto repartidora.
   Una sola escena para la landing, el inicio del cliente y el panel del admin.
   API: const e = crearEscena(div); e.set(datos); e.explorar(bool); e.zoom(f); e.reset(); e.destruir();
   datos = { colgadas, lavando, secando, listas, ciclo, motos:[{rol:'recogiendo'|'llevando'|'devolviendo', progreso?}],
             paquete, destacarMia, nombre, foco:'auto'|'general'|'lavanderia'|'casa' } */
import * as THREE from 'three';
import { OrbitControls } from './vendor/OrbitControls.js';

const C = { azul: 0x2f7fe0, agua: 0x8fd7ff, tinta: 0x0a1c33 };
const PERIODO_CICLO = 12, VEL_MOTO = 2.8, PAUSA_MOTO = 1.4;
const lerp = (a, b, t) => a + (b - a) * t;
const ease = (t) => (t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);

/* ───────── rutas (centros de calle, coordenadas x,z) ───────── */
/* Casas de clientes (una por pedido en el panel del admin). Todas miran a +z; "P" es el punto de la calle frente a la puerta. */
const SLOTS = [
  { casa: null, door: [2.2, 9.9], P: [2.2, 11.6] },                           // 0: "Tu casa"
  { casa: [13.2, 8.6, 14.8, 10.2], door: [14.0, 10.35], P: [14.0, 11.6] },
  { casa: [19.6, 8.6, 21.2, 10.2], door: [20.4, 10.35], P: [20.4, 11.6] },
  { casa: [7.4, 14.6, 9.0, 16.2], door: [8.2, 16.35], P: [8.2, 17.7] },
  { casa: [13.4, 14.6, 15.0, 16.2], door: [14.2, 16.35], P: [14.2, 17.7] },
  { casa: [1.2, 14.6, 2.8, 16.2], door: [2.0, 16.35], P: [2.0, 17.7] },
  { casa: [19.6, 3.0, 21.2, 4.6], door: [20.4, 4.75], P: [20.4, 6.0] },
  { casa: [7.4, 3.0, 9.0, 4.6], door: [8.2, 4.75], P: [8.2, 6.0] },
  { casa: [25.8, 8.6, 27.4, 10.2], door: [26.6, 10.35], P: [26.6, 11.6] },
  { casa: [19.6, 14.6, 21.2, 16.2], door: [20.4, 16.35], P: [20.4, 17.7] },
  { casa: [13.4, 20.8, 15.0, 22.4], door: [14.2, 22.55], P: [14.2, 24.0] },
  { casa: [7.4, 20.8, 9.0, 22.4], door: [8.2, 22.55], P: [8.2, 24.0] },
];
const LARGA0 = [[2.2, 9.9], [2.2, 11.6], [11.4, 11.6], [11.4, 17.7], [23.8, 17.7], [23.8, 6.0], [14.0, 6.0], [14.0, 5.5]];   // recorrido largo por la ciudad
const RUTA_LLEGADA = [[-1.4, 11.6], [2.2, 11.6], [2.2, 9.9]];
function puntosSlot(s) {
  const [dx, dz] = s.door, [px, pz] = s.P;
  const pts = Math.abs(pz - 6.0) < .1 ? [[dx, dz], [px, pz], [14.0, 6.0], [14.0, 5.5]]
    : [[dx, dz], [px, pz], [11.4, pz], [11.4, 6.0], [14.0, 6.0], [14.0, 5.5]];
  return pts.filter((p, i) => !i || Math.hypot(p[0] - pts[i - 1][0], p[1] - pts[i - 1][1]) > .01);
}

/** Polilínea con esquinas redondeadas, muestreada densa, con longitudes acumuladas. */
function ruta(pts, r = .55) {
  const out = [];
  const push = (x, z) => out.push([x, z]);
  push(...pts[0]);
  for (let i = 1; i < pts.length - 1; i++) {
    const [ax, az] = pts[i - 1], [bx, bz] = pts[i], [cx, cz] = pts[i + 1];
    const l1 = Math.hypot(bx - ax, bz - az), l2 = Math.hypot(cx - bx, cz - bz);
    const rr = Math.min(r, l1 / 2, l2 / 2);
    const p1 = [bx - (bx - ax) / l1 * rr, bz - (bz - az) / l1 * rr];
    const p2 = [bx + (cx - bx) / l2 * rr, bz + (cz - bz) / l2 * rr];
    for (let k = 0; k <= 8; k++) {
      const t = k / 8, u = 1 - t;
      push(u * u * p1[0] + 2 * u * t * bx + t * t * p2[0], u * u * p1[1] + 2 * u * t * bz + t * t * p2[1]);
    }
  }
  push(...pts[pts.length - 1]);
  const acum = [0];
  for (let i = 1; i < out.length; i++) acum.push(acum[i - 1] + Math.hypot(out[i][0] - out[i - 1][0], out[i][1] - out[i - 1][1]));
  return { pts: out, acum, largo: acum[acum.length - 1] };
}
function enRuta(R, t, lado = 0) {
  const s = Math.min(Math.max(t, 0), 1) * R.largo;
  let i = 1;
  while (i < R.acum.length - 1 && R.acum[i] < s) i++;
  const [ax, az] = R.pts[i - 1], [bx, bz] = R.pts[i];
  const seg = R.acum[i] - R.acum[i - 1] || 1, k = (s - R.acum[i - 1]) / seg;
  let tx = bx - ax, tz = bz - az; const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
  return { x: lerp(ax, bx, k) + -tz * lado, z: lerp(az, bz, k) + tx * lado, tx, tz };
}
const cacheRutas = new Map();
/** Ruta (densa, con longitudes) de una moto según su rol y la casa del pedido. */
function rutaDe(rol, slot = 0, larga = false) {
  const k = `${rol}:${slot}:${larga}`;
  if (!cacheRutas.has(k)) {
    const fwd = larga && slot === 0 ? LARGA0 : puntosSlot(SLOTS[slot] || SLOTS[0]);
    const rev = [...fwd].reverse();
    cacheRutas.set(k, rol === 'llevando' ? ruta(fwd) : rol === 'devolviendo' ? ruta(rev)
      : (larga || slot !== 0 ? ruta(rev) : ruta(RUTA_LLEGADA, .4)));
  }
  return cacheRutas.get(k);
}

/* ───────── texturas de ventanas (una por color; la repetición va en los UV de cada caja) ───────── */
const cacheTex = new Map(), cacheMat = new Map();
function texVentanas(base, variante) {
  const k = base + ':' + variante;
  if (cacheTex.has(k)) return cacheTex.get(k);
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = '#' + base.toString(16).padStart(6, '0'); g.fillRect(0, 0, 128, 128);
  g.fillStyle = 'rgba(0,0,0,.07)'; g.fillRect(0, 116, 128, 12);
  g.fillStyle = 'rgba(255,255,255,.18)'; g.fillRect(0, 0, 128, 6);
  const lit = variante === 1;
  g.fillStyle = lit ? '#ffe9a8' : '#9fc7ee'; g.beginPath(); g.roundRect(30, 26, 68, 62, 7); g.fill();
  g.fillStyle = lit ? '#ffd47a' : '#7fb0e3'; g.fillRect(30, 26, 68, 18);
  g.strokeStyle = 'rgba(255,255,255,.8)'; g.lineWidth = 3.5; g.strokeRect(30, 26, 68, 62); g.beginPath(); g.moveTo(64, 26); g.lineTo(64, 88); g.stroke();
  g.fillStyle = 'rgba(255,255,255,.3)'; g.fillRect(34, 30, 18, 54);
  g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(24, 90, 80, 6);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 4;
  cacheTex.set(k, t);
  return t;
}
function matVentanas(base, variante) {
  const k = base + ':' + variante;
  if (!cacheMat.has(k)) cacheMat.set(k, new THREE.MeshStandardMaterial({ map: texVentanas(base, variante), roughness: .85 }));
  return cacheMat.get(k);
}
/** Caja cuyas 4 caras laterales repiten la ventana `cols`×`rows` veces. */
function cajaVentanas(w, h, d, colsX, colsZ, rows) {
  const geo = new THREE.BoxGeometry(w, h, d), uv = geo.attributes.uv;
  for (let f = 0; f < 6; f++) {
    const [su, sv] = f < 2 ? [colsZ, rows] : f < 4 ? [1, 1] : [colsX, rows];
    for (let v = f * 4; v < f * 4 + 4; v++) uv.setXY(v, uv.getX(v) * su, uv.getY(v) * sv);
  }
  return geo;
}
function prng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

export function crearEscena(cont, opciones = {}) {
  const movil = matchMedia('(max-width:700px)').matches || opciones.ligero;
  const anilloFuera = !!opciones.ligero;
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, movil ? 1.5 : 2));
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.08;
  renderer.domElement.style.cssText = 'display:block;width:100%;height:100%;touch-action:pan-y';
  cont.appendChild(renderer.domElement);
  const etiquetas = document.createElement('div');
  etiquetas.style.cssText = 'position:absolute;inset:0;pointer-events:none;overflow:hidden;font:700 12px Geist,system-ui,sans-serif';
  if (getComputedStyle(cont).position === 'static') cont.style.position = 'relative';
  cont.appendChild(etiquetas);

  const scene = new THREE.Scene();
  const CIELO = 0xcfe6fb;
  scene.background = new THREE.Color(CIELO);
  scene.fog = new THREE.Fog(CIELO, 120, 260);
  const camera = new THREE.PerspectiveCamera(24, 1.8, .5, 600);

  scene.add(new THREE.HemisphereLight(0xffffff, 0xa7c4e6, 1.0));
  const sol = new THREE.DirectionalLight(0xfff1d6, 2.6);
  sol.position.set(24, 30, 10); sol.target.position.set(8.2, 0, 8.2);
  sol.castShadow = true; sol.shadow.mapSize.set(movil ? 1024 : 2048, movil ? 1024 : 2048);
  Object.assign(sol.shadow.camera, { left: -22, right: 22, top: 22, bottom: -22, near: 1, far: 110 });
  sol.shadow.bias = -.0004; sol.shadow.normalBias = .03;
  scene.add(sol, sol.target);

  const M = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: .8, ...extra });
  const sombrear = (o) => { o.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } }); return o; };
  function caja(w, h, d, color, x, y, z, padre = scene) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), color.isMaterial || Array.isArray(color) ? color : M(color));
    m.position.set(x, y, z); m.castShadow = m.receiveShadow = true; padre.add(m); return m;
  }

  /* ───────── suelo, manzanas, calles ───────── */
  const RX = [[-7.4, -1.8], [-.6, 5.4], [6.6, 10.8], [12, 17], [18.2, 23.2], [24.4, 29.4]];
  const RZ = [[-7.4, -1.8], [-.6, 5.4], [6.6, 11], [12.2, 17], [18.4, 23.4], [24.6, 29.6]];
  const CX = [-1.2, 6.0, 11.4, 17.6, 23.8], CZ = [-1.2, 6.0, 11.6, 17.7, 24.0];   // centros de calles
  const LX = RX[0][0] - .5, HX = RX[RX.length - 1][1] + .5, LZ = RZ[0][0] - .5, HZ = RZ[RZ.length - 1][1] + .5;
  const MIDX = (LX + HX) / 2, MIDZ = (LZ + HZ) / 2, ANCHOX = HX - LX, ANCHOZ = HZ - LZ;
  caja(ANCHOX + 1, .5, ANCHOZ + 1, 0xe7eff8, MIDX, -.31, MIDZ);
  caja(ANCHOX + 1, .12, ANCHOZ + 1, 0xbcd3ee, MIDX, -.62, MIDZ);
  const calleCol = 0x55657c;
  RX.slice(0, -1).forEach(([, e], i) => { const a = e, b = RX[i + 1][0]; caja(b - a, .06, ANCHOZ, calleCol, (a + b) / 2, .03, MIDZ); });
  RZ.slice(0, -1).forEach(([, e], i) => { const a = e, b = RZ[i + 1][0]; caja(ANCHOX, .06, b - a, calleCol, MIDX, .031, (a + b) / 2); });
  const lineaMat = M(0xe9eef5), aceraMat = M(0xdbe6f2), parqueMat = M(0xbfe3c6), tileMat = M(0xf2f7fc);
  const rand = prng(7);
  const SLOT_BLOQUES = new Set(['3,2', '4,2', '2,3', '3,3', '1,3', '4,1', '2,1', '5,2', '4,3', '3,4', '2,4']);
  const especial = (i, j) => (i === 3 && j === 1) /*laundry*/ || (i === 1 && j === 2) /*casa*/ || (i === 2 && j === 2) /*parque*/;
  // manzanas con borde (cordón) y los casos especiales
  RX.forEach(([x0, x1], i) => RZ.forEach(([z0, z1], j) => {
    if (anilloFuera && (i === 0 || j === 0 || i === RX.length - 1 || j === RZ.length - 1)) return;
    const parque = (i === 2 && j === 2) || (i === 4 && j === 4);
    caja(x1 - x0 + .16, .1, z1 - z0 + .16, aceraMat, (x0 + x1) / 2, .05, (z0 + z1) / 2).castShadow = false;
    caja(x1 - x0, .06, z1 - z0, parque ? parqueMat : tileMat, (x0 + x1) / 2, .13, (z0 + z1) / 2).castShadow = false;
  }));
  // líneas de carril, cebras
  for (const c of CZ) for (let x = LX + .4; x < HX; x += 1.5) caja(.7, .02, .08, lineaMat, x, .075, c);
  for (const c of CX) for (let z = LZ + .4; z < HZ; z += 1.5) caja(.08, .02, .7, lineaMat, c, .076, z);
  for (const cx of CX) for (const cz of CZ) {
    for (let k = -2; k <= 2; k++) { caja(.1, .02, .5, lineaMat, cx + k * .2, .08, cz - .95); caja(.5, .02, .1, lineaMat, cx - .95, .08, cz + k * .2); }
  }

  /* ───────── edificios procedurales (altos al fondo, bajos hacia la cámara) ───────── */
  const animables = [];
  const PALETA = [0xf4c9a8, 0xbfd9f5, 0xf7e49a, 0xcfe9d8, 0xc9b8f0, 0xb7e3c6, 0xf2b8a0, 0xa9d3f2, 0xfbe3c4, 0xe7c6e8, 0xd6e8b5, 0xf5d0c5];
  const TOLDOS = [0xe2705a, 0x2f7fe0, 0x46c2a5, 0xf2b84b, 0xb98bf2];
  const techoMat = M(0xdfe8f2), parapetoMat = M(0xcfdbe9), equipoMat = M(0xb8c6d8), tanqueMat = M(0x9fb1c8);
  function edificio(x0, z0, x1, z1, h, color, r) {
    const w = x1 - x0, d = z1 - z0, rows = Math.max(1, Math.round(h / .95));
    const colsX = Math.max(1, Math.round(w / 1.05)), colsZ = Math.max(1, Math.round(d / 1.05));
    const mv = matVentanas(color, r() < .22 ? 1 : 0);
    const m = new THREE.Mesh(cajaVentanas(w, h, d, colsX, colsZ, rows), [mv, mv, techoMat, techoMat, mv, mv]);
    m.position.set((x0 + x1) / 2, .16 + h / 2, (z0 + z1) / 2); m.castShadow = m.receiveShadow = true; scene.add(m);
    caja(w + .14, .1, d + .14, parapetoMat, m.position.x, .16 + h + .05, m.position.z);
    const cx = (x0 + x1) / 2, cz = (z0 + z1) / 2, yTop = .16 + h + .1;
    const sorteo = r();
    if (h > 2.6 && sorteo < .4) { const t = new THREE.Mesh(new THREE.CylinderGeometry(.28, .28, .55, 12), tanqueMat); t.position.set(x0 + w * .3, yTop + .3, z0 + d * .35); t.castShadow = true; scene.add(t); caja(.05, .3, .05, equipoMat, t.position.x, yTop + .02, t.position.z); }
    else if (h > 1.6 && sorteo < .75) { caja(.5, .3, .4, equipoMat, x0 + w * .3, yTop + .15, z0 + d * .4); if (w > 1.6) caja(.4, .26, .36, equipoMat, x0 + w * .7, yTop + .13, z0 + d * .6); }
    else if (h > 3.2) { caja(.04, 1.0, .04, 0x7c8da6, cx, yTop + .5, cz); }
    // local con toldo en la cara que ve la cámara (+z)
    if (h < 3.4 && r() < .6) {
      const col = TOLDOS[Math.floor(r() * TOLDOS.length)];
      const tol = caja(Math.min(w - .3, 1.6), .06, .5, col, cx, .16 + .85, z1 + .22); tol.rotation.x = .35;
      caja(Math.min(w - .5, 1.3), .5, .04, 0xffe9c0, cx, .16 + .5, z1 + .02);
    }
    return m;
  }
  /** Parte una manzana en 2–4 lotes y levanta un edificio en cada uno. */
  function manzana(x0, z0, x1, z1, i, j) {
    const r = prng(1000 + i * 31 + j * 17), m = .6;
    const cerca = (((x0 + x1) / 2 - LX) / (HX - LX) + ((z0 + z1) / 2 - LZ) / (HZ - LZ)) / 2;           // 0 fondo … 1 cerca de la cámara
    const hMax = lerp(7.6, 1.3, Math.pow(cerca, .45)), hMin = Math.max(1.0, hMax * .38);
    const nx = (x1 - x0) > 4.3 ? 2 : 1, nz = (z1 - z0) > 4.3 ? 2 : 1;
    for (let a = 0; a < nx; a++) for (let b = 0; b < nz; b++) {
      const lx0 = x0 + m + a * (x1 - x0 - 2 * m) / nx + (a ? .25 : 0), lx1 = x0 + m + (a + 1) * (x1 - x0 - 2 * m) / nx - (a < nx - 1 ? .25 : 0);
      const lz0 = z0 + m + b * (z1 - z0 - 2 * m) / nz + (b ? .25 : 0), lz1 = z0 + m + (b + 1) * (z1 - z0 - 2 * m) / nz - (b < nz - 1 ? .25 : 0);
      if (r() < .12) { arbol((lx0 + lx1) / 2, (lz0 + lz1) / 2, 1.2); continue; }
      edificio(lx0, lz0, lx1, lz1, lerp(hMin, hMax, r()), PALETA[Math.floor(r() * PALETA.length)], r);
    }
  }

  /* ───────── árboles (instanciados), farolas, peatones ───────── */
  const arbolesPos = [];
  function arbol(x, z, s = 1) { arbolesPos.push([x, z, s]); }
  function construirArboles() {
    const n = arbolesPos.length; if (!n) return;
    const tronco = new THREE.InstancedMesh(new THREE.CylinderGeometry(.07, .09, .6, 6), M(0x8a6a4f), n);
    const f1 = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(.55, 1), M(0xffffff, { flatShading: true }), n);
    const f2 = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(.38, 1), M(0xffffff, { flatShading: true }), n);
    const mtx = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3(), pos = new THREE.Vector3(), col = new THREE.Color();
    const verdes = [0x4fb286, 0x5cc08f, 0x3fa57a, 0x6cc79d], r = prng(99);
    arbolesPos.forEach(([x, z, s], i) => {
      sc.setScalar(s);
      pos.set(x, .44 * s + .14, z); tronco.setMatrixAt(i, mtx.compose(pos, q, sc));
      pos.set(x, (1.15 * s) + .14, z); f1.setMatrixAt(i, mtx.compose(pos, q, sc));
      pos.set(x + .2 * s, (1.55 * s) + .14, z + .05); f2.setMatrixAt(i, mtx.compose(pos, q, sc));
      col.setHex(verdes[Math.floor(r() * verdes.length)]); f1.setColorAt(i, col); col.offsetHSL(0, 0, .06); f2.setColorAt(i, col);
    });
    for (const o of [tronco, f1, f2]) { o.castShadow = true; o.receiveShadow = true; scene.add(o); }
  }
  const farolaMat = M(0xfff2b0, { emissive: 0xffe08a, emissiveIntensity: .8 });
  const postes = [];
  function farola(x, z) { postes.push([x, z]); }
  function construirFarolas() {
    const n = postes.length; if (!n) return;
    const palo = new THREE.InstancedMesh(new THREE.CylinderGeometry(.035, .045, 1.5, 6), M(0x6b7a90), n);
    const luz = new THREE.InstancedMesh(new THREE.SphereGeometry(.13, 10, 8), farolaMat, n);
    const m4 = new THREE.Matrix4();
    postes.forEach(([x, z], i) => { palo.setMatrixAt(i, m4.makeTranslation(x, .9, z)); luz.setMatrixAt(i, m4.makeTranslation(x, 1.68, z)); });
    scene.add(palo, luz);
  }

  RX.forEach(([x0, x1], i) => RZ.forEach(([z0, z1], j) => {
    if (anilloFuera && (i === 0 || j === 0 || i === RX.length - 1 || j === RZ.length - 1)) return;
    if (especial(i, j)) return;
    if ((i === 4 && j === 4)) { for (let k = 0; k < 9; k++) arbol(x0 + 1 + (k % 3) * 1.7 + rand() * .5, z0 + 1 + Math.floor(k / 3) * 1.7 + rand() * .5, 1 + rand() * .4); return; }
    manzana(x0, z0, x1, SLOT_BLOQUES.has(`${i},${j}`) ? z1 - 2.7 : z1, i, j);
  }));
  // árboles de acera y farolas en cada calle
  RX.forEach(([x0, x1], i) => RZ.forEach(([z0, z1], j) => {
    if (anilloFuera && (i === 0 || j === 0 || i === RX.length - 1 || j === RZ.length - 1)) return;
    for (let k = 1; k < 4; k++) { if (rand() < .6) arbol(x0 + .3 + (x1 - x0 - .6) * k / 4, z1 - .25, .75 + rand() * .3); if (rand() < .5) arbol(x1 - .25, z0 + .3 + (z1 - z0 - .6) * k / 4, .75 + rand() * .3); }
    farola(x1 - .1, z1 - .1); farola(x0 + .1, z1 - .1);
  }));
  // parque central: estanque, árboles y bancas
  [[7.2, 7.2, 1.2], [9.4, 7.0, 1], [8.0, 10.3, 1.3], [10.2, 10.2, 1], [7.0, 9.6, .9], [10.2, 8.2, 1]].forEach((p) => arbol(...p));
  const estanque = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, .06, 32), M(0x7cc2ff, { roughness: .15, metalness: .1 }));
  estanque.position.set(8.6, .18, 8.5); estanque.receiveShadow = true; scene.add(estanque);
  caja(.5, .18, .2, 0x8a6a4f, 8.6, .27, 10.1); caja(.5, .18, .2, 0x8a6a4f, 6.9, .27, 8.6);

  // alrededores de la casa
  caja(1.4, 1.1, 1.3, 0xfbe3c4, 4.5, .7, 8.4); { const t = new THREE.Mesh(new THREE.ConeGeometry(1.1, .7, 4), M(0xc96a55)); t.rotation.y = Math.PI / 4; t.position.set(4.5, 1.6, 8.4); t.castShadow = true; scene.add(t); }
  arbol(-.3, 10.4, 1.1); arbol(5.0, 10.4, .9); arbol(.6, 7.2, 1);
  // alrededores de la lavandería
  arbol(12.3, 5.0, .9); arbol(16.8, 5.1, 1); arbol(17.0, 1.0, 1); arbol(11.9, 2.0, .8);
  construirArboles(); construirFarolas();

  // autos estacionados (instanciados) junto a los cordones
  {
    const libres = [];
    for (const c of CZ) for (let x = LX + 1; x < HX - 1; x += 2.2 + rand() * 2) if (rand() < .55) libres.push([x, c + (rand() < .5 ? -.52 : .52), 0]);
    for (const c of CX) for (let z = LZ + 1; z < HZ - 1; z += 2.2 + rand() * 2) if (rand() < .55) libres.push([c + (rand() < .5 ? -.52 : .52), z, 1]);
    const ok = libres.filter(([x, z]) => !(x > 1 && x < 3.4 && z > 11 && z < 12.2));
    const cuerpo = new THREE.InstancedMesh(new THREE.BoxGeometry(1, .3, .5), M(0xffffff), ok.length), cab = new THREE.InstancedMesh(new THREE.BoxGeometry(.52, .24, .44), M(0xcfe8ff), ok.length);
    const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), p = new THREE.Vector3(), sc = new THREE.Vector3(1, 1, 1), col = new THREE.Color();
    const cs = [0xe2705a, 0xf2b84b, 0x46c2a5, 0xb98bf2, 0xffffff, 0x2f7fe0, 0xff8e72];
    ok.forEach(([x, z, eje], i) => {
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), eje ? Math.PI / 2 : 0);
      p.set(x, .31, z); cuerpo.setMatrixAt(i, m4.compose(p, q, sc)); p.set(x, .55, z); cab.setMatrixAt(i, m4.compose(p, q, sc)); cuerpo.setColorAt(i, col.setHex(cs[i % cs.length]));
    });
    cuerpo.castShadow = cab.castShadow = true; scene.add(cuerpo, cab);
  }
  // semáforos en las intersecciones
  const semaforos = [];
  for (const cx of CX.slice(1, 4)) for (const cz of CZ.slice(1, 4)) {
    const g = new THREE.Group(); caja(.05, 1.4, .05, 0x4a5568, 0, .85, 0, g);
    const verde = new THREE.Mesh(new THREE.SphereGeometry(.07, 8, 8), new THREE.MeshBasicMaterial({ color: 0x3ddc84 })); verde.position.set(.07, 1.5, 0);
    const rojo = new THREE.Mesh(new THREE.SphereGeometry(.07, 8, 8), new THREE.MeshBasicMaterial({ color: 0xff4d4d })); rojo.position.set(.07, 1.68, 0);
    g.add(verde, rojo); g.position.set(cx + .7, 0, cz + .7); scene.add(g); semaforos.push({ verde, rojo, off: (cx + cz) % 4 });
  }
  // peatones
  const peatones = [];
  for (let k = 0; k < (movil ? 8 : 26); k++) {
    const g = new THREE.Group(), c = [0xff8e72, 0x6c8cff, 0x46c2a5, 0xf2b84b, 0xb98bf2][k % 5];
    const cu = new THREE.Mesh(new THREE.CapsuleGeometry(.07, .22, 4, 8), M(c)); cu.position.y = .34; g.add(cu);
    const ca = new THREE.Mesh(new THREE.SphereGeometry(.07, 8, 8), M(0xf2c6a0)); ca.position.y = .62; g.add(ca);
    sombrear(g); scene.add(g);
    const horiz = rand() < .5, linea = (horiz ? CZ : CX)[1 + Math.floor(rand() * 3)] + (rand() < .5 ? -.78 : .78);
    peatones.push({ g, horiz, linea, u: rand(), v: .02 + rand() * .035, dir: rand() < .5 ? 1 : -1 });
  }

  /* ───────── casa ───────── */
  const casa = new THREE.Group();
  caja(2.4, 1.3, 2.0, 0xfff1d8, 2.2, .8, 8.6, casa);
  const tejado = new THREE.Mesh(new THREE.ConeGeometry(2.05, 1.05, 4), M(0xe2705a)); tejado.rotation.y = Math.PI / 4; tejado.scale.set(1.12, 1, .95); tejado.position.set(2.2, 1.95, 8.6); casa.add(tejado);
  caja(.5, .85, .06, C.azul, 1.7, .56, 9.62, casa); caja(.6, .45, .06, 0xbfe4ff, 2.8, .95, 9.62, casa);
  caja(.22, .5, .22, 0xc96a55, 2.9, 2.2, 8.2, casa);
  scene.add(sombrear(casa));
  const paquete = new THREE.Group();
  caja(.5, .45, .5, 0xffffff, 0, .22, 0, paquete); caja(.52, .06, .08, C.azul, 0, .45, 0, paquete); caja(.08, .46, .52, C.azul, 0, .23, 0, paquete);
  paquete.scale.setScalar(1.5); paquete.position.set(1.9, .14, 10.3); sombrear(paquete); paquete.visible = false; scene.add(paquete);
  function crearPaquete() {
    const g = new THREE.Group();
    caja(.5, .45, .5, 0xffffff, 0, .22, 0, g); caja(.52, .06, .08, C.azul, 0, .45, 0, g); caja(.08, .46, .52, C.azul, 0, .23, 0, g);
    g.scale.setScalar(1.3); sombrear(g); g.visible = false; scene.add(g); return g;
  }
  function crearBolsa(color) {
    const g = new THREE.Group();
    caja(.34, .36, .22, color, 0, .2, 0, g); caja(.2, .05, .05, 0x6b4f33, 0, .44, 0, g);
    g.scale.setScalar(1.25); sombrear(g); g.visible = false; scene.add(g); return g;
  }
  const COL_TEJADO = [0xe2705a, 0x2f7fe0, 0x46c2a5, 0xf2b84b, 0xb98bf2, 0xff8e72, 0x6c8cff, 0xe2705a, 0x46c2a5, 0xf2b84b, 0xb98bf2, 0x2f7fe0];
  const COL_PARED = [0xfff1d8, 0xfbe3c4, 0xe9f3ff, 0xf3fbe9, 0xffeef0, 0xfff5d6, 0xeaf6ff, 0xfdf0e0, 0xfbe3c4, 0xe9f3ff, 0xf3fbe9, 0xffeef0];
  /** Estado por casa: bolsa de ropa (sucia/limpia) frente a la puerta, paquete entregado y posición para su etiqueta. */
  const casasSlot = SLOTS.map((sl, i) => {
    if (i > 0) {
      const [x0, z0, x1, z1] = sl.casa, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2, g = new THREE.Group();
      caja(x1 - x0, 1.0, z1 - z0, COL_PARED[i], cx, .66, cz, g);
      const t = new THREE.Mesh(new THREE.ConeGeometry((x1 - x0) * .86, .8, 4), M(COL_TEJADO[i])); t.rotation.y = Math.PI / 4; t.position.set(cx, 1.55, cz); g.add(t);
      caja(.34, .62, .05, C.azul, sl.door[0], .45, z1 + .03, g); caja(.34, .3, .05, 0xbfe4ff, x0 + .3, .85, z1 + .03, g);
      scene.add(sombrear(g));
    }
    const sucia = crearBolsa(0xc49a6c), limpia = crearBolsa(0xffffff), pq = i === 0 ? paquete : crearPaquete();
    const dz = i === 0 ? 10.35 : sl.door[1] + .55, dx = i === 0 ? 1.9 : sl.door[0] + .5;
    sucia.position.set(dx, .14, dz); limpia.position.set(dx, .14, dz); if (i > 0) pq.position.set(dx, .14, dz);
    return { sucia, limpia, pq, label: new THREE.Vector3(i === 0 ? 2.2 : (sl.casa[0] + sl.casa[2]) / 2, i === 0 ? 2.9 : 2.1, i === 0 ? 8.6 : (sl.casa[1] + sl.casa[3]) / 2) };
  });

  /* ───────── lavandería ───────── */
  const LX0 = 12, LX1 = 16.4, LZ0 = .8, LZ1 = 5.2, WH = 2.3;
  const lav = new THREE.Group(); scene.add(lav);
  caja(LX1 - LX0, .12, LZ1 - LZ0, 0xf7fbff, (LX0 + LX1) / 2, .2, (LZ0 + LZ1) / 2, lav);
  // baldosas
  const tilesMat = M(0xdcebf9);
  for (let x = LX0 + .9; x < LX1; x += .9) caja(.02, .01, LZ1 - LZ0, tilesMat, x, .265, (LZ0 + LZ1) / 2, lav);
  for (let z = LZ0 + .9; z < LZ1; z += .9) caja(LX1 - LX0, .01, .02, tilesMat, (LX0 + LX1) / 2, .266, z, lav);
  const paredMat = () => M(0xbfd9f5), paredMat2 = () => M(0xd3e5f8);
  caja(LX1 - LX0 + .2, WH, .16, paredMat(), (LX0 + LX1) / 2, .14 + WH / 2, LZ0 - .08, lav);
  caja(.16, WH, LZ1 - LZ0 + .2, paredMat2(), LX0 - .08, .14 + WH / 2, (LZ0 + LZ1) / 2, lav);
  for (const x of [12.9, 14.3, 15.6]) caja(.7, .6, .04, 0xeaf6ff, x, 1.5, LZ0 + .03, lav);
  // frentes (se desvanecen al mirar el interior)
  const frentes = new THREE.Group(), techoG = new THREE.Group(); lav.add(frentes, techoG);
  const mf = () => new THREE.MeshStandardMaterial({ color: 0xcfe3f7, roughness: .8, transparent: true });
  const cristal = () => new THREE.MeshStandardMaterial({ color: 0xaad8ff, roughness: .1, transparent: true, opacity: .55 });
  caja(1.55, WH, .16, mf(), 12.9, .14 + WH / 2, LZ1 + .08, frentes); caja(1.9, WH, .16, mf(), 15.45, .14 + WH / 2, LZ1 + .08, frentes);
  caja(.9, .55, .16, mf(), 14.0, .14 + WH - .27, LZ1 + .08, frentes);
  caja(.16, WH, LZ1 - LZ0 + .2, mf(), LX1 + .08, .14 + WH / 2, (LZ0 + LZ1) / 2, frentes);
  for (const z of [1.9, 3.4]) caja(.05, .8, .9, cristal(), LX1 + .17, 1.2, z, frentes);
  caja(.04, .9, .8, cristal(), 12.9, 1.0, LZ1 + .17, frentes);
  const techoM = () => new THREE.MeshStandardMaterial({ color: 0x6fa6e0, roughness: .6, transparent: true });
  caja(LX1 - LX0 + .5, .16, LZ1 - LZ0 + .5, techoM(), (LX0 + LX1) / 2, .14 + WH + .08, (LZ0 + LZ1) / 2, techoG);
  const cartel = new THREE.Mesh(new THREE.BoxGeometry(3.4, .8, .12), M(0xffffff));
  cartel.position.set(14.2, .14 + WH + .75, LZ1 + .15); lav.add(cartel);
  let texCartel = null;
  function pintaCartel(nombre) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 120; const g = c.getContext('2d');
    g.fillStyle = '#ffffff'; g.fillRect(0, 0, 512, 120); g.fillStyle = '#2f7fe0'; g.fillRect(0, 0, 512, 12);
    g.fillStyle = '#0a1c33'; g.font = '800 54px Geist, system-ui, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    let t = nombre || 'Lavandería'; while (g.measureText(t).width > 470 && t.length > 4) t = t.slice(0, -2) + '…';
    g.fillText(t, 256, 66);
    texCartel?.dispose(); texCartel = new THREE.CanvasTexture(c); texCartel.colorSpace = THREE.SRGBColorSpace;
    const mm = new THREE.MeshStandardMaterial({ map: texCartel, roughness: .5 });
    cartel.material = [M(0xdfe8f2), M(0xdfe8f2), M(0xdfe8f2), M(0xdfe8f2), mm, M(0xdfe8f2)];
  }
  pintaCartel('Lavandería');
  const felpudo = caja(1.2, .02, .6, C.azul, 14.0, .15, LZ1 + .45); felpudo.castShadow = false;

  // recepción: riel con prendas
  const riel = new THREE.Group(); lav.add(riel);
  caja(.06, 1.7, .06, 0x7c8da6, 12.4, 1.0, 1.4, riel); caja(.06, 1.7, .06, 0x7c8da6, 13.9, 1.0, 1.4, riel); caja(1.56, .05, .05, 0x7c8da6, 13.15, 1.85, 1.4, riel);
  const colores = [0x6c8cff, 0xff8e72, 0x46c2a5, 0xf2b84b, 0xb98bf2, 0x58b7f0];
  const camisas = colores.map((c, i) => {
    const g = new THREE.Group(), piv = new THREE.Group();
    caja(.34, .42, .07, c, 0, -.3, 0, g); caja(.2, .12, .06, c, -.25, -.16, 0, g).rotation.z = .6; caja(.2, .12, .06, c, .25, -.16, 0, g).rotation.z = -.6;
    caja(.12, .04, .075, 0xffffff, 0, -.08, 0, g);
    piv.add(g); piv.position.set(12.55 + i * .26, 1.85, 1.4); riel.add(piv); piv.visible = false; return piv;
  });
  // mesa de entrega
  const mesa = new THREE.Group(); lav.add(mesa);
  caja(1.5, .7, 1.2, 0xe9d8bf, 13.0, .56, 4.2, mesa);
  const pilas = [0x7fb8f5, 0xffc6a8, 0xb7e3c6, 0xf7e49a].map((c, i) => {
    const g = new THREE.Group();
    for (let k = 0; k < 4; k++) caja(.42, .09, .34, [c, 0xffffff, c, 0xffffff][k] === 0xffffff ? 0xffffff : c, 0, k * .1, 0, g).rotation.y = k * .06;
    g.position.set(12.55 + (i % 2) * .85, .95, 3.95 + Math.floor(i / 2) * .5); g.visible = false; mesa.add(g); return g;
  });

  // máquinas
  const maquinas = [];
  function maquina(x, z, tipo) {
    const g = new THREE.Group(), lavadora = tipo === 'lavadora';
    caja(1.05, 1.05, .9, lavadora ? 0xffffff : 0xf4efe6, 0, .66, 0, g);
    caja(1.05, .2, .06, lavadora ? 0x8fc3f5 : 0xf2b27a, 0, 1.1, .46, g);
    const luz = new THREE.Mesh(new THREE.SphereGeometry(.035, 8, 8), new THREE.MeshStandardMaterial({ color: 0x888888, emissive: 0x000000 })); luz.position.set(.38, 1.1, .5); g.add(luz);
    const anillo = new THREE.Mesh(new THREE.TorusGeometry(.3, .05, 10, 28), M(0x9fb4cc, { metalness: .4, roughness: .3 })); anillo.position.set(0, .62, .46); g.add(anillo);
    const vidrio = new THREE.Mesh(new THREE.CircleGeometry(.29, 28), new THREE.MeshStandardMaterial({ color: 0x1e3350, roughness: .1, metalness: .2 })); vidrio.position.set(0, .62, .465); g.add(vidrio);
    const tambor = new THREE.Group(); tambor.position.set(0, .62, .475); g.add(tambor);
    const agua = new THREE.Mesh(new THREE.CircleGeometry(.27, 24, Math.PI * 1.12, Math.PI * .76), new THREE.MeshBasicMaterial({ color: 0x5bb6ff, transparent: true, opacity: .8 })); agua.position.set(0, .62, .472); g.add(agua);
    [0xff8e72, 0xf2b84b, 0x6c8cff, 0x46c2a5].forEach((c, i) => {
      const b = new THREE.Mesh(new THREE.SphereGeometry(.07, 10, 8), new THREE.MeshBasicMaterial({ color: c })); b.position.set(Math.cos(i * 1.57) * .15, Math.sin(i * 1.57) * .15, 0); tambor.add(b);
    });
    const particulas = [];
    for (let i = 0; i < 5; i++) {
      const p = new THREE.Mesh(new THREE.SphereGeometry(lavadora ? .06 : .05, 8, 8), new THREE.MeshBasicMaterial({ color: lavadora ? 0x9bdcff : 0xffd2a8, transparent: true, opacity: .8 }));
      p.visible = false; p.userData.fase = i / 5; g.add(p); particulas.push(p);
    }
    g.position.set(x, .26, z); sombrear(g); lav.add(g);
    const m = { g, tipo, luz, tambor, agua, particulas, activa: false, vel: 0, x, z };
    maquinas.push(m); return m;
  }
  const lavs = [maquina(14.0, 1.7, 'lavadora'), maquina(15.3, 1.7, 'lavadora')];
  const secs = [maquina(14.0, 3.2, 'secadora'), maquina(15.3, 3.2, 'secadora')];

  /* ───────── vehículos ───────── */
  function auto(color) {
    const g = new THREE.Group();
    caja(1.1, .32, .56, color, 0, .3, 0, g); caja(.58, .26, .5, 0xcfe8ff, -.05, .56, 0, g);
    for (const [wx, wz] of [[-.36, .28], [.36, .28], [-.36, -.28], [.36, -.28]]) {
      const w = new THREE.Mesh(new THREE.CylinderGeometry(.11, .11, .1, 12), M(0x1e3350)); w.rotation.x = Math.PI / 2; w.position.set(wx, .14, wz); g.add(w);
    }
    caja(.05, .08, .1, 0xfff3b0, .56, .32, .18, g); caja(.05, .08, .1, 0xfff3b0, .56, .32, -.18, g);
    return sombrear(g);
  }
  function bus() {
    const g = new THREE.Group();
    caja(2.4, .62, .62, 0x2f7fe0, 0, .5, 0, g); caja(2.3, .26, .64, 0xcfe8ff, 0, .72, 0, g); caja(2.42, .08, .64, 0xffffff, 0, .84, 0, g);
    for (const wx of [-.8, .8]) for (const wz of [.3, -.3]) { const w = new THREE.Mesh(new THREE.CylinderGeometry(.13, .13, .1, 12), M(0x1e3350)); w.rotation.x = Math.PI / 2; w.position.set(wx, .16, wz); g.add(w); }
    return sombrear(g);
  }
  // carriles de sentido contrario al de la moto (la moto usa el carril derecho de su ruta)
  const carriles = [];
  for (const c of CZ) carriles.push({ a: [HX + 1, c - .22], b: [LX - 1, c - .22] });          // oeste
  for (const c of CX) carriles.push({ a: [c - .22, LZ - 1], b: [c - .22, HZ + 1] });          // sur
  for (const c of [CZ[1], CZ[3], CZ[4]]) carriles.push({ a: [LX - 1, c + .22], b: [HX + 1, c + .22] }); // este (no pisa la ruta de la moto)
  for (const c of [CX[1], CX[3], CX[4]]) carriles.push({ a: [c + .22, HZ + 1], b: [c + .22, LZ - 1] });  // norte
  const colAuto = [0xe2705a, 0xf2b84b, 0x46c2a5, 0xb98bf2, 0xffffff, 0xff8e72, 0x6c8cff];
  const autosR = prng(5);
  const autos = [];
  carriles.forEach((l, i) => {
    const n = movil ? 1 : (i % 3 === 0 ? 2 : 1);
    for (let k = 0; k < n; k++) {
      const esBus = (i + k) % 5 === 2, g = esBus ? bus() : auto(colAuto[Math.floor(autosR() * colAuto.length)]);
      scene.add(g); autos.push({ ...l, g, v: (esBus ? 1.1 : 1.3) + autosR() * .7, fase: (autosR() + k / n) % 1 });
    }
  });

  /* ───────── moto ───────── */
  function crearMoto() {
    const g = new THREE.Group(), azul = M(C.azul, { roughness: .45 }), oscuro = M(0x1e3350);
    for (const wx of [-.42, .42]) {
      const r = new THREE.Mesh(new THREE.TorusGeometry(.17, .07, 8, 18), oscuro); r.position.set(wx, .24, 0); g.add(r);
      const hub = new THREE.Mesh(new THREE.CylinderGeometry(.08, .08, .12, 10), M(0xc9d6e6)); hub.rotation.x = Math.PI / 2; hub.position.set(wx, .24, 0); g.add(hub);
      g.userData['rueda' + (wx < 0 ? 0 : 1)] = r;
    }
    caja(.9, .22, .22, azul, -.02, .46, 0, g); caja(.3, .34, .2, azul, .28, .6, 0, g).rotation.z = -.5;
    caja(.5, .08, .26, oscuro, -.22, .66, 0, g);
    caja(.04, .5, .04, oscuro, .45, .62, 0, g).rotation.z = .22; caja(.05, .05, .4, oscuro, .5, .88, 0, g);
    const farol = new THREE.Mesh(new THREE.SphereGeometry(.06, 8, 8), new THREE.MeshBasicMaterial({ color: 0xfff3b0 })); farol.position.set(.56, .68, 0); g.add(farol);
    const carga = new THREE.Group(); g.add(carga); g.userData.carga = carga;
    caja(.46, .4, .4, 0xc49a6c, -.55, .9, 0, carga);
    caja(.5, .06, .44, 0x8b6a45, -.55, 1.12, 0, carga);
    const tor = caja(.2, .5, .22, 0xff8e72, -.05, .98, 0, g); tor.rotation.z = -.12;
    const cab = new THREE.Mesh(new THREE.SphereGeometry(.15, 12, 10), M(0xf2c6a0)); cab.position.set(.02, 1.32, 0); g.add(cab);
    const casco = new THREE.Mesh(new THREE.SphereGeometry(.17, 12, 10, 0, Math.PI * 2, 0, Math.PI / 2), M(0xf2b84b)); casco.position.set(.02, 1.34, 0); g.add(casco);
    caja(.3, .07, .08, 0xff8e72, .22, 1.08, .12, g).rotation.z = -.5; caja(.3, .07, .08, 0xff8e72, .22, 1.08, -.12, g).rotation.z = -.5;
    g.scale.setScalar(1.15);
    return sombrear(g);
  }
  const motos = []; // { g, rol, prog }

  /* ───────── nubes ───────── */
  const nubes = [];
  for (let i = 0; i < 4; i++) {
    const g = new THREE.Group();
    for (let k = 0; k < 4; k++) { const s = new THREE.Mesh(new THREE.SphereGeometry(1.1 + Math.random() * .9, 12, 10), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: .92, fog: false })); s.position.set(k * 1.4 - 2, Math.random() * .4, Math.random() * .8); s.scale.y = .6; g.add(s); }
    g.position.set(-8 + i * 11, 16 + (i % 2) * 4, -2 + i * 9); scene.add(g); nubes.push(g);
  }

  /* ───────── etiquetas HTML ───────── */
  const etiqs = new Map();
  function etiqueta(id, texto, vec, estilo = '') {
    let e = etiqs.get(id);
    if (!e) {
      e = document.createElement('div');
      e.style.cssText = `position:absolute;left:0;top:0;transform:translate(-50%,-100%);padding:4px 10px;border-radius:99px;white-space:nowrap;box-shadow:0 4px 14px rgba(10,28,51,.25);${estilo}`;
      etiquetas.appendChild(e); etiqs.set(id, e);
    }
    if (e.dataset.estilo !== estilo) { e.dataset.estilo = estilo; e.style.cssText = `position:absolute;left:0;top:0;transform:translate(-50%,-100%);padding:4px 10px;border-radius:99px;white-space:nowrap;box-shadow:0 4px 14px rgba(10,28,51,.25);${estilo}`; }
    e.textContent = texto; e.dataset.v = '1'; e._pos = vec;
  }
  const tmp = new THREE.Vector3();
  function actualizaEtiquetas() {
    const w = renderer.domElement.clientWidth, h = renderer.domElement.clientHeight;
    for (const [id, e] of etiqs) {
      if (e.dataset.v !== '1') { e.remove(); etiqs.delete(id); continue; }
      tmp.copy(e._pos).project(camera);
      e.style.display = tmp.z > 1 ? 'none' : 'block';
      e.style.transform = `translate(${(tmp.x * .5 + .5) * w}px,${(-tmp.y * .5 + .5) * h}px) translate(-50%,-100%)`;
      e.dataset.v = '0';
    }
  }
  const PILL_AZUL = 'background:#2f7fe0;color:#fff;', PILL_BLANCA = 'background:rgba(255,255,255,.94);color:#0a1c33;';

  /* ───────── estado y cámara ───────── */
  let datos = { motos: [] };
  let objetivo = { x: 11, y: 0, z: 11.5, dist: 92 };
  const cam = { x: 11, y: 0, z: 11.5, dist: 92 };
  const DIR = new THREE.Vector3(1, 1.4, 1.06).normalize();
  let explorando = false, zoomUsuario = 1, interior = 0 /* 0..1 opacidad invertida */;
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enabled = false; controls.enableDamping = true; controls.dampingFactor = .09;
  controls.minDistance = 9; controls.maxDistance = 110; controls.maxPolarAngle = 1.1; controls.minPolarAngle = .35; controls.screenSpacePanning = true;

  let tSet = 0, t = 0;
  function set(d) {
    datos = { motos: [], ...d }; tSet = t;
    pintaCartel(datos.nombre || 'Lavandería');
    camisas.forEach((c, i) => (c.visible = i < Math.min(datos.colgadas || 0, 6)));
    pilas.forEach((p, i) => (p.visible = i < Math.min(datos.listas || 0, 4)));
    casasSlot.forEach((c, i) => { c.sucia.visible = c.limpia.visible = false; c.pq.visible = (i === 0 && !!datos.paquete && !datos.casas); });
    for (const c of datos.casas || []) {
      const k = casasSlot[c.slot]; if (!k) continue;
      k.sucia.visible = c.estado === 'esperandoRepartidor' || c.estado === 'repartidorCamino';
      k.limpia.visible = c.estado === 'devolviendo';
      k.pq.visible = c.estado === 'entregada';
    }
    while (motos.length < Math.min(datos.motos.length, 12)) { const g = crearMoto(); scene.add(g); motos.push({ g, rol: null, slot: 0, prog: 0 }); }
    motos.forEach((m, i) => (m.g.visible = i < datos.motos.length));
  }
  function foco(t) {
    const f = datos.foco || 'auto';
    const ms = datos.motos || [];
    if (f === 'general') return { x: 11, y: 0, z: 11.5, dist: 92 };
    const hayInterior = (datos.colgadas || 0) + (datos.lavando || 0) + (datos.secando || 0) + (datos.listas || 0) > 0 || datos.ciclo;
    if (f === 'lavanderia' || (f === 'auto' && ms.length === 0 && hayInterior)) return { x: 14.2, y: .6, z: 3.1, dist: 21, interior: 1 };
    if (f === 'auto' && datos.casas && datos.casas.length > 1) return { x: 11, y: 0, z: 11.5, dist: 92 };
    if (f === 'casa' || (f === 'auto' && (datos.paquete || (datos.casas && datos.casas.length === 1 && ms.length === 0 && !hayInterior)))) {
      const k = casasSlot[(datos.casas && datos.casas[0] && datos.casas[0].slot) || 0].label; return { x: k.x + .4, y: .3, z: k.z + 1.0, dist: 19 };
    }
    if (f === 'auto' && ms.length === 1 && motos[0]) { const p = motos[0].g.position; return { x: p.x, y: .4, z: p.z, dist: 24 }; }
    return { x: 11, y: 0, z: 11.5, dist: 92 };
  }

  function actualizaMaquinas(t, dt) {
    const lavandoAhora = (t % PERIODO_CICLO) < PERIODO_CICLO / 2;
    for (const m of maquinas) {
      const esLav = m.tipo === 'lavadora', lista = esLav ? lavs : secs, idx = lista.indexOf(m);
      m.activa = datos.ciclo ? (idx === 0 && (esLav ? lavandoAhora : !lavandoAhora)) : idx < (esLav ? (datos.lavando || 0) : (datos.secando || 0));
      m.vel = lerp(m.vel, m.activa ? (esLav ? 5 : 8) : 0, Math.min(1, dt * 4));
      m.tambor.rotation.z -= m.vel * dt;
      m.agua.visible = esLav && m.activa;
      m.luz.material.color.set(m.activa ? 0x3ddc84 : 0x888888); m.luz.material.emissive.set(m.activa ? 0x1fa35c : 0x000000);
      for (const p of m.particulas) {
        p.visible = m.activa;
        if (!m.activa) continue;
        const f = (t * .55 + p.userData.fase) % 1;
        p.position.set(Math.sin(f * 7 + p.userData.fase * 9) * .25, 1.25 + f * .9, esLav ? .1 : .0);
        p.material.opacity = (1 - f) * .85; p.scale.setScalar(esLav ? 1 : .6 + f);
      }
    }
  }

  /* ───────── bucle ───────── */
  const reloj = new THREE.Clock(); let vivo = true, visible = true, raf = 0;
  function frame() {
    raf = requestAnimationFrame(frame);
    if (!visible || document.hidden) return;
    const dt = Math.min(reloj.getDelta(), .05); t += dt;
    animables.forEach((f) => f(t));
    nubes.forEach((n, i) => {
      n.position.x += dt * (.35 + i * .08); if (n.position.x > 36) n.position.x = -16;
      const op = Math.max(0, Math.min(.28, (n.position.distanceTo(camera.position) - 30) / 25));   // se desvanecen al acercarse a la cámara
      n.visible = op > .02; n.children.forEach((c) => (c.material.opacity = op));
    });
    estanque.material.color.setHex(0x7cc2ff);

    // autos
    for (const a of autos) {
      const len = a.len ?? (a.len = Math.hypot(a.b[0] - a.a[0], a.b[1] - a.a[1]));
      const u = ((t * a.v / len) + a.fase) % 1, x = lerp(a.a[0], a.b[0], u), z = lerp(a.a[1], a.b[1], u);
      a.g.position.set(x, .14, z);
      a.g.rotation.y = Math.atan2(-(a.b[1] - a.a[1]), a.b[0] - a.a[0]);
      a.g.scale.setScalar(Math.min(1, Math.min(u, 1 - u) * len / 2 + .001));
    }
    // semáforos y peatones
    for (const sm of semaforos) { const verde = ((t / 5 + sm.off) % 2) < 1; sm.verde.visible = verde; sm.rojo.visible = !verde; }
    for (const p of peatones) {
      p.u = (p.u + dt * p.v * p.dir + 1) % 1;
      const rango = p.horiz ? [LX, HX] : [LZ, HZ], pos = lerp(rango[0], rango[1], p.u);
      p.g.position.set(p.horiz ? pos : p.linea, .14 + Math.abs(Math.sin(t * 9 + p.u * 40)) * .02, p.horiz ? p.linea : pos);
      p.g.rotation.y = p.horiz ? (p.dir > 0 ? 0 : Math.PI) : (p.dir > 0 ? -Math.PI / 2 : Math.PI / 2);
    }

    // motos
    const ms = datos.motos || [];
    ms.slice(0, 12).forEach((d, i) => {
      const m = motos[i]; if (!m) return;
      const slot = d.slot || 0;
      if (m.rol !== d.rol || m.slot !== slot) { m.rol = d.rol; m.slot = slot; m.prog = d.progreso != null ? Math.min(d.progreso, .02) : 0; }
      const R = rutaDe(d.rol, slot, !!datos.rutaLarga);
      if (d.progreso == null) {
        // sin GPS: recorrido de demostración
        const per = R.largo / VEL_MOTO, fase = Math.min((((t - tSet) + i * 2.7) % (per + PAUSA_MOTO)) / per, 1);
        m.prog = .5 * ease(fase) + .5 * fase;
      } else {
        // con GPS real: avanza hacia la posición real a velocidad de moto (nunca retrocede) → la llegada coincide con la real
        const vmax = d.rapido ? 9 : 3.2, falta = Math.max(0, d.progreso - m.prog);
        m.prog += Math.min(falta, vmax * dt / R.largo);
      }
      const p = enRuta(R, m.prog, .22);
      m.g.position.set(p.x, .14, p.z); m.g.rotation.y = Math.atan2(-p.tz, p.tx);
      m.g.userData.carga.visible = d.rol !== 'recogiendo';
      m.g.userData.carga.children.forEach((c) => c.material?.color && (c.material.color.setHex(d.rol === 'devolviendo' ? 0xffffff : 0xc49a6c)));
      if (m.g.userData.rueda0) { m.g.userData.rueda0.rotation.z -= dt * 14; m.g.userData.rueda1.rotation.z -= dt * 14; }
      m.g.position.y = .14 + Math.abs(Math.sin(t * 22)) * .008;
    });

    actualizaMaquinas(t, dt);
    camisas.forEach((c, i) => { c.rotation.z = Math.sin(t * 1.8 + i * 1.3) * .08; });
    casasSlot.forEach((c, i) => { const b = Math.abs(Math.sin(t * 3 + i)) * .08; c.pq.position.y = .14 + b; c.sucia.position.y = c.limpia.position.y = .14 + Math.abs(Math.sin(t * 2.2 + i)) * .1; });

    // cámara
    const f = foco(t);
    objetivo = f;
    const aInt = f.interior ? 1 : 0; interior = lerp(interior, aInt, Math.min(1, dt * 3));
    for (const g of [frentes, techoG]) {
      g.visible = interior < .97;
      g.traverse((o) => { if (o.isMesh) { const k = o.material.userData.o ?? (o.material.userData.o = o.material.opacity ?? 1); o.material.opacity = k * (1 - interior); } });
    }
    cartel.visible = interior < .5;
    sol.target.position.set(cam.x, 0, cam.z); sol.position.set(cam.x + 24, 30, cam.z + 10);
    const sh = Math.min(30, Math.max(12, cam.dist * .42)); if (Math.abs(sol.shadow.camera.right - sh) > .5) { Object.assign(sol.shadow.camera, { left: -sh, right: sh, top: sh, bottom: -sh }); sol.shadow.camera.updateProjectionMatrix(); }
    if (!explorando) {
      const k = Math.min(1, dt * 2.4);
      cam.x = lerp(cam.x, objetivo.x, k); cam.y = lerp(cam.y, objetivo.y, k); cam.z = lerp(cam.z, objetivo.z, k); cam.dist = lerp(cam.dist, objetivo.dist / zoomUsuario, k);
      const asp = camera.aspect;
      const d = cam.dist * (asp < 1.3 ? 1.35 : 1);
      scene.fog.near = d * 1.7; scene.fog.far = d * 4;   // la niebla acompaña a la cámara: nunca se come la ciudad
      camera.position.set(cam.x + DIR.x * d, cam.y + DIR.y * d, cam.z + DIR.z * d);
      camera.lookAt(cam.x, cam.y, cam.z);
      controls.target.set(cam.x, cam.y, cam.z);
    } else controls.update();

    // etiquetas
    if (datos.destacarMia) {
      if ((datos.colgadas || 0) > 0 && interior > .5) etiqueta('mia1', 'Tu ropa', new THREE.Vector3(13.15, 2.5, 1.4), PILL_AZUL);
      if (datos.ciclo && interior > .5) { const m = (t % PERIODO_CICLO) < PERIODO_CICLO / 2 ? lavs[0] : secs[0]; etiqueta('mia2', (t % PERIODO_CICLO) < PERIODO_CICLO / 2 ? 'Lavando' : 'Secando', new THREE.Vector3(m.x, 1.9, m.z), PILL_AZUL); }
      if ((datos.listas || 0) > 0 && interior > .5) etiqueta('mia3', 'Tu ropa lista', new THREE.Vector3(13.0, 1.9, 4.2), PILL_AZUL);
    }
    const ESTILO = { esperandoRepartidor: 'background:#f59e0b;color:#fff;', repartidorCamino: 'background:#2f7fe0;color:#fff;', ropaEnCamino: 'background:#2f7fe0;color:#fff;',
      enLavanderia: 'background:rgba(255,255,255,.94);color:#0a1c33;', lavando: 'background:#2f7fe0;color:#fff;', lista: 'background:#1fa67a;color:#fff;',
      devolviendo: 'background:#8b5cf6;color:#fff;', entregada: 'background:#1fa67a;color:#fff;', trae: 'background:rgba(255,255,255,.94);color:#0a1c33;' };
    if (datos.casas) for (const c of datos.casas) { const k = casasSlot[c.slot]; if (k) etiqueta('casa' + c.slot, c.etiqueta, k.label, (ESTILO[c.estado] || ESTILO.enLavanderia) + 'font-size:11px;'); }
    else if (datos.paquete) etiqueta('casa', '¡Entregada!', new THREE.Vector3(1.7, 1.1, 10.35), 'background:#1fa67a;color:#fff;');
    if (!interior || interior < .5) etiqueta('lav', datos.nombre || 'Lavandería', new THREE.Vector3(14.2, 3.9, LZ1 + .15), PILL_BLANCA);
    if (!datos.casas) etiqueta('hogar', 'Tu casa', new THREE.Vector3(2.2, 2.9, 8.6), PILL_BLANCA + 'font-size:11px;');
    actualizaEtiquetas();
    renderer.render(scene, camera);
  }

  function ajustar() {
    const w = cont.clientWidth || 600, h = cont.clientHeight || 340;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
  }
  const ro = new ResizeObserver(ajustar); ro.observe(cont); ajustar();
  const io = new IntersectionObserver((e) => (visible = e[0].isIntersecting)); io.observe(cont);
  set({ motos: [] });
  frame();

  return {
    set,
    explorar(v) {
      explorando = !!v; controls.enabled = explorando;
      if (explorando) { controls.target.set(cam.x, cam.y, cam.z); } else { zoomUsuario = 1; }
    },
    zoom(f) { if (explorando) { camera.position.sub(controls.target).multiplyScalar(1 / f).add(controls.target); } else zoomUsuario = Math.min(3.2, Math.max(.7, zoomUsuario * f)); },
    reset() { explorando = false; controls.enabled = false; zoomUsuario = 1; },
    destruir() { cancelAnimationFrame(raf); ro.disconnect(); io.disconnect(); renderer.dispose(); renderer.domElement.remove(); etiquetas.remove(); },
    get explorando() { return explorando; },
    debug() { return { cam: { ...cam }, objetivo, camara: camera.position.toArray(), motos: motos.map((m) => ({ rol: m.rol, slot: m.slot, prog: m.prog, pos: m.g.position.toArray(), vis: m.g.visible })), datos }; },
  };
}

export function webglDisponible() {
  try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch { return false; }
}
