/* Personajes animados (Kenney Mini Characters: idle, walk, sit, drive, pick-up,
   holding-both, interact-right…) y la moto repartidora hecha con formas suaves. */
import * as THREE from 'three';
import { RoundedBoxGeometry } from '../vendor/jsm/geometries/RoundedBoxGeometry.js';
import { personaje, disponible } from './modelos.js';
import { bolsaRopa } from './lavanderia.js';

export const MODELOS_GENTE = ['a', 'b', 'c', 'd', 'e', 'f'].flatMap((l) => [`gente/character-female-${l}`, `gente/character-male-${l}`]);

/** Elige un modelo estable para un id (el mismo empleado siempre se ve igual). */
export function modeloPara(id = '') {
  let h = 0; for (const ch of String(id)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  const lista = MODELOS_GENTE.filter(disponible);
  return lista[h % lista.length];
}

export class Persona {
  constructor(mundo, ruta, { alto = 1.72 } = {}) {
    const { obj, clips } = personaje(ruta, alto);
    this.mundo = mundo;
    this.raiz = new THREE.Group();
    this.raiz.add(obj);
    obj.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.frustumCulled = false; } });
    this.mixer = new THREE.AnimationMixer(obj);
    this.acciones = Object.fromEntries(clips.map((c) => [c.name, this.mixer.clipAction(c)]));
    this.actual = null;
    this.camino = null;
    this.vel = 1.5;
    this.bolsa = null;
    this.quitarTarea = mundo.cadaCuadro((dt) => this._paso(dt));
    this.animar('idle');
  }
  animar(nombre, { una = false, fundido = 0.25 } = {}) {
    const a = this.acciones[nombre] || this.acciones.idle;
    if (!a || this.actual === a) return a;
    a.reset();
    a.setLoop(una ? THREE.LoopOnce : THREE.LoopRepeat, Infinity);
    a.clampWhenFinished = una;
    a.fadeIn(fundido).play();
    if (this.actual) this.actual.fadeOut(fundido);
    this.actual = a;
    return a;
  }
  /** Camina por una lista de puntos (Vector3) y resuelve la promesa al llegar. */
  caminar(puntos, { vel = 1.5, anim } = {}) {
    this.vel = vel;
    return new Promise((ok) => {
      this.camino = { pts: puntos.map((p) => p.clone()), i: 0, ok };
      this.animar(anim || (this.bolsa ? 'holding-both' : 'walk'));
    });
  }
  ponerEn(p, ang = 0) { this.raiz.position.copy(p); this.raiz.rotation.y = ang; }
  mirar(ang) { this.angObjetivo = ang; }
  cargar(bolsa = true, color) {
    if (bolsa && !this.bolsa) {
      this.bolsa = bolsaRopa(color);
      this.bolsa.scale.setScalar(1.25);
      this.bolsa.position.set(0, 0.62, 0.32);
      this.raiz.add(this.bolsa);
    } else if (!bolsa && this.bolsa) { this.raiz.remove(this.bolsa); this.bolsa = null; }
  }
  _paso(dt) {
    // de lejos no se nota: el esqueleto se actualiza a menor frecuencia
    this._acum = (this._acum || 0) + dt;
    const lejos = this.raiz.parent === this.mundo.escena && this.mundo.camara.position.distanceToSquared(this.raiz.position) > 110 * 110;
    if (!lejos || this._acum > 0.12) { this.mixer.update(this._acum); this._acum = 0; }
    const c = this.camino;
    if (c) {
      const obj = c.pts[c.i];
      const pos = this.raiz.position;
      const dx = obj.x - pos.x, dz = obj.z - pos.z, d = Math.hypot(dx, dz);
      const paso = this.vel * dt;
      if (d <= paso) {
        pos.x = obj.x; pos.z = obj.z;
        if (++c.i >= c.pts.length) { this.camino = null; this.animar(this.bolsa ? 'holding-both' : 'idle'); if (this.bolsa) this.actual?.setEffectiveTimeScale(0); c.ok(); }
      } else {
        pos.x += (dx / d) * paso; pos.z += (dz / d) * paso;
        this.angObjetivo = Math.atan2(dx, dz);
        if (this.bolsa) this.actual?.setEffectiveTimeScale(1);
      }
    }
    if (this.angObjetivo != null) {
      let da = this.angObjetivo - this.raiz.rotation.y;
      da = Math.atan2(Math.sin(da), Math.cos(da));
      this.raiz.rotation.y += da * Math.min(1, dt * 8);
    }
  }
  destruir() { this.quitarTarea(); this.raiz.parent?.remove(this.raiz); this.mixer.stopAllAction(); }
}

/* ───────── moto repartidora (scooter con caja de reparto) ───────── */
const m = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.45, ...extra });
function rueda() {
  const g = new THREE.Group();
  const llanta = new THREE.Mesh(new THREE.TorusGeometry(0.27, 0.1, 14, 32), m(0x232a3a, { roughness: 0.8 }));
  const aro = new THREE.Mesh(new THREE.CylinderGeometry(0.19, 0.19, 0.12, 24), m(0xdfe5f3, { metalness: 0.6, roughness: 0.25 }));
  aro.rotation.x = Math.PI / 2;
  const eje = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.16, 12), m(0x2f6fe0));
  eje.rotation.x = Math.PI / 2;
  g.add(llanta, aro, eje);
  g.rotation.y = Math.PI / 2;
  return g;
}
function texCaja() {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.fillStyle = '#2f6fe0'; g.fillRect(0, 0, 128, 128);
  g.fillStyle = '#fff'; g.beginPath(); g.arc(64, 58, 30, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#2f6fe0'; g.beginPath(); g.arc(64, 62, 16, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#9fd2ff'; g.beginPath(); g.arc(64, 62, 10, 0, Math.PI * 2); g.fill();
  g.fillStyle = '#fff'; g.font = 'bold 15px system-ui'; g.textAlign = 'center'; g.fillText('LAVANDERÍA', 64, 112);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
let _texCaja;
export function crearMoto() {
  const g = new THREE.Group();
  const cuerpo = new THREE.Group(); g.add(cuerpo);
  // carrocería: perfil lateral extruido con bisel (forma de scooter)
  const s = new THREE.Shape();
  s.moveTo(-0.75, 0.32); s.lineTo(0.35, 0.32); s.quadraticCurveTo(0.62, 0.34, 0.66, 0.62);
  s.lineTo(0.78, 1.05); s.lineTo(0.62, 1.08); s.lineTo(0.48, 0.6); s.lineTo(-0.1, 0.58);
  s.quadraticCurveTo(-0.3, 0.86, -0.72, 0.8); s.quadraticCurveTo(-0.92, 0.6, -0.75, 0.32);
  const geo = new THREE.ExtrudeGeometry(s, { depth: 0.36, bevelEnabled: true, bevelSize: 0.06, bevelThickness: 0.06, bevelSegments: 4, curveSegments: 16 });
  geo.translate(0, 0, -0.18);
  const carro = new THREE.Mesh(geo, m(0xffffff, { roughness: 0.3 }));
  carro.rotation.y = -Math.PI / 2; cuerpo.add(carro);
  const franja = new THREE.Mesh(new RoundedBoxGeometry(0.44, 0.08, 1.1, 2, 0.03), m(0x2f6fe0)); franja.position.set(0, 0.5, -0.15); cuerpo.add(franja);
  const asiento = new THREE.Mesh(new RoundedBoxGeometry(0.34, 0.12, 0.62, 3, 0.05), m(0x1f2740, { roughness: 0.7 })); asiento.position.set(0, 0.86, -0.42); cuerpo.add(asiento);
  const manubrio = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.7, 10), m(0x2a3142)); manubrio.rotation.z = Math.PI / 2; manubrio.position.set(0, 1.12, 0.66); cuerpo.add(manubrio);
  const farol = new THREE.Mesh(new THREE.SphereGeometry(0.08, 14, 10), new THREE.MeshStandardMaterial({ color: 0xfff6d0, emissive: 0xfff0b0, emissiveIntensity: 0.8 })); farol.position.set(0, 1.0, 0.78); cuerpo.add(farol);
  _texCaja ??= texCaja();
  const caja = new THREE.Mesh(new RoundedBoxGeometry(0.62, 0.55, 0.6, 3, 0.08), [m(0x2f6fe0), m(0x2f6fe0), m(0x2f6fe0), m(0x2f6fe0), new THREE.MeshStandardMaterial({ map: _texCaja }), new THREE.MeshStandardMaterial({ map: _texCaja })]);
  caja.position.set(0, 1.2, -0.95); cuerpo.add(caja);
  const r1 = rueda(); r1.position.set(0, 0.37, 0.62); g.add(r1);
  const r2 = rueda(); r2.position.set(0, 0.37, -0.68); g.add(r2);
  g.traverse((o) => { if (o.isMesh) { o.castShadow = true; } });
  g.userData.ruedas = [r1, r2];
  g.userData.caja = caja;
  return g;
}

/** Moto con su repartidor sentado (animación "drive"). */
export class Repartidor {
  constructor(mundo, id) {
    this.mundo = mundo;
    this.raiz = new THREE.Group();
    this.moto = crearMoto();
    this.raiz.add(this.moto);
    this.conductor = new Persona(mundo, modeloPara('rep' + id));
    this.conductor.raiz.position.set(0, 0.42, -0.25);
    this.conductor.animar('drive');
    this.raiz.add(this.conductor.raiz);
    this.quitar = mundo.cadaCuadro((dt) => {
      const v = this.raiz.userData.vel || 0;
      for (const r of this.moto.userData.ruedas) r.rotation.x += v * dt / 0.37;
      this.moto.rotation.z = Math.sin(performance.now() / 300) * 0.01 * Math.min(1, v);
    });
  }
  bajar() { this.raiz.remove(this.conductor.raiz); return this.conductor; }
  subir() { this.conductor.raiz.position.set(0, 0.42, -0.25); this.conductor.raiz.rotation.set(0, 0, 0); this.conductor.animar('drive'); this.raiz.add(this.conductor.raiz); }
  destruir() { this.quitar(); this.conductor.destruir(); this.raiz.parent?.remove(this.raiz); }
}
