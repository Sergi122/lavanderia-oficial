/* Lavandería con interior visible (el techo se desvanece al acercarse): recepción,
   zona de descanso, lavadoras, secadoras, máquina de vapor/lavado en seco, planchado
   y la sección de colgados (cola de pedidos). Expone "estaciones" donde se paran los
   empleados según lo que estén haciendo. */
import * as THREE from 'three';
import { RoundedBoxGeometry } from '../vendor/jsm/geometries/RoundedBoxGeometry.js';
import { PALETA } from './mundo.js';
import { copia, disponible } from './modelos.js';
import { fusionar } from './fusion.js';

const ANCHO = 22, FONDO = 14, ALTO = 4.4;
const mat = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, ...extra });

function texPiso() {
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const g = c.getContext('2d');
  for (let i = 0; i < 8; i++) for (let j = 0; j < 8; j++) {
    g.fillStyle = (i + j) % 2 ? '#f3f5fb' : '#e7ebf6'; g.fillRect(i * 32, j * 32, 32, 32);
  }
  g.strokeStyle = 'rgba(160,170,200,.35)'; g.lineWidth = 1;
  for (let i = 0; i <= 8; i++) { g.beginPath(); g.moveTo(i * 32, 0); g.lineTo(i * 32, 256); g.stroke(); g.beginPath(); g.moveTo(0, i * 32); g.lineTo(256, i * 32); g.stroke(); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(ANCHO / 4, FONDO / 4); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function texLetrero(nombre) {
  const c = document.createElement('canvas'); c.width = 1024; c.height = 192;
  const g = c.getContext('2d');
  const gr = g.createLinearGradient(0, 0, 1024, 0); gr.addColorStop(0, '#2f6fe0'); gr.addColorStop(1, '#3d8bff');
  g.fillStyle = gr; g.beginPath(); g.roundRect(0, 0, 1024, 192, 36); g.fill();
  g.fillStyle = '#fff'; g.beginPath(); g.arc(96, 96, 58, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#2f6fe0'; g.beginPath(); g.arc(96, 104, 30, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#9fd2ff'; g.beginPath(); g.arc(96, 104, 21, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#2f6fe0'; g.fillRect(64, 50, 64, 12);
  g.fillStyle = '#fff'; g.font = 'bold 74px system-ui, sans-serif'; g.textBaseline = 'middle';
  const t = (nombre || 'Lavandería').toUpperCase();
  let tam = 74;
  while (tam > 30) { g.font = `bold ${tam}px system-ui, sans-serif`; if (g.measureText(t).width <= 800) break; tam -= 4; }
  g.fillText(t, 180, 100, 820);
  const tx = new THREE.CanvasTexture(c); tx.colorSpace = THREE.SRGBColorSpace; tx.anisotropy = 8;
  return tx;
}

/* ───────── piezas hechas a mano (formas suaves, no cubos sueltos) ───────── */
function maquinaVapor() {
  const g = new THREE.Group();
  const cuerpo = new THREE.Mesh(new RoundedBoxGeometry(2.2, 1.9, 1.3, 4, 0.18), mat(0xf7f9fd, { roughness: 0.35 }));
  cuerpo.position.y = 0.95; g.add(cuerpo);
  const franja = new THREE.Mesh(new RoundedBoxGeometry(2.24, 0.28, 1.34, 3, 0.1), mat(PALETA.azul, { roughness: 0.4 }));
  franja.position.y = 1.62; g.add(franja);
  const aro = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.09, 16, 40), mat(0xb8c2d8, { metalness: 0.6, roughness: 0.25 }));
  aro.position.set(-0.35, 0.9, 0.66); g.add(aro);
  const vidrio = new THREE.Mesh(new THREE.CircleGeometry(0.46, 40), new THREE.MeshPhysicalMaterial({ color: 0x9fd2ff, roughness: 0.05, transmission: 0.3, transparent: true, opacity: 0.85 }));
  vidrio.position.set(-0.35, 0.9, 0.665); g.add(vidrio);
  const tambor = new THREE.Mesh(new THREE.CircleGeometry(0.38, 6), mat(0x7aa7e6));
  tambor.position.set(-0.35, 0.9, 0.655); g.add(tambor);
  const panel = new THREE.Mesh(new RoundedBoxGeometry(0.6, 0.8, 0.08, 2, 0.04), mat(0x223355, { roughness: 0.3 }));
  panel.position.set(0.62, 1.05, 0.66); g.add(panel);
  for (let i = 0; i < 3; i++) {
    const led = new THREE.Mesh(new THREE.SphereGeometry(0.045, 12, 8), new THREE.MeshBasicMaterial({ color: [0x58e08a, 0xffc44d, 0x58c8ff][i] }));
    led.position.set(0.48 + i * 0.14, 1.3, 0.71); g.add(led);
  }
  const tubo = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.12, 1.1, 20), mat(0xc7cfe0, { metalness: 0.5, roughness: 0.3 }));
  tubo.position.set(0.85, 2.35, -0.3); g.add(tubo);
  g.userData.tambor = tambor;
  g.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  return g;
}

function mesaPlanchar() {
  const g = new THREE.Group();
  const forma = new THREE.Shape();
  forma.moveTo(-0.85, -0.2); forma.lineTo(0.55, -0.2);
  forma.quadraticCurveTo(0.95, -0.2, 0.95, 0); forma.quadraticCurveTo(0.95, 0.2, 0.55, 0.2);
  forma.lineTo(-0.85, 0.2); forma.lineTo(-0.85, -0.2);
  const tabla = new THREE.Mesh(new THREE.ExtrudeGeometry(forma, { depth: 0.05, bevelEnabled: true, bevelSize: 0.02, bevelThickness: 0.02, bevelSegments: 3 }), mat(0xbcd6ff, { roughness: 0.85 }));
  tabla.rotation.x = -Math.PI / 2; tabla.position.y = 0.9; g.add(tabla);
  for (const s of [-1, 1]) {
    const pata = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.05, 10), mat(0x9aa6bf, { metalness: 0.6 }));
    pata.position.set(-0.25, 0.45, 0); pata.rotation.z = s * 0.45; g.add(pata);
  }
  // plancha
  const plancha = new THREE.Group();
  const fp = new THREE.Shape(); fp.moveTo(-0.16, -0.09); fp.lineTo(0.08, -0.09); fp.quadraticCurveTo(0.2, 0, 0.08, 0.09); fp.lineTo(-0.16, 0.09); fp.lineTo(-0.16, -0.09);
  const base = new THREE.Mesh(new THREE.ExtrudeGeometry(fp, { depth: 0.07, bevelEnabled: true, bevelSize: 0.015, bevelThickness: 0.015, bevelSegments: 2 }), mat(0xffffff, { roughness: 0.3 }));
  base.rotation.x = -Math.PI / 2; plancha.add(base);
  const asa = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.022, 8, 20, Math.PI), mat(PALETA.azul));
  asa.position.set(-0.04, 0.09, 0); plancha.add(asa);
  plancha.position.set(0.1, 0.97, 0); g.add(plancha);
  // prenda sobre la tabla
  const prenda = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.02, 0.34), mat(0xf6c1c7, { roughness: 0.95 }));
  prenda.position.set(-0.35, 0.965, 0); g.add(prenda);
  g.userData.plancha = plancha;
  g.traverse((o) => { if (o.isMesh) { o.castShadow = true; } });
  return g;
}

/** Prensa universal (como las de las fotos): gabinete con relojes, mesa de acero, almohadilla inferior,
 *  cabezal neumático con resortes y barra amarilla, soplador lateral con manguera y pedales. */
function prensaUniversal() {
  const g = new THREE.Group();
  const blanco = mat(0xf4f6fb, { roughness: 0.4 }), acero = mat(0xc9d0dc, { metalness: 0.65, roughness: 0.28 });
  const oscuro = mat(0x2a3142, { roughness: 0.5 }), azulA = mat(0xa9c9f2, { roughness: 0.9 });
  const add = (geo, m, x, y, z) => { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); o.castShadow = true; g.add(o); return o; };
  add(new RoundedBoxGeometry(0.95, 0.06, 0.85, 2, 0.02), oscuro, 0, 0.03, 0.05);                 // base
  add(new RoundedBoxGeometry(0.72, 0.92, 0.6, 3, 0.04), blanco, 0, 0.52, 0);                      // gabinete
  for (let i = 0; i < 3; i++) {                                                                  // relojes
    add(new RoundedBoxGeometry(0.11, 0.11, 0.03, 2, 0.01), mat(0xd8dbe2), -0.16 + i * 0.16, 0.86, 0.31);
    const r = add(new THREE.CylinderGeometry(0.035, 0.035, 0.02, 20), oscuro, -0.16 + i * 0.16, 0.86, 0.33); r.rotation.x = Math.PI / 2;
  }
  add(new THREE.SphereGeometry(0.022, 10, 8), mat(0xe53935), -0.16, 0.72, 0.31);
  add(new THREE.SphereGeometry(0.025, 10, 8), mat(0x1e63d6), -0.04, 0.72, 0.31);
  add(new RoundedBoxGeometry(0.12, 0.16, 0.04, 2, 0.01), oscuro, 0.16, 0.7, 0.31);               // interruptor
  add(new THREE.BoxGeometry(0.07, 0.05, 0.02), mat(0x43a047), 0.16, 0.73, 0.335);
  add(new THREE.BoxGeometry(0.07, 0.04, 0.02), mat(0xe53935), 0.16, 0.67, 0.335);
  add(new THREE.BoxGeometry(0.2, 0.14, 0.01), mat(0x1aa3e8), -0.17, 0.5, 0.305);                 // etiqueta de seguridad
  for (const x of [-0.12, 0.12]) add(new RoundedBoxGeometry(0.16, 0.03, 0.22, 2, 0.01), oscuro, x, 0.08, 0.42); // pedales
  const guarda = add(new THREE.TorusGeometry(0.11, 0.012, 6, 16, Math.PI), mat(0xff7a45), 0.12, 0.08, 0.5); guarda.rotation.y = Math.PI / 2;
  // mesa de acero curvada (bandeja)
  const mesa = add(new RoundedBoxGeometry(1.75, 0.05, 0.62, 3, 0.02), acero, 0, 1.0, 0.05);
  add(new THREE.BoxGeometry(1.75, 0.09, 0.02), acero, 0, 0.97, 0.37);
  add(new THREE.CylinderGeometry(0.05, 0.05, 0.12, 12), acero, -0.45, 1.08, -0.05);              // soporte
  // almohadilla inferior (forma de tabla de surf)
  const tabla = (largo, ancho, alto, m) => {
    const f = new THREE.Shape(); const r = ancho / 2;
    f.moveTo(-largo / 2 + r, -r); f.lineTo(largo / 2 - r, -r); f.absarc(largo / 2 - r, 0, r, -Math.PI / 2, Math.PI / 2, false);
    f.lineTo(-largo / 2 + r, r); f.absarc(-largo / 2 + r, 0, r, Math.PI / 2, Math.PI * 1.5, false);
    const geo = new THREE.ExtrudeGeometry(f, { depth: alto, bevelEnabled: true, bevelSize: 0.03, bevelThickness: 0.03, bevelSegments: 4, curveSegments: 18 });
    geo.rotateX(-Math.PI / 2);
    const o = new THREE.Mesh(geo, m); o.castShadow = true; return o;
  };
  const buck = tabla(1.45, 0.42, 0.1, azulA); buck.position.set(0, 1.06, 0.02); g.add(buck);
  // cabezal: almohadilla superior + placa negra + cilindro neumático + resortes + barra amarilla
  const cabezal = new THREE.Group(); cabezal.position.set(0, 1.42, 0.02); g.add(cabezal);
  const pad = tabla(1.4, 0.4, 0.1, azulA); pad.position.y = -0.18; cabezal.add(pad);
  const placa = new THREE.Mesh(new RoundedBoxGeometry(0.62, 0.05, 0.3, 2, 0.02), oscuro); placa.position.y = 0.0; cabezal.add(placa);
  const piston = new THREE.Mesh(new THREE.CylinderGeometry(0.045, 0.045, 0.32, 14), acero); piston.position.y = 0.18; cabezal.add(piston);
  for (const x of [-0.27, 0.27]) for (const z of [-0.1, 0.1]) {
    for (let k = 0; k < 6; k++) { const an = new THREE.Mesh(new THREE.TorusGeometry(0.028, 0.006, 5, 12), acero); an.rotation.x = Math.PI / 2; an.position.set(x, 0.04 + k * 0.025, z); cabezal.add(an); }
  }
  const barra = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 1.55, 8), mat(0xffb300)); barra.rotation.z = Math.PI / 2; barra.position.set(0, -0.2, 0.25); cabezal.add(barra);
  cabezal.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  // soplador lateral con manguera
  const motor = add(new THREE.CylinderGeometry(0.13, 0.13, 0.3, 20), acero, -0.55, 0.3, 0.05); motor.rotation.z = Math.PI / 2;
  for (let k = 0; k < 5; k++) { const f = add(new THREE.CylinderGeometry(0.15, 0.15, 0.012, 20), acero, -0.47 - k * 0.04, 0.3, 0.05); f.rotation.z = Math.PI / 2; }
  const curva = new THREE.CatmullRomCurve3([new THREE.Vector3(-0.72, 0.3, 0.05), new THREE.Vector3(-0.85, 0.55, 0.0), new THREE.Vector3(-0.62, 0.92, -0.05), new THREE.Vector3(-0.45, 1.0, -0.05)]);
  add(new THREE.TubeGeometry(curva, 24, 0.045, 10), mat(0xb7c0cf, { metalness: 0.5, roughness: 0.35 }), 0, 0, 0);
  g.userData = { cabezal, mesa };
  return g;
}

const COLORES_ROPA = [0xf6c1c7, 0xb8d8ff, 0xc9f0d6, 0xffe2a8, 0xd8c8ff, 0xffffff, 0x9cc3ff, 0xf7b267];
/** Prenda colgada con funda transparente (para la sección de colgados). */
function prendaColgada(color) {
  const g = new THREE.Group();
  const gancho = new THREE.Mesh(new THREE.TorusGeometry(0.06, 0.012, 6, 16, Math.PI * 1.4), mat(0x9aa6bf, { metalness: 0.7 }));
  gancho.position.y = 0.02; g.add(gancho);
  const forma = new THREE.Shape();
  forma.moveTo(-0.05, 0); forma.lineTo(-0.26, -0.12); forma.lineTo(-0.24, -0.95); forma.lineTo(0.24, -0.95); forma.lineTo(0.26, -0.12); forma.lineTo(0.05, 0);
  const ropa = new THREE.Mesh(new THREE.ExtrudeGeometry(forma, { depth: 0.08, bevelEnabled: true, bevelSize: 0.02, bevelThickness: 0.03, bevelSegments: 2 }), mat(color, { roughness: 0.9 }));
  ropa.position.z = -0.04; g.add(ropa);
  const funda = new THREE.Mesh(new THREE.CapsuleGeometry(0.29, 0.62, 4, 12), new THREE.MeshPhysicalMaterial({ color: 0xffffff, transparent: true, opacity: 0.28, roughness: 0.1 }));
  funda.position.y = -0.5; funda.scale.z = 0.35; g.add(funda);
  return g;
}

/** Bolsa de ropa (lathe redondeado con nudo): lo que se entrega y se cuelga en la cola. */
export function bolsaRopa(color = 0x2f6fe0) {
  const g = new THREE.Group();
  const perfil = [];
  for (let i = 0; i <= 12; i++) { const t = i / 12; perfil.push(new THREE.Vector2(Math.sin(t * Math.PI) * 0.26 + 0.02 + (t > 0.85 ? -0.12 : 0), t * 0.62)); }
  const saco = new THREE.Mesh(new THREE.LatheGeometry(perfil, 24), mat(color, { roughness: 0.8 }));
  g.add(saco);
  const nudo = new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.03, 8, 16), mat(0xffffff));
  nudo.position.y = 0.66; nudo.rotation.x = Math.PI / 2; g.add(nudo);
  const tag = new THREE.Mesh(new RoundedBoxGeometry(0.14, 0.09, 0.01, 2, 0.01), mat(0xffffff));
  tag.position.set(0.18, 0.4, 0.17); g.add(tag);
  g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  return g;
}

export function crearLavanderia(mundo, nombre) {
  const g = new THREE.Group(); g.name = 'lavanderia';
  g.position.set(0, 0.18, 1);
  mundo.escena.add(g);

  // piso, paredes con zócalo azul, vidriera al frente
  const piso = new THREE.Mesh(new THREE.PlaneGeometry(ANCHO, FONDO), mat(0xffffff, { map: texPiso(), roughness: 0.7 }));
  piso.rotation.x = -Math.PI / 2; piso.position.y = 0.03; piso.receiveShadow = true; g.add(piso);
  const matPared = mat(0xf9fafe, { roughness: 0.85 });
  const matZocalo = mat(PALETA.azul, { roughness: 0.5 });
  const pared = (w, d, x, z) => {
    const m = new THREE.Mesh(new RoundedBoxGeometry(w, ALTO, d, 2, 0.08), matPared); m.position.set(x, ALTO / 2, z); m.castShadow = m.receiveShadow = true; g.add(m);
    const zz = new THREE.Mesh(new THREE.BoxGeometry(w + 0.02, 0.5, d + 0.02), matZocalo); zz.position.set(x, 0.25, z); g.add(zz);
  };
  pared(ANCHO, 0.3, 0, -FONDO / 2);
  pared(0.3, FONDO, -ANCHO / 2, 0);
  pared(0.3, FONDO, ANCHO / 2, 0);
  // frente: columnas + vidrio + puerta
  const vidrio = new THREE.MeshPhysicalMaterial({ color: 0xcfe6ff, transparent: true, opacity: 0.32, roughness: 0.05, metalness: 0.1 });
  for (const x of [-ANCHO / 2 + 0.2, -3.2, 3.2, ANCHO / 2 - 0.2]) {
    const c = new THREE.Mesh(new RoundedBoxGeometry(0.5, ALTO, 0.5, 2, 0.1), matPared); c.position.set(x, ALTO / 2, FONDO / 2); c.castShadow = true; g.add(c);
  }
  for (const [x, w] of [[-6.6, 6.4], [6.6, 6.4]]) {
    const v = new THREE.Mesh(new THREE.BoxGeometry(w, ALTO - 1.2, 0.08), vidrio); v.position.set(x, (ALTO - 1.2) / 2 + 0.6, FONDO / 2); g.add(v);
    const b = new THREE.Mesh(new THREE.BoxGeometry(w, 0.6, 0.3), matZocalo); b.position.set(x, 0.3, FONDO / 2); g.add(b);
  }
  const dintel = new THREE.Mesh(new RoundedBoxGeometry(ANCHO + 0.3, 0.7, 0.6, 2, 0.12), mat(0xf9fafe, { roughness: 0.85, transparent: true })); dintel.position.set(0, ALTO - 0.15, FONDO / 2); g.add(dintel);

  // letrero con el nombre + toldo
  const letrero = new THREE.Mesh(new THREE.PlaneGeometry(9, 1.7), new THREE.MeshStandardMaterial({ map: texLetrero(nombre), roughness: 0.4, transparent: true }));
  letrero.position.set(0, ALTO + 0.55, FONDO / 2 + 0.32); g.add(letrero);
  // toldo azul con franjas sobre la puerta
  const toldo = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 6, 24, 1, true, 0, Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x5aa0ff, roughness: 0.6, side: THREE.DoubleSide }));
  toldo.rotation.z = Math.PI / 2; toldo.rotation.x = -Math.PI / 2; toldo.position.set(0, ALTO - 0.95, FONDO / 2 + 0.25); toldo.castShadow = true; g.add(toldo);
  // techo con borde azul (se desvanece al acercarse) + equipos en el techo
  const techo = new THREE.Group();
  const matTecho = mat(0xf2f5fc, { transparent: true });
  const losa = new THREE.Mesh(new RoundedBoxGeometry(ANCHO + 0.6, 0.35, FONDO + 0.6, 2, 0.12), matTecho); losa.position.y = ALTO + 0.18; techo.add(losa);
  const matBorde = mat(PALETA.azul, { transparent: true });
  for (const [w, d, x, z] of [[ANCHO + 0.8, 0.3, 0, FONDO / 2 + 0.3], [ANCHO + 0.8, 0.3, 0, -FONDO / 2 - 0.3], [0.3, FONDO + 0.8, ANCHO / 2 + 0.3, 0], [0.3, FONDO + 0.8, -ANCHO / 2 - 0.3, 0]]) {
    const b = new THREE.Mesh(new RoundedBoxGeometry(w, 0.5, d, 2, 0.1), matBorde); b.position.set(x, ALTO + 0.45, z); techo.add(b);
  }
  for (let i = 0; i < 3; i++) {
    const u = new THREE.Mesh(new RoundedBoxGeometry(1.6, 0.8, 1.2, 3, 0.15), mat(0xdfe5f3, { transparent: true })); u.position.set(-6 + i * 4, ALTO + 0.75, -3); techo.add(u);
    const v = new THREE.Mesh(new THREE.CylinderGeometry(0.42, 0.42, 0.06, 24), mat(0x9aa6bf, { transparent: true })); v.position.set(-6 + i * 4, ALTO + 1.18, -3); techo.add(v);
  }
  techo.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  g.add(techo);

  // ───── interior ─────
  const pon = (ruta, x, z, rot, esc) => { if (!disponible(ruta)) return null; const o = copia(ruta, esc); o.position.set(x, 0.03, z); o.rotation.y = rot; g.add(o); return o; };
  // Kenney Furniture: el origen está en una esquina, por eso se compensan medias medidas.
  const lavadoras = [];
  for (let i = 0; i < 5; i++) {
    const x = -9 + i * 1.05;
    const o = pon('mueble/washer', x, -FONDO / 2 + 0.95, 0, 2.2);
    if (o) lavadoras.push(o);
  }
  const secadoras = [];
  for (let i = 0; i < 3; i++) { const o = pon('mueble/washerDryerStacked', -ANCHO / 2 + 0.95, -2.6 + i * 1.1, Math.PI / 2, 2.2); if (o) secadoras.push(o); }
  const vapor = maquinaVapor(); vapor.position.set(2.2, 0.03, -FONDO / 2 + 1.1); g.add(vapor);
  const vapor2 = maquinaVapor(); vapor2.position.set(-0.6, 0.03, -FONDO / 2 + 1.1); vapor2.scale.setScalar(0.9); g.add(vapor2);
  const planchas = [];
  { const m = mesaPlanchar(); m.position.set(8.0, 0.03, -2.2); g.add(m); planchas.push(m); }
  const prensa = prensaUniversal(); prensa.position.set(5.0, 0.03, -2.8); prensa.scale.setScalar(1.15); g.add(prensa);

  // recepción: mostrador redondeado en L + compu
  const mostrador = new THREE.Group();
  const m1 = new THREE.Mesh(new RoundedBoxGeometry(4.2, 1.1, 0.9, 3, 0.15), mat(0xffffff, { roughness: 0.4 })); m1.position.set(0, 0.55, 0); mostrador.add(m1);
  const m2 = new THREE.Mesh(new RoundedBoxGeometry(0.9, 1.1, 2.2, 3, 0.15), mat(0xffffff, { roughness: 0.4 })); m2.position.set(1.65, 0.55, -1.1); mostrador.add(m2);
  const tope = new THREE.Mesh(new RoundedBoxGeometry(4.4, 0.08, 1.05, 2, 0.03), mat(PALETA.azul, { roughness: 0.3 })); tope.position.set(0, 1.13, 0); mostrador.add(tope);
  const franja = new THREE.Mesh(new THREE.BoxGeometry(4.21, 0.16, 0.02), mat(PALETA.azul)); franja.position.set(0, 0.75, 0.46); mostrador.add(franja);
  mostrador.position.set(5.6, 0.03, 4.1);
  mostrador.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  g.add(mostrador);
  const pantalla = pon('mueble/computerScreen', 4.4, 4.0, Math.PI, 2.2); if (pantalla) pantalla.position.y = 1.17;

  // descanso: sofá, mesita, planta, alfombra
  pon('mueble/rugRectangle', -8.4, 3.0, 0, 2.6);
  const sofa = pon('mueble/loungeSofa', -8.8, 5.6, Math.PI, 2.2);
  pon('mueble/loungeChair', -4.6, 2.2, -Math.PI / 2, 2.2);
  pon('mueble/pottedPlant', -9.8, 1.2, 0, 2.4);
  pon('mueble/pottedPlant', 9.4, 6.2, 0, 2.4);
  pon('mueble/lampSquareFloor', -3.8, 5.8, 0, 2.2);

  // segunda fila de lavadoras (espalda con espalda) + carritos con canastos + estantes
  for (let i = 0; i < 4; i++) { const o = pon('mueble/washer', -8.4 + i * 1.05, -2.2, Math.PI, 2.2); if (o) lavadoras.push(o); }
  const carrito = (x, z, color) => {
    const c = new THREE.Group();
    const cesta = new THREE.Mesh(new RoundedBoxGeometry(0.9, 0.55, 0.6, 3, 0.1), mat(0xffffff, { roughness: 0.5 }));
    cesta.position.y = 0.75; c.add(cesta);
    const ropa = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 10), mat(color, { roughness: 0.95 })); ropa.scale.set(1.1, 0.45, 0.75); ropa.position.y = 1.03; c.add(ropa);
    const barra = new THREE.Mesh(new THREE.TorusGeometry(0.28, 0.025, 6, 20, Math.PI), mat(PALETA.azul)); barra.position.set(-0.45, 1.05, 0); barra.rotation.y = Math.PI / 2; c.add(barra);
    for (const [dx, dz] of [[0.35, 0.22], [-0.35, 0.22], [0.35, -0.22], [-0.35, -0.22]]) {
      const pata = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.45, 6), mat(0x9aa6bf, { metalness: 0.6 })); pata.position.set(dx, 0.27, dz); c.add(pata);
      const rd = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), mat(0x2a3142)); rd.position.set(dx, 0.05, dz); c.add(rd);
    }
    c.position.set(x, 0.03, z); c.traverse((o) => { if (o.isMesh) o.castShadow = true; }); g.add(c); return c;
  };
  carrito(-3.8, -4.4, 0xb8d8ff); carrito(-6.2, 0.2, 0xf6c1c7); carrito(3.6, -1.2, 0xc9f0d6);
  const estante = new THREE.Group();
  for (let k = 0; k < 3; k++) {
    const tabla = new THREE.Mesh(new RoundedBoxGeometry(3, 0.08, 0.5, 2, 0.02), mat(0xffffff)); tabla.position.y = 0.6 + k * 0.7; estante.add(tabla);
    for (let b = 0; b < 6; b++) {
      const bot = new THREE.Mesh(new RoundedBoxGeometry(0.22, 0.38, 0.2, 2, 0.05), mat([0x2f6fe0, 0x58c8ff, 0xffffff, 0x9cd8a8][(b + k) % 4], { roughness: 0.35 }));
      bot.position.set(-1.2 + b * 0.48, 0.84 + k * 0.7, 0); estante.add(bot);
    }
  }
  for (const x of [-1.5, 1.5]) { const p = new THREE.Mesh(new THREE.BoxGeometry(0.06, 2.2, 0.5), mat(0xdfe5f3)); p.position.set(x, 1.1, 0); estante.add(p); }
  estante.position.set(-4.6, 0.03, -FONDO / 2 + 0.45); g.add(estante);
  const mesaDoblar = new THREE.Mesh(new RoundedBoxGeometry(2.4, 0.9, 1.0, 3, 0.1), mat(0xffffff, { roughness: 0.45 }));
  mesaDoblar.position.set(1.4, 0.48, -1.2); mesaDoblar.castShadow = true; g.add(mesaDoblar);
  for (let i = 0; i < 4; i++) { const pr = new THREE.Mesh(new RoundedBoxGeometry(0.45, 0.1, 0.35, 2, 0.03), mat(COLORES_ROPA[i], { roughness: 0.95 })); pr.position.set(0.7 + i * 0.5, 0.98 + (i % 2) * 0.1, -1.2); g.add(pr); }
  pon('mueble/chairCushion', -2.4, 5.6, Math.PI, 2.2); pon('mueble/chairCushion', -1.6, 5.6, Math.PI, 2.2);

  // mesa de entrega (ropa lista, doblada)
  const mesaLista = pon('mueble/tableCloth', 0.6, 3.6, 0, 2.2);
  const grupoListas = new THREE.Group(); grupoListas.position.set(1.5, 0.82, 3.1); g.add(grupoListas);

  // sección de colgados (cola): riel largo en la pared derecha
  const riel = new THREE.Group();
  const barra = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 7.5, 12), mat(0x9aa6bf, { metalness: 0.7, roughness: 0.25 }));
  barra.rotation.x = Math.PI / 2; barra.position.y = 2.2; riel.add(barra);
  for (const z of [-3.6, 0, 3.6]) {
    const p = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 2.2, 10), mat(0x9aa6bf, { metalness: 0.7 })); p.position.set(0, 1.1, z); riel.add(p);
  }
  riel.position.set(ANCHO / 2 - 0.9, 0.03, -2.6);
  g.add(riel);
  const colgados = new THREE.Group(); colgados.position.copy(riel.position); colgados.position.y += 2.2; g.add(colgados);
  // bolsas recién recibidas (cola de entrada, junto al mostrador)
  const colaBolsas = new THREE.Group(); colaBolsas.position.set(8.3, 0.03, 1.4); g.add(colaBolsas);

  const cartel = (texto, x, z, alto = 3.3) => {
    const c = document.createElement('canvas'); c.width = 256; c.height = 64; const gg = c.getContext('2d');
    gg.fillStyle = '#ffffff'; gg.beginPath(); gg.roundRect(0, 0, 256, 64, 18); gg.fill();
    gg.fillStyle = '#2f6fe0'; gg.font = 'bold 30px system-ui'; gg.textAlign = 'center'; gg.textBaseline = 'middle'; gg.fillText(texto, 128, 34);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthWrite: false })); s.scale.set(2.2, 0.55, 1); s.position.set(x, alto, z); g.add(s);
  };
  cartel('Recepción', 5.6, 4.1); cartel('Lavado', -7, -6); cartel('Vapor / seco', 1, -6); cartel('Planchado', 8, -2.2); cartel('Prensa', 5, -2.7, 3.4);
  cartel('Colgados', ANCHO / 2 - 1, -2.6); cartel('Descanso', -8, 3.6); cartel('Secado', -ANCHO / 2 + 1.2, -1.4);

  // estaciones (coordenadas locales → mundo) donde se paran los empleados
  const L = (x, z) => new THREE.Vector3(x, 0, z).add(new THREE.Vector3(0, 0.18, 1));
  const estaciones = {
    recepcion: [{ p: L(5.4, 2.9), ang: 0, anim: 'idle' }, { p: L(3.9, 2.9), ang: 0, anim: 'idle' }],
    descanso: [{ p: L(-8.3, 5.05), ang: Math.PI, anim: 'sit' }, { p: L(-7.2, 5.05), ang: Math.PI, anim: 'sit' }, { p: L(-4.5, 2.6), ang: -Math.PI / 2, anim: 'sit' }],
    lavando: [{ p: L(-7.4, -4.6), ang: Math.PI, anim: 'interact-right' }, { p: L(-5.3, -4.6), ang: Math.PI, anim: 'interact-left' }],
    secando: [{ p: L(-8.6, -1.5), ang: -Math.PI / 2, anim: 'interact-right' }, { p: L(-8.6, 0.6), ang: -Math.PI / 2, anim: 'interact-left' }],
    vapor: [{ p: L(1.9, -4.3), ang: Math.PI, anim: 'interact-right' }, { p: L(-0.9, -4.3), ang: Math.PI, anim: 'interact-right' }],
    planchando: [{ p: L(8.0, -1.45), ang: Math.PI, anim: 'interact-right' }, { p: L(6.6, -1.45), ang: Math.PI, anim: 'interact-left' }],
    prensa: [{ p: L(5.0, -1.45), ang: Math.PI, anim: 'interact-right' }],
    colgando: [{ p: L(9.3, -2.6), ang: Math.PI / 2, anim: 'holding-both' }],
  };
  const puerta = L(0, FONDO / 2 + 1.2);     // vereda frente a la puerta
  const mostradorCliente = L(5.4, 5.3);       // donde se para quien entrega
  const mostradorEmpleado = L(5.4, 2.9);

  // estado visible: colgados, bolsas, listas, máquinas girando
  let girando = 0, ultimoN = { colgados: -1, bolsas: -1, listas: -1 };
  function set({ colgadosN = 0, bolsasN = 0, listasN = 0, lavando = 0 }) {
    girando = lavando;
    if (colgadosN !== ultimoN.colgados) {
      colgados.clear();
      const n = Math.min(colgadosN, 22);
      for (let i = 0; i < n; i++) { const p = prendaColgada(COLORES_ROPA[i % COLORES_ROPA.length]); p.position.z = -3.4 + i * 0.32; p.rotation.y = Math.PI / 2; colgados.add(p); }
      ultimoN.colgados = colgadosN;
    }
    if (bolsasN !== ultimoN.bolsas) {
      colaBolsas.clear();
      for (let i = 0; i < Math.min(bolsasN, 9); i++) { const b = bolsaRopa([0x2f6fe0, 0x5aa0ff, 0x1d4fb8][i % 3]); b.position.set((i % 3) * 0.55, Math.floor(i / 3) * 0.0, -Math.floor(i / 3) * 0.55); colaBolsas.add(b); }
      ultimoN.bolsas = bolsasN;
    }
    if (listasN !== ultimoN.listas) {
      grupoListas.clear();
      for (let i = 0; i < Math.min(listasN, 6); i++) {
        const pila = new THREE.Mesh(new RoundedBoxGeometry(0.42, 0.12, 0.32, 2, 0.04), mat(COLORES_ROPA[(i + 3) % COLORES_ROPA.length], { roughness: 0.95 }));
        pila.position.set(-(i % 3) * 0.5, Math.floor(i / 3) * 0.13, 0); pila.castShadow = true; grupoListas.add(pila);
      }
      ultimoN.listas = listasN;
    }
  }

  // todo lo que no se mueve dentro del local se fusiona (menos llamadas de dibujo, mismo aspecto)
  const dinamicos = new Set([techo, letrero, dintel, vapor, vapor2, prensa, colgados, colaBolsas, grupoListas, ...lavadoras, ...planchas]);
  const estaticos = g.children.filter((o) => !dinamicos.has(o) && !o.isSprite && (o.isMesh || o.isGroup || o.type === 'Object3D'));
  const fusionadas = fusionar(estaticos, g);
  estaticos.forEach((o) => g.remove(o));
  fusionadas.forEach((m) => g.add(m));

  // animación: techo según distancia, máquinas, vapor
  let prensando = false;
  const vaporPrensa = [];
  for (let i = 0; i < 8; i++) { const s = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5, depthWrite: false })); s.userData.f = i / 8; g.add(s); vaporPrensa.push(s); }
  mundo.cadaCuadro((dt, t) => {
    // ciclo de la prensa: baja 2 s (con vapor), sube 1.5 s
    const ciclo = (t % 3.5) / 3.5;
    const abajo = prensando && ciclo < 0.57;
    const cab = prensa.userData.cabezal;
    cab.position.y += ((abajo ? 1.3 : 1.42) - cab.position.y) * Math.min(1, dt * 6);
    for (const s of vaporPrensa) {
      s.visible = abajo;
      s.userData.f = (s.userData.f + dt * 0.6) % 1;
      const f = s.userData.f;
      s.position.set(5.0 - 0.7 + (s.userData.f * 7 % 1.4), 1.45 + f * 1.1, -2.8 + Math.sin(f * 8) * 0.1);
      s.scale.setScalar(0.5 + f * 1.6); s.material.opacity = 0.5 * (1 - f);
    }
  });
  const vaporParts = [];
  const matVapor = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5, depthWrite: false });
  for (let i = 0; i < 10; i++) { const s = new THREE.Mesh(new THREE.SphereGeometry(0.18, 10, 8), matVapor); s.userData.f = Math.random(); g.add(s); vaporParts.push(s); }
  let vaporActivo = false;
  const _c = new THREE.Vector3();
  mundo.cadaCuadro((dt, t) => {
    const d = mundo.camara.position.distanceTo(g.getWorldPosition(_c));
    const op = THREE.MathUtils.clamp((d - 55) / 30, 0, 1);
    techo.visible = op > 0.02;
    techo.traverse((o) => { if (o.isMesh) { o.material.opacity = op; o.material.depthWrite = op > 0.9; } });
    letrero.material.opacity = 0.12 + op * 0.88;
    dintel.material.opacity = 0.25 + op * 0.75;
    lavadoras.forEach((l, i) => { l.userData.x0 ??= l.position.x; const on = i < girando; l.position.x = l.userData.x0 + (on ? Math.sin(t * 40 + i) * 0.012 : 0); });
    vapor.userData.tambor.rotation.z += dt * (vaporActivo ? 6 : 0.4);
    vapor2.userData.tambor.rotation.z += dt * 3;
    for (const s of vaporParts) {
      s.userData.f += dt * 0.35; if (s.userData.f > 1) s.userData.f -= 1;
      const f = s.userData.f;
      s.visible = vaporActivo;
      s.position.set(3.05 + Math.sin(f * 9) * 0.15, 2.9 + f * 2, -FONDO / 2 + 0.8);
      s.scale.setScalar(0.6 + f * 1.8);
    }
    matVapor.opacity = 0.45;
    planchas.forEach((m, i) => { m.userData.plancha.position.x = 0.1 + Math.sin(t * 2.4 + i) * 0.35; });
  });

  return {
    renombrar: (n) => { letrero.material.map = texLetrero(n); letrero.material.needsUpdate = true; },
    grupo: g, estaciones, puerta, mostradorCliente, mostradorEmpleado, set,
    colaBolsas, colgados, riel, ancho: ANCHO, fondo: FONDO,
    vapor: (on) => { vaporActivo = on; },
    prensar: (on) => { prensando = on; },
    frenteCalle: { x: 0, z: 18, eje: 'x' },          // calle al sur de la manzana central
    estacionamiento: L(3.6, FONDO / 2 + 2.6),
  };
}
