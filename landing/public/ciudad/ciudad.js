/* Ciudad completa alrededor de la lavandería: cuadrícula de calles, centro comercial,
   rascacielos, barrios de casas (lotes para clientes), parque, árboles, postes y semáforos.
   Coordenadas en metros; la lavandería está en la manzana (0,0). */
import * as THREE from 'three';
import { PALETA } from './mundo.js';
import { copia, disponible } from './modelos.js';
import { fusionar } from './fusion.js';

export const PASO = 36;          // manzana (28 m) + calle (8 m)
export const MANZANA = 28;
export const CALLE = 8;
export const RADIO = 4;          // manzanas -4..4 → ciudad de ~320 m
export const CARRIL = 1.9;       // desplazamiento del carril derecho

/* ───────── texturas dibujadas (asfalto con líneas, vereda) ───────── */
function texCalle() {
  const c = document.createElement('canvas'); c.width = 64; c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = '#d6dbe9'; g.fillRect(0, 0, 64, 256);
  for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(80,90,120,${Math.random() * 0.05})`; g.fillRect(Math.random() * 64, Math.random() * 256, 1, 1); }
  g.fillStyle = '#ffffff'; g.fillRect(30, 20, 4, 90); g.fillRect(30, 148, 4, 90); // línea central discontinua
  g.fillStyle = 'rgba(255,255,255,.75)'; g.fillRect(2, 0, 2, 256); g.fillRect(60, 0, 2, 256); // bordes
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}
function texCruce() {
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = '#d6dbe9'; g.fillRect(0, 0, 256, 256);
  g.fillStyle = '#ffffff';
  for (let i = 0; i < 6; i++) { // pasos de cebra en los 4 lados
    const o = 40 + i * 30;
    g.fillRect(o, 4, 16, 34); g.fillRect(o, 218, 16, 34); g.fillRect(4, o, 34, 16); g.fillRect(218, o, 34, 16);
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

const prng = (seed) => () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

export function crearCiudad(mundo) {
  const raiz = new THREE.Group(); raiz.name = 'ciudad';
  mundo.escena.add(raiz);
  const rnd = prng(20261012);
  const lim = (RADIO + 0.5) * PASO;            // borde exterior de las calles
  const lineas = [];                             // centros de calle (x o z)
  for (let i = -RADIO; i <= RADIO + 1; i++) lineas.push((i - 0.5) * PASO);

  /* calles */
  const tc = texCalle(), largo = lim * 2 + CALLE;
  const matCalle = new THREE.MeshStandardMaterial({ map: tc, roughness: 0.95 });
  tc.repeat.set(1, largo / 8);
  for (const L of lineas) {
    for (const eje of ['x', 'z']) {
      const m = new THREE.Mesh(new THREE.PlaneGeometry(CALLE, largo), matCalle);
      m.rotation.x = -Math.PI / 2;
      if (eje === 'x') { m.rotation.z = Math.PI / 2; m.position.set(0, 0.01, L); } else m.position.set(L, 0.01, 0);
      m.receiveShadow = true; raiz.add(m);
    }
  }
  const matCruce = new THREE.MeshStandardMaterial({ map: texCruce(), roughness: 0.95 });
  const geoCruce = new THREE.PlaneGeometry(CALLE, CALLE);
  for (const x of lineas) for (const z of lineas) {
    const m = new THREE.Mesh(geoCruce, matCruce); m.rotation.x = -Math.PI / 2; m.position.set(x, 0.02, z); m.receiveShadow = true; raiz.add(m);
  }

  /* manzanas: vereda elevada + interior (césped o pavimento) */
  const matVereda = new THREE.MeshStandardMaterial({ color: PALETA.vereda, roughness: 0.9 });
  const matCesped = new THREE.MeshStandardMaterial({ color: PALETA.cesped, roughness: 1 });
  const matPlaza = new THREE.MeshStandardMaterial({ color: 0xeaedf7, roughness: 0.9 });
  const geoVereda = new THREE.BoxGeometry(MANZANA, 0.18, MANZANA);
  const lotes = [];        // casas de barrio (para clientes)
  const ocupado = new Set();

  const poner = (ruta, x, z, rot = 0, esc) => {
    if (!disponible(ruta)) return null;
    const o = copia(ruta, esc); o.position.set(x, 0.18, z); o.rotation.y = rot; raiz.add(o); return o;
  };

  for (let i = -RADIO; i <= RADIO; i++) for (let j = -RADIO; j <= RADIO; j++) {
    const cx = i * PASO, cz = j * PASO, d = Math.max(Math.abs(i), Math.abs(j));
    const v = new THREE.Mesh(geoVereda, matVereda); v.position.set(cx, 0.09, cz); v.receiveShadow = true; raiz.add(v);
    const tipo = i === 0 && j === 0 ? 'lavanderia'
      : (i === -1 && j === 1) || (i === 2 && j === -2) ? 'parque'
      : (j <= -2 && Math.abs(i) <= 2 && d <= 3) ? 'torres'
      : d === 1 ? 'comercio' : 'barrio';
    const interior = new THREE.Mesh(new THREE.PlaneGeometry(MANZANA - 4, MANZANA - 4), tipo === 'barrio' || tipo === 'parque' ? matCesped : matPlaza);
    interior.rotation.x = -Math.PI / 2; interior.position.set(cx, 0.185, cz); interior.receiveShadow = true; raiz.add(interior);

    if (tipo === 'comercio' || tipo === 'torres') {
      // edificios mirando a las 4 calles, 3 por lado
      const lista = tipo === 'torres' ? ['com/building-skyscraper-a', 'com/building-skyscraper-b', 'com/building-skyscraper-c', 'com/building-skyscraper-d', 'com/building-skyscraper-e']
        : d === 1 ? ['com/building-a', 'com/building-b', 'com/building-c', 'com/building-d', 'com/building-e', 'com/building-f']
        : ['com/building-a', 'com/building-b', 'com/building-c', 'com/building-d', 'com/building-e', 'com/building-f', 'com/building-g', 'com/building-h', 'com/building-i', 'com/building-j', 'com/building-k', 'com/building-l', 'com/building-m', 'com/building-n'];
      const n = tipo === 'torres' ? 2 : 3, sep = MANZANA / n;
      for (let k = 0; k < n; k++) {
        const o = -MANZANA / 2 + sep * (k + 0.5);
        const r = () => lista[Math.floor(rnd() * lista.length)];
        const esc = tipo === 'torres' ? 7 + rnd() * 2.5 : d === 1 ? 6 : 7;
        const off = MANZANA / 2 - (tipo === 'torres' ? 5.5 : 4);
        poner(r(), cx + o, cz + off, 0, esc);
        poner(r(), cx + o, cz - off, Math.PI, esc);
        if (k > 0 && k < n - 1 || n === 2) {
          poner(r(), cx + off, cz + o, Math.PI / 2, esc);
          poner(r(), cx - off, cz + o, -Math.PI / 2, esc);
        }
      }
    } else if (tipo === 'barrio') {
      const casas = ['sub/building-type-a', 'sub/building-type-b', 'sub/building-type-c', 'sub/building-type-d', 'sub/building-type-e', 'sub/building-type-f', 'sub/building-type-g', 'sub/building-type-h', 'sub/building-type-i', 'sub/building-type-j', 'sub/building-type-k', 'sub/building-type-l', 'sub/building-type-m', 'sub/building-type-n', 'sub/building-type-o', 'sub/building-type-p', 'sub/building-type-q', 'sub/building-type-r', 'sub/building-type-s', 'sub/building-type-t', 'sub/building-type-u'];
      for (const lado of [1, -1]) for (let k = 0; k < 3; k++) {
        const x = cx - MANZANA / 2 + (MANZANA / 3) * (k + 0.5);
        const z = cz + lado * (MANZANA / 2 - 6.2);
        const rot = lado === 1 ? 0 : Math.PI;
        const lote = { id: lotes.length, x, z, rot, frente: { x, z: cz + lado * (MANZANA / 2 + CALLE / 2), eje: 'x' }, obj: null, modelo: casas[Math.floor(rnd() * casas.length)] };
        lote.obj = poner(lote.modelo, x, z, rot);
        if (rnd() < 0.7) poner('sub/tree-large', x + 3.6, z - lado * 3.5, 0, 6 + rnd() * 2);
        lotes.push(lote);
      }
      // árboles y cercos en el interior
      for (let k = 0; k < 4; k++) poner(rnd() < 0.5 ? 'sub/tree-large' : 'sub/tree-small', cx + (rnd() - 0.5) * 16, cz + (rnd() - 0.5) * 6, 0, 6 + rnd() * 2);
    } else if (tipo === 'parque') {
      for (let k = 0; k < 16; k++) poner(rnd() < 0.6 ? 'sub/tree-large' : 'sub/tree-small', cx + (rnd() - 0.5) * 22, cz + (rnd() - 0.5) * 22, rnd() * 6, 6 + rnd() * 3);
      for (let k = 0; k < 4; k++) poner('mueble/benchCushion', cx + Math.cos(k * 1.57) * 5, cz + Math.sin(k * 1.57) * 5, -k * 1.57 + Math.PI / 2, 2);
      const fuente = new THREE.Mesh(new THREE.CylinderGeometry(2.6, 2.9, 0.6, 40), new THREE.MeshStandardMaterial({ color: 0xf2f4fb, roughness: 0.6 }));
      const agua = new THREE.Mesh(new THREE.CylinderGeometry(2.3, 2.3, 0.05, 40), new THREE.MeshStandardMaterial({ color: 0x9fd2ff, roughness: 0.15, metalness: 0.1 }));
      fuente.position.set(cx, 0.48, cz); agua.position.set(cx, 0.8, cz); fuente.castShadow = true; raiz.add(fuente, agua);
    }
  }

  /* postes de luz y semáforos */
  for (const x of lineas) for (const z of lineas) {
    if (Math.abs(x) > lim - 1 || Math.abs(z) > lim - 1) continue;
    if (rnd() < 0.35) poner('road/traffic-light', x + CALLE / 2 + 0.8, z + CALLE / 2 + 0.8, Math.PI, 5);
  }
  for (const L of lineas) for (let i = -RADIO; i <= RADIO; i++) {
    if (rnd() < 0.5) poner('road/light-square', i * PASO + 7, L + CALLE / 2 + 0.6, Math.PI, 6);
    if (rnd() < 0.5) poner('road/light-square', L - CALLE / 2 - 0.6, i * PASO - 7, Math.PI / 2, 6);
  }

  /* ───────── rutas por la cuadrícula (carril derecho) ───────── */
  const lineaMasCercana = (v) => lineas.reduce((a, b) => (Math.abs(b - v) < Math.abs(a - v) ? b : a));
  /** Recorrido por calles entre dos puntos "frente" ({x,z,eje}); devuelve lista de [x,z]. */
  function recorrido(a, b) {
    const pts = [[a.x, a.z]];
    if (a.eje === 'x' && b.eje === 'x') {
      if (Math.abs(a.z - b.z) < 0.1) pts.push([b.x, b.z]);
      else { const xv = lineaMasCercana((a.x + b.x) / 2); pts.push([xv, a.z], [xv, b.z], [b.x, b.z]); }
    } else if (a.eje === 'z' && b.eje === 'z') {
      if (Math.abs(a.x - b.x) < 0.1) pts.push([b.x, b.z]);
      else { const zh = lineaMasCercana((a.z + b.z) / 2); pts.push([a.x, zh], [b.x, zh], [b.x, b.z]); }
    } else if (a.eje === 'x') pts.push([b.x, a.z], [b.x, b.z]);
    else pts.push([a.x, b.z], [b.x, b.z]);
    return pts.filter((p, i) => !i || Math.hypot(p[0] - pts[i - 1][0], p[1] - pts[i - 1][1]) > 0.05);
  }

  /** Lote libre más cercano a un punto (x,z) del mundo. */
  function loteCercano(x, z, excluir = ocupado) {
    let mejor = null, dm = Infinity;
    for (const l of lotes) {
      if (excluir.has(l.id)) continue;
      const dd = (l.x - x) ** 2 + (l.z - z) ** 2;
      if (dd < dm) { dm = dd; mejor = l; }
    }
    return mejor;
  }

  /* ───────── optimización: todo lo estático de cada manzana se fusiona en pocas mallas ─────────
     Mismos modelos y colores, pero ~15 veces menos llamadas de dibujo. Una casa de lote se puede
     ocultar (obra en construcción): solo se vuelve a fusionar su manzana. */
  const fuentes = new Map();
  const ZONA = PASO * 3; // zonas de 3×3 manzanas: pocas mallas y aún se recortan fuera de cámara
  const clave = (x, z) => `${Math.round(x / ZONA)},${Math.round(z / ZONA)}`;
  for (const o of [...raiz.children]) {
    raiz.remove(o);
    const k = clave(o.position.x, o.position.z);
    if (!fuentes.has(k)) fuentes.set(k, []);
    fuentes.get(k).push(o);
  }
  const fusionadas = new Map();
  function fusionarManzana(k) {
    for (const m of fusionadas.get(k) || []) { raiz.remove(m); m.geometry.dispose(); }
    const mallas = fusionar((fuentes.get(k) || []).filter((o) => !o.userData.oculto), raiz);
    mallas.forEach((m) => raiz.add(m));
    fusionadas.set(k, mallas);
  }
  for (const k of fuentes.keys()) fusionarManzana(k);
  for (const l of lotes) {
    if (!l.obj) continue;
    const k = clave(l.obj.position.x, l.obj.position.z);
    l.ocultar = (v) => { l.obj.userData.oculto = v; fusionarManzana(k); };
  }

  return { raiz, lotes, ocupado, lineas, lim, recorrido, loteCercano, lineaMasCercana };
}

/* ───────── utilidades de recorrido (polilínea con esquinas suaves) ───────── */
export function trazar(pts, radio = 3, lado = CARRIL) {
  // desplaza al carril derecho según la dirección de cada tramo
  const off = [];
  for (let i = 0; i < pts.length; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    let tx = b[0] - a[0], tz = b[1] - a[1]; const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
    off.push([pts[i][0] - tz * lado, pts[i][1] + tx * lado]);
  }
  const out = [off[0]];
  for (let i = 1; i < off.length - 1; i++) {
    const [ax, az] = off[i - 1], [bx, bz] = off[i], [cx, cz] = off[i + 1];
    const l1 = Math.hypot(bx - ax, bz - az), l2 = Math.hypot(cx - bx, cz - bz);
    const r = Math.min(radio, l1 / 2, l2 / 2);
    const p1 = [bx - (bx - ax) / l1 * r, bz - (bz - az) / l1 * r], p2 = [bx + (cx - bx) / l2 * r, bz + (cz - bz) / l2 * r];
    for (let k = 0; k <= 8; k++) { const t = k / 8, u = 1 - t; out.push([u * u * p1[0] + 2 * u * t * bx + t * t * p2[0], u * u * p1[1] + 2 * u * t * bz + t * t * p2[1]]); }
  }
  out.push(off[off.length - 1]);
  const acum = [0];
  for (let i = 1; i < out.length; i++) acum.push(acum[i - 1] + Math.hypot(out[i][0] - out[i - 1][0], out[i][1] - out[i - 1][1]));
  return { pts: out, acum, largo: acum[acum.length - 1] };
}
export function puntoEn(R, s) {
  s = Math.max(0, Math.min(R.largo, s));
  let i = 1; while (i < R.acum.length - 1 && R.acum[i] < s) i++;
  const [ax, az] = R.pts[i - 1], [bx, bz] = R.pts[i];
  const k = (s - R.acum[i - 1]) / ((R.acum[i] - R.acum[i - 1]) || 1);
  return { x: ax + (bx - ax) * k, z: az + (bz - az) * k, ang: Math.atan2(bx - ax, bz - az) };
}
