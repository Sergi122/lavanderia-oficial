/* Casa en construcción en el lote del cliente mientras arma su pedido:
   cerco, conos, grúa con gancho y la casa subiendo dentro de un andamio.
   confirmar() → termina de construirse (brillo + pin); cancelar() → se derrumba con polvo. */
import * as THREE from 'three';
import { RoundedBoxGeometry } from '../vendor/jsm/geometries/RoundedBoxGeometry.js';
import { copia, disponible } from './modelos.js';

const m = (c, e = {}) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.6, ...e });

function grua() {
  const g = new THREE.Group();
  const amarillo = m(0xffc23d, { roughness: 0.45 });
  const mastil = new THREE.Group();
  for (let i = 0; i < 12; i++) {
    const anillo = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.05, 4, 4), amarillo);
    anillo.rotation.x = Math.PI / 2; anillo.rotation.z = Math.PI / 4; anillo.position.y = i * 0.9; mastil.add(anillo);
  }
  for (const [x, z] of [[0.3, 0.3], [-0.3, 0.3], [0.3, -0.3], [-0.3, -0.3]]) {
    const p = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 10.8, 6), amarillo); p.position.set(x, 5.4, z); mastil.add(p);
  }
  g.add(mastil);
  const brazo = new THREE.Group(); brazo.position.y = 10.8; g.add(brazo);
  const pluma = new THREE.Mesh(new RoundedBoxGeometry(11, 0.45, 0.45, 2, 0.08), amarillo); pluma.position.x = 3.2; brazo.add(pluma);
  const contrapeso = new THREE.Mesh(new RoundedBoxGeometry(1.4, 0.9, 0.9, 2, 0.1), m(0x9aa6bf)); contrapeso.position.set(-2.2, -0.4, 0); brazo.add(contrapeso);
  const cabina = new THREE.Mesh(new RoundedBoxGeometry(0.9, 0.8, 0.9, 2, 0.12), m(0xffffff)); cabina.position.set(0.5, -0.65, 0); brazo.add(cabina);
  const cable = new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 1, 4), m(0x333a48)); cable.position.set(6, -2, 0); brazo.add(cable);
  const gancho = new THREE.Mesh(new RoundedBoxGeometry(0.9, 0.5, 0.9, 2, 0.1), m(0xd65a3a)); brazo.add(gancho);
  g.userData = { brazo, cable, gancho };
  g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  return g;
}

export class Construccion {
  /** lote: {x,z,rot,obj(modelo de la casa original),modelo} */
  constructor(mundo, lote, etiqueta) {
    this.mundo = mundo; this.lote = lote; this.estado = 'armando'; this.t = 0;
    const g = this.g = new THREE.Group(); g.position.set(lote.x, 0.18, lote.z); g.rotation.y = lote.rot;
    mundo.escena.add(g);
    if (lote.ocultar) lote.ocultar(true); else if (lote.obj) lote.obj.visible = false;
    // terreno de tierra + losa
    const tierra = new THREE.Mesh(new THREE.CircleGeometry(6.2, 40), m(0xd9c6a5, { roughness: 1 })); tierra.rotation.x = -Math.PI / 2; tierra.position.y = 0.01; g.add(tierra);
    const losa = new THREE.Mesh(new RoundedBoxGeometry(8.4, 0.3, 6.6, 2, 0.08), m(0xdfe3ec)); losa.position.y = 0.15; g.add(losa);
    // cerco y conos
    if (disponible('road/construction-fence')) for (let i = 0; i < 4; i++) {
      const f = copia('road/construction-fence'); f.position.set(-4.6 + i * 3.0, 0, 4.3); f.rotation.y = Math.PI / 2; g.add(f);
    }
    if (disponible('road/construction-cone')) for (const x of [-5.2, 5.2]) { const c = copia('road/construction-cone'); c.position.set(x, 0, 4.9); g.add(c); }
    // casa nueva (mismo modelo del lote) que crece dentro del andamio
    this.casa = lote.modelo && disponible(lote.modelo) ? copia(lote.modelo) : new THREE.Mesh(new RoundedBoxGeometry(7, 5, 6, 2, 0.2), m(0xffffff));
    this.casa.position.y = 0.3;
    // se "construye" de abajo hacia arriba: un plano de corte que va subiendo
    this.corte = new THREE.Plane(new THREE.Vector3(0, -1, 0), 0);
    this.casa.traverse((o) => {
      if (!o.isMesh) return;
      o.material = (Array.isArray(o.material) ? o.material : [o.material]).map((mm) => { const c = mm.clone(); c.clippingPlanes = [this.corte]; c.side = THREE.DoubleSide; return c; });
      if (o.material.length === 1) o.material = o.material[0];
    });
    g.add(this.casa);
    this.altoCasa = new THREE.Box3().setFromObject(this.casa).getSize(new THREE.Vector3()).y || 6;
    this.escalaFinal = this.casa.scale.x;
    // andamio (tubos)
    const andamio = this.andamio = new THREE.Group();
    const tubo = m(0x8f9bb5, { metalness: 0.6, roughness: 0.3 });
    for (const x of [-4.3, -1.4, 1.4, 4.3]) for (const z of [-3.6, 3.6]) {
      const p = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 7, 6), tubo); p.position.set(x, 3.5, z); andamio.add(p);
    }
    for (const y of [1.8, 3.6, 5.4]) for (const z of [-3.6, 3.6]) {
      const b = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 8.6, 6), tubo); b.rotation.z = Math.PI / 2; b.position.set(0, y, z); andamio.add(b);
      const tabla = new THREE.Mesh(new THREE.BoxGeometry(8.6, 0.08, 0.6), m(0xc79a5b)); tabla.position.set(0, y, z * 1.08); andamio.add(tabla);
    }
    g.add(andamio);
    this.grua = grua(); this.grua.position.set(-5.6, 0, -2.6); g.add(this.grua);
    g.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    // polvo / chispas
    this.parts = [];
    const pm = new THREE.MeshBasicMaterial({ color: 0xf1e3c8, transparent: true, opacity: 0.7, depthWrite: false });
    for (let i = 0; i < 26; i++) { const p = new THREE.Mesh(new THREE.SphereGeometry(0.35, 8, 6), pm.clone()); p.visible = false; g.add(p); this.parts.push(p); }
    this.etiqueta = mundo.etiqueta(g, etiqueta, { alto: 9, clase: 'chip-obra' });
    this.quitar = mundo.cadaCuadro((dt, t) => this._paso(dt, t));
  }
  confirmar(etiquetaFinal) { if (this.estado !== 'armando') return; this.estado = 'terminando'; this.t = 0; this.etiqueta.set(etiquetaFinal); }
  cancelar() { if (this.estado !== 'armando') return; this.estado = 'derrumbe'; this.t = 0; this.etiqueta.set('❌ Pedido cancelado'); this._polvo(); }
  _polvo(color = 0xf1e3c8) {
    for (const p of this.parts) {
      p.visible = true; p.material.color.setHex(color); p.material.opacity = 0.75;
      p.position.set((Math.random() - 0.5) * 7, 0.5 + Math.random() * 2, (Math.random() - 0.5) * 6);
      p.userData.v = new THREE.Vector3((Math.random() - 0.5) * 3, 1 + Math.random() * 2.5, (Math.random() - 0.5) * 3);
    }
  }
  _paso(dt, t) {
    this.t += dt;
    const { brazo, cable, gancho } = this.grua.userData;
    brazo.rotation.y = Math.sin(t * 0.4) * 0.7;
    const largo = 3 + Math.sin(t * 0.9) * 1.5;
    cable.scale.y = largo; cable.position.y = -largo / 2 - 0.2; gancho.position.set(6, -largo - 0.4, 0);
    const sc = this.escalaFinal;
    const alto = (k) => { this.corte.constant = this.g.position.y + 0.3 + this.altoCasa * k; };
    if (this.estado === 'armando') {
      // sube despacio hasta 60% mientras el cliente sigue armando su pedido
      alto(Math.min(0.6, 0.06 + this.t * 0.035));
    } else if (this.estado === 'terminando') {
      alto(Math.min(1.05, 0.6 + this.t * 0.4));
      this.andamio.position.y = -this.t * 4; this.grua.position.y = -Math.max(0, this.t - 0.6) * 9;
      if (this.t > 0.9 && !this._brillo) { this._brillo = true; this._polvo(0xffffff); }
      if (this.t > 2.4) { this.andamio.visible = false; this.grua.visible = false; this.estado = 'lista'; }
    } else if (this.estado === 'derrumbe') {
      alto(Math.max(0, 0.6 - this.t * 0.35));
      this.casa.position.y = 0.3 - this.t * 0.6;
      this.casa.rotation.z = Math.min(0.25, this.t * 0.2);
      this.andamio.rotation.z = Math.min(0.6, this.t * 0.5); this.andamio.position.y = -this.t * 1.5;
      this.grua.rotation.z = -Math.min(1.2, this.t * 0.7);
      if (this.t > 3) this.destruir();
    }
    for (const p of this.parts) if (p.visible) {
      p.position.addScaledVector(p.userData.v, dt); p.userData.v.y -= dt * 0.8; p.scale.multiplyScalar(1 + dt * 0.6);
      p.material.opacity -= dt * 0.35; if (p.material.opacity <= 0) p.visible = false;
    }
  }
  /** La casa terminada vuelve a ser la del lote (se usa para mostrar el pedido). */
  destruir() {
    this.quitar(); this.etiqueta.quitar(); this.mundo.escena.remove(this.g);
    if (this.lote.ocultar) this.lote.ocultar(false); else if (this.lote.obj) this.lote.obj.visible = true;
    this.estado = 'fin';
  }
}
