/* Escenario base: renderer, cámara con órbita limitada (vista "juego de estrategia"),
   luz suave tipo WareTrack, suelo, etiquetas HTML proyectadas y selección por clic. */
import * as THREE from 'three';
import { OrbitControls } from '../vendor/OrbitControls.js';

export const PALETA = {
  fondo: 0xeef1fb, suelo: 0xe6eaf6, vereda: 0xf4f6fc, cesped: 0xcfe8cf,
  asfalto: 0xd9deec, linea: 0xffffff, azul: 0x2f6fe0, azulOsc: 0x1d4fb8, tinta: 0x0a1c33,
};

export function crearMundo(contenedor) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.localClippingEnabled = true;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  contenedor.appendChild(renderer.domElement);

  const escena = new THREE.Scene();
  escena.background = new THREE.Color(PALETA.fondo);
  escena.fog = new THREE.Fog(PALETA.fondo, 170, 420);

  const camara = new THREE.PerspectiveCamera(30, 1, 0.5, 900);
  camara.position.set(70, 75, 95);

  const controles = new OrbitControls(camara, renderer.domElement);
  controles.enableDamping = true;
  controles.dampingFactor = 0.08;
  controles.minDistance = 14;
  controles.maxDistance = 330;
  controles.minPolarAngle = 0.35;
  controles.maxPolarAngle = 1.18;
  controles.screenSpacePanning = false;
  controles.target.set(0, 0, 4);
  controles.mouseButtons = { LEFT: THREE.MOUSE.PAN, MIDDLE: THREE.MOUSE.DOLLY, RIGHT: THREE.MOUSE.ROTATE };
  controles.touches = { ONE: THREE.TOUCH.PAN, TWO: THREE.TOUCH.DOLLY_ROTATE };

  // Luz: cielo/suelo lavanda + sol cálido con sombras suaves que siguen al foco.
  escena.add(new THREE.HemisphereLight(0xffffff, 0xb9c3e6, 1.55));
  const sol = new THREE.DirectionalLight(0xfff3e2, 2.3);
  sol.position.set(60, 110, 45);
  sol.castShadow = true;
  sol.shadow.mapSize.set(2048, 2048);
  const sc = sol.shadow.camera; sc.left = -95; sc.right = 95; sc.top = 95; sc.bottom = -95; sc.near = 10; sc.far = 320;
  sol.shadow.bias = -0.0004; sol.shadow.normalBias = 0.04; sol.shadow.radius = 3;
  escena.add(sol, sol.target);
  const relleno = new THREE.DirectionalLight(0xdfe7ff, 0.55);
  relleno.position.set(-60, 40, -70);
  escena.add(relleno);

  const suelo = new THREE.Mesh(new THREE.PlaneGeometry(1400, 1400), new THREE.MeshStandardMaterial({ color: PALETA.suelo, roughness: 1 }));
  suelo.rotation.x = -Math.PI / 2; suelo.receiveShadow = true; suelo.position.y = -0.02;
  escena.add(suelo);

  // Etiquetas HTML que siguen a un objeto 3D (chips como "PAL-1026 Safety Helmet").
  const capa = document.createElement('div');
  capa.className = 'capa-etiquetas';
  contenedor.appendChild(capa);
  const etiquetas = new Set();
  function etiqueta(obj, html, { alto = 2.2, clase = '' } = {}) {
    const el = document.createElement('div');
    el.className = 'etiqueta ' + clase;
    el.innerHTML = html;
    capa.appendChild(el);
    const e = { obj, el, alto, visible: true, set(h) { el.innerHTML = h; }, quitar() { el.remove(); etiquetas.delete(e); } };
    etiquetas.add(e);
    return e;
  }
  const _v = new THREE.Vector3();
  function proyectarEtiquetas(w, h) {
    for (const e of etiquetas) {
      if (!e.obj.parent || !e.visible) { e.el.style.display = 'none'; continue; }
      e.obj.getWorldPosition(_v); _v.y += e.alto;
      const d = _v.distanceTo(camara.position);
      _v.project(camara);
      const fuera = _v.z > 1 || Math.abs(_v.x) > 1.1 || Math.abs(_v.y) > 1.1 || d > 260;
      e.el.style.display = fuera ? 'none' : '';
      if (!fuera) {
        e.el.style.transform = `translate(-50%,-100%) translate(${(_v.x * 0.5 + 0.5) * w}px,${(-_v.y * 0.5 + 0.5) * h}px)`;
        e.el.style.opacity = d > 170 ? Math.max(0, 1 - (d - 170) / 90) : 1;
      }
    }
  }

  // Selección: cualquier objeto con userData.seleccion = {tipo, id} es clicable.
  const elegibles = [];
  const ray = new THREE.Raycaster();
  const _p = new THREE.Vector2();
  let alElegir = () => {}, alPasar = () => {};
  let abajo = null;
  function buscar(ev) {
    const r = renderer.domElement.getBoundingClientRect();
    _p.set(((ev.clientX - r.left) / r.width) * 2 - 1, -((ev.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(_p, camara);
    const hit = ray.intersectObjects(elegibles, true)[0];
    let o = hit?.object;
    while (o && !o.userData.seleccion) o = o.parent;
    return o || null;
  }
  renderer.domElement.addEventListener('pointerdown', (e) => { abajo = [e.clientX, e.clientY]; });
  renderer.domElement.addEventListener('pointerup', (e) => {
    if (!abajo || Math.hypot(e.clientX - abajo[0], e.clientY - abajo[1]) > 5) return;
    alElegir(buscar(e));
  });
  let ultimoHover = 0;
  renderer.domElement.addEventListener('pointermove', (e) => {
    const t = performance.now(); if (t - ultimoHover < 60) return; ultimoHover = t;
    const o = buscar(e);
    renderer.domElement.style.cursor = o ? 'pointer' : 'grab';
    alPasar(o);
  });

  // Vuelo suave de cámara hacia un objetivo (target + distancia + ángulos).
  let vuelo = null;
  function volarA(target, { dist = 60, azimut = null, polar = 0.95, dur = 1.4 } = {}) {
    const desde = { t: controles.target.clone(), p: camara.position.clone() };
    const off = camara.position.clone().sub(controles.target);
    const sph = new THREE.Spherical().setFromVector3(off);
    sph.radius = dist; sph.phi = polar; if (azimut != null) sph.theta = azimut;
    const hastaP = new THREE.Vector3().setFromSpherical(sph).add(target);
    vuelo = { desde, hastaT: target.clone(), hastaP, t: 0, dur };
  }
  function actualizarVuelo(dt) {
    if (!vuelo) return;
    vuelo.t = Math.min(1, vuelo.t + dt / vuelo.dur);
    const k = vuelo.t < 0.5 ? 4 * vuelo.t ** 3 : 1 - Math.pow(-2 * vuelo.t + 2, 3) / 2;
    controles.target.lerpVectors(vuelo.desde.t, vuelo.hastaT, k);
    camara.position.lerpVectors(vuelo.desde.p, vuelo.hastaP, k);
    if (vuelo.t >= 1) vuelo = null;
  }
  controles.addEventListener('start', () => { vuelo = null; });

  function redimensionar() {
    const w = contenedor.clientWidth || innerWidth, h = contenedor.clientHeight || innerHeight;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = w + 'px'; renderer.domElement.style.height = h + 'px';
    camara.aspect = w / h; camara.updateProjectionMatrix();
  }
  addEventListener('resize', redimensionar);
  redimensionar();

  const tareas = new Set();
  const reloj = new THREE.Timer();
  function cuadro() {
    reloj.update(); const dt = Math.min(reloj.getDelta(), 0.05), t = reloj.getElapsed();
    actualizarVuelo(dt);
    controles.update();
    // la sombra sigue al punto que se mira (cubre 190 m alrededor)
    sol.position.set(controles.target.x + 60, 110, controles.target.z + 45);
    sol.target.position.copy(controles.target);
    for (const f of tareas) f(dt, t);
    renderer.render(escena, camara);
    proyectarEtiquetas(renderer.domElement.clientWidth, renderer.domElement.clientHeight);
  }
  renderer.setAnimationLoop(cuadro);

  return {
    THREE, renderer, escena, camara, controles, sol, etiqueta, elegibles, volarA,
    cadaCuadro: (f) => { tareas.add(f); return () => tareas.delete(f); },
    alElegir: (f) => { alElegir = f; }, alPasar: (f) => { alPasar = f; },
  };
}
