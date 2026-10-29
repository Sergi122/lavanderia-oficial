/* Ciudad 3D del panel del admin. Recibe por postMessage el estado real (Firestore)
   y lo dibuja: empleados según su actividad, pedidos como casas con pin, motos en ruta,
   casas en construcción mientras un cliente arma su pedido, y la animación de entrega
   cuando la ropa llega a la lavandería.

   Mensajes que entiende (JSON):
     {tipo:'datos', datos:{lavanderia:{nombre,lat,lng}, empleados:[{id,nombre,actividad}],
        pedidos:[{id,clienteId,cliente,estado,entrega,etapa,lat,lng,repLat,repLng,recibida,prendas,conRepartidor}],
        intenciones:[{id,nombre,lat,lng,estado,ts}]}}
     {tipo:'enfocar', objetivo:'lavanderia'|'ciudad'|{tipo,id}}  {tipo:'zoom', valor:+1|-1}  {tipo:'rotar'}
   Mensajes que envía: {tipo:'listo'} {tipo:'seleccion', obj:{tipo,id}|null} {tipo:'progreso', valor} */
import * as THREE from 'three';
import { crearMundo } from './mundo.js';
import { precargar } from './modelos.js';
import { crearCiudad, trazar, puntoEn } from './ciudad.js';
import { crearLavanderia } from './lavanderia.js';
import { Persona, Repartidor, modeloPara, MODELOS_GENTE } from './personajes.js';
import { crearTrafico } from './trafico.js';
import { Construccion } from './construccion.js';

const avisar = (o) => { window.__obs?.(o); const s = JSON.stringify(o); if (window.FlutterBridge) window.FlutterBridge.postMessage(s); else if (parent !== window) parent.postMessage(s, '*'); };
const ACT = {
  descanso: { icono: '☕', txt: 'Descansando' }, recepcion: { icono: '🛎️', txt: 'En recepción' },
  lavando: { icono: '🫧', txt: 'Lavando' }, secando: { icono: '🌀', txt: 'Secando' },
  planchando: { icono: '👔', txt: 'Planchando' }, vapor: { icono: '♨️', txt: 'Vapor / lavado en seco' },
  colgando: { icono: '🧺', txt: 'Colgando ropa' }, prensa: { icono: '🔥', txt: 'Usando la prensa' },
};
const ETAPA = { aceptado: 'Va a recoger', recogido: 'Trae la ropa', enLavanderia: 'En la lavandería', devolviendo: 'Llevando a casa', completada: 'Entregado' };
const ESTADO = { recibido: 'En cola', enProceso: 'Lavando', listo: 'Listo', entregado: 'Entregado' };
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export async function iniciar(contenedor, { demo = false } = {}) {
  const mundo = crearMundo(contenedor);
  const rutas = [
    ...['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u'].map((l) => `sub/building-type-${l}`),
    'sub/tree-large', 'sub/tree-small',
    ...['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'].map((l) => `com/building-${l}`),
    ...['a', 'b', 'c', 'd', 'e'].map((l) => `com/building-skyscraper-${l}`), 'com/detail-awning-wide',
    'road/traffic-light', 'road/light-square', 'road/construction-fence', 'road/construction-cone',
    'car/sedan', 'car/taxi', 'car/van', 'car/suv', 'car/hatchback-sports', 'car/sedan-sports', 'car/suv-luxury', 'car/delivery', 'car/police', 'car/truck', 'car/garbage-truck', 'car/ambulance',
    ...MODELOS_GENTE,
    'mueble/washer', 'mueble/washerDryerStacked', 'mueble/computerScreen', 'mueble/rugRectangle', 'mueble/loungeSofa', 'mueble/loungeChair', 'mueble/pottedPlant', 'mueble/lampSquareFloor', 'mueble/tableCloth', 'mueble/benchCushion', 'mueble/chairCushion',
  ];
  await precargar(rutas, (f) => avisar({ tipo: 'progreso', valor: f }));

  const ciudad = crearCiudad(mundo);
  const lav = crearLavanderia(mundo, 'Mi lavandería');
  crearTrafico(mundo, ciudad);
  mundo.elegibles.push(lav.grupo);
  lav.grupo.userData.seleccion = { tipo: 'lavanderia', id: 'lav' };

  /* ───────── conversión GPS → ciudad (dirección real, distancia comprimida) ───────── */
  let origen = null;
  function aMundo(lat, lng) {
    if (lat == null || lng == null || !origen) return null;
    const dz = -(lat - origen.lat) * 111320;
    const dx = (lng - origen.lng) * 111320 * Math.cos((origen.lat * Math.PI) / 180);
    const r = Math.hypot(dx, dz); if (r < 1) return { x: 30, z: 40 };
    const rw = 150 * Math.tanh(r / 2600) + 22;
    return { x: (dx / r) * rw, z: (dz / r) * rw };
  }

  /* ───────── lotes por cliente (casa del pedido y de la obra) ───────── */
  const lotePorCliente = new Map();
  function loteDe(clienteId, lat, lng) {
    if (lotePorCliente.has(clienteId)) return lotePorCliente.get(clienteId);
    const p = aMundo(lat, lng) || { x: 60 * Math.cos(lotePorCliente.size * 2.1), z: 60 * Math.sin(lotePorCliente.size * 2.1) };
    const l = ciudad.loteCercano(p.x, p.z);
    if (!l) return null;
    ciudad.ocupado.add(l.id); lotePorCliente.set(clienteId, l);
    return l;
  }

  /* ───────── pines de pedido sobre las casas ───────── */
  const pines = new Map();
  const geoPin = (() => {
    const s = new THREE.Shape(); s.absarc(0, 0.9, 0.62, Math.PI * 0.15 - Math.PI, Math.PI * 1.15 - Math.PI, true); s.lineTo(0, -0.4);
    return new THREE.ExtrudeGeometry(s, { depth: 0.28, bevelEnabled: true, bevelSize: 0.08, bevelThickness: 0.08, bevelSegments: 4, curveSegments: 24 });
  })();
  const matPin = new THREE.MeshStandardMaterial({ color: 0x2f6fe0, roughness: 0.3 });
  function pin(lote, id, html) {
    let p = pines.get(id);
    if (!p) {
      const g = new THREE.Group();
      const cuerpo = new THREE.Mesh(geoPin, matPin); cuerpo.position.z = -0.14; cuerpo.castShadow = true; g.add(cuerpo);
      const punto = new THREE.Mesh(new THREE.CircleGeometry(0.28, 24), new THREE.MeshBasicMaterial({ color: 0xffffff })); punto.position.set(0, 0.9, 0.23); g.add(punto);
      const sombra = new THREE.Mesh(new THREE.RingGeometry(0.5, 0.9, 32), new THREE.MeshBasicMaterial({ color: 0x2f6fe0, transparent: true, opacity: 0.35 }));
      sombra.rotation.x = -Math.PI / 2; sombra.position.y = -6.9; g.add(sombra);
      g.position.set(lote.x, 8.4, lote.z); g.scale.setScalar(1.5);
      g.userData.seleccion = { tipo: 'pedido', id };
      mundo.escena.add(g); mundo.elegibles.push(g);
      p = { g, etq: mundo.etiqueta(g, html, { alto: 2.4, clase: 'chip-pedido' }), lote };
      pines.set(id, p);
    } else p.etq.set(html);
    return p;
  }
  mundo.cadaCuadro((dt, t) => { for (const [, p] of pines) { p.g.position.y = 8.4 + Math.sin(t * 2 + p.lote.id) * 0.25; p.g.rotation.y = t * 0.8; } });

  /* ───────── empleados ───────── */
  const empleados = new Map();   // id → {p: Persona, act, ocupado, etq}
  const usoEst = new Map();
  function estacionPara(act, id) {
    const lista = lav.estaciones[act] || lav.estaciones.recepcion;
    const usados = usoEst.get(act) || new Map(); usoEst.set(act, usados);
    if (usados.has(id)) return lista[usados.get(id)];
    const libres = lista.map((_, i) => i).filter((i) => ![...usados.values()].includes(i));
    const i = libres.length ? libres[0] : usados.size % lista.length;
    usados.set(id, i); return lista[i];
  }
  function soltarEstacion(id) { for (const [, u] of usoEst) u.delete(id); }
  async function irA(e, act) {
    soltarEstacion(e.id);
    const est = estacionPara(act, e.id);
    const actual = e.p.raiz.position;
    const medio = new THREE.Vector3((actual.x + est.p.x) / 2, est.p.y, Math.max(actual.z, est.p.z, 1.5));
    if (e.p.actual?.getClip().name === 'sit') e.p.animar('idle');
    await e.p.caminar([medio, est.p], { vel: 1.6 });
    e.p.mirar(est.ang);
    e.p.animar(est.anim);
  }
  function sincEmpleados(lista) {
    const vistos = new Set();
    for (const em of lista) {
      vistos.add(em.id);
      const act = ACT[em.actividad] ? em.actividad : 'descanso';
      let e = empleados.get(em.id);
      if (!e) {
        const p = new Persona(mundo, modeloPara(em.id));
        const est = estacionPara(act, em.id);
        p.ponerEn(est.p, est.ang); p.animar(est.anim);
        p.raiz.userData.seleccion = { tipo: 'empleado', id: em.id };
        mundo.escena.add(p.raiz); mundo.elegibles.push(p.raiz);
        e = { id: em.id, p, act, ocupado: false, etq: mundo.etiqueta(p.raiz, '', { alto: 2.15, clase: 'chip-empleado' }) };
        empleados.set(em.id, e);
      } else if (e.act !== act) {
        e.act = act;
        if (!e.ocupado) irA(e, act);
      }
      e.nombre = em.nombre;
      e.etq.set(`<b>${ACT[act].icono}</b> ${esc(em.nombre.split(' ')[0])} · ${ACT[act].txt}`);
    }
    for (const [id, e] of empleados) if (!vistos.has(id)) { e.p.destruir(); e.etq.quitar(); empleados.delete(id); soltarEstacion(id); }
    lav.vapor([...empleados.values()].some((e) => e.act === 'vapor'));
    lav.prensar([...empleados.values()].some((e) => e.act === 'prensa'));
  }

  /* ───────── motos de reparto ───────── */
  const motos = new Map(); // pedidoId → {r: Repartidor, R, s, modo}
  const RUTA_PARQUEO = () => ({ x: lav.estacionamiento.x, z: 18, eje: 'x' });
  function rutaEntre(a, b) { return trazar(ciudad.recorrido(a, b), 3.4); }
  function motoDe(pid) {
    let mo = motos.get(pid);
    if (!mo) {
      const r = new Repartidor(mundo, pid);
      r.raiz.userData.seleccion = { tipo: 'pedido', id: pid };
      mundo.escena.add(r.raiz); mundo.elegibles.push(r.raiz);
      mo = { r, R: null, s: 0, modo: '', etq: mundo.etiqueta(r.raiz, '', { alto: 2.6, clase: 'chip-moto' }), quieta: false };
      motos.set(pid, mo);
    }
    return mo;
  }
  function quitarMoto(pid) { const mo = motos.get(pid); if (!mo) return; mo.r.destruir(); mo.etq.quitar(); motos.delete(pid); }
  mundo.cadaCuadro((dt) => {
    for (const [, mo] of motos) {
      if (!mo.R || mo.quieta) { mo.r.raiz.userData.vel = 0; continue; }
      const objetivo = mo.objetivoS ?? mo.R.largo;
      const v = 9;
      if (mo.s < objetivo) mo.s = Math.min(objetivo, mo.s + v * dt);
      else if (mo.bucle) mo.s = 0;
      const p = puntoEn(mo.R, mo.s);
      mo.r.raiz.position.set(p.x, 0.02, p.z); mo.r.raiz.rotation.y = p.ang;
      mo.r.raiz.userData.vel = mo.s < objetivo ? v : 0;
      if (mo.s >= mo.R.largo && mo.alLlegar) { const f = mo.alLlegar; mo.alLlegar = null; f(); }
    }
  });

  /* ───────── animación de entrega: la ropa llega a la lavandería ───────── */
  const cola = [];
  let corriendo = false;
  function encolar(f) { cola.push(f); if (!corriendo) siguiente(); }
  async function siguiente() {
    corriendo = true;
    while (cola.length) { try { await cola.shift()(); } catch (e) { console.warn(e); } }
    corriendo = false;
  }
  function empleadoParaRecibir(uid) {
    // quien hizo clic en "Recibí la ropa" es quien la recibe en la escena
    const quien = uid && empleados.get(uid);
    if (quien && !quien.ocupado) return quien;
    const lista = [...empleados.values()].filter((e) => !e.ocupado);
    return lista.find((e) => e.act === 'recepcion') || lista.find((e) => e.act === 'descanso') || lista[0] || null;
  }
  const espera = (ms) => new Promise((r) => setTimeout(r, ms));
  async function recibirRopa(entregador, pedidoId, recibidaPor) {
    const empl = empleadoParaRecibir(recibidaPor);
    // quien entrega camina al mostrador con la bolsa
    entregador.cargar(true);
    await entregador.caminar([lav.puerta, lav.mostradorCliente], { vel: 1.5 });
    entregador.mirar(Math.PI);
    if (empl) {
      empl.ocupado = true; soltarEstacion(empl.id);
      if (empl.p.actual?.getClip().name === 'sit') { empl.p.animar('idle'); await espera(300); }
      await empl.p.caminar([lav.mostradorEmpleado], { vel: 1.8 });
      empl.p.mirar(0);
      entregador.animar('pick-up', { una: true }); await espera(700);
      entregador.cargar(false); empl.p.cargar(true); empl.p.animar('holding-both');
      await espera(500);
      entregador.animar('emote-yes', { una: true });
      // el empleado lleva la bolsa a la sección de colgados (la cola)
      const riel = lav.estaciones.colgando[0];
      await empl.p.caminar([new THREE.Vector3(riel.p.x - 1.4, riel.p.y, 1.8), riel.p], { vel: 1.4 });
      empl.p.mirar(riel.ang); empl.p.animar('interact-right');
      await espera(1100);
      empl.p.cargar(false);
      colaExtra++; actualizarLav();
      empl.ocupado = false;
      irA(empl, empl.act);
    } else {
      entregador.animar('pick-up', { una: true }); await espera(800);
      entregador.cargar(false); colaExtra++; actualizarLav();
    }
    await espera(400);
  }
  let colaExtra = 0;   // bolsas recién colgadas que aún no se reflejan en los datos

  function animEntregaRepartidor(pid) {
    encolar(async () => {
      const mo = motoDe(pid);
      // sigue la ruta que ya traía (casa → lavandería); si no había, entra desde la calle
      if (!mo.R) { mo.R = rutaEntre({ x: ciudad.lineas[0], z: 18, eje: 'x' }, RUTA_PARQUEO()); mo.s = mo.R.largo * 0.5; }
      mo.modo = 'llegando'; mo.bucle = false; mo.objetivoS = null; mo.quieta = false;
      await new Promise((ok) => { mo.alLlegar = ok; if (mo.s >= mo.R.largo) ok(); });
      mo.quieta = true;
      mo.r.raiz.position.set(lav.estacionamiento.x, 0.02, lav.estacionamiento.z + 1); mo.r.raiz.rotation.y = Math.PI;
      const rider = mo.r.bajar();
      rider.ponerEn(new THREE.Vector3(lav.estacionamiento.x + 0.8, 0.18, lav.estacionamiento.z + 0.6));
      mundo.escena.add(rider.raiz);
      await recibirRopa(rider, pid);
      await rider.caminar([lav.puerta, new THREE.Vector3(lav.estacionamiento.x + 0.8, 0.18, lav.estacionamiento.z + 0.6)], { vel: 1.6 });
      mundo.escena.remove(rider.raiz); mo.r.subir();
      mo.etq.set(`🛵 ${ETAPA.enLavanderia}`);
    });
  }
  function animEntregaCliente(pid, nombre, recibidaPor) {
    encolar(async () => {
      const c = new Persona(mundo, modeloPara('cli' + pid));
      const inicio = new THREE.Vector3(-9, 0.18, 14.6);
      c.ponerEn(inicio); mundo.escena.add(c.raiz);
      const etq = mundo.etiqueta(c.raiz, `🧺 ${esc(nombre || 'Cliente')} trae su ropa`, { alto: 2.15, clase: 'chip-cliente' });
      await c.caminar([new THREE.Vector3(-2, 0.18, 14.6)], { vel: 1.7 });
      await recibirRopa(c, pid, recibidaPor);
      etq.set('👋 ¡Gracias!');
      await c.caminar([lav.puerta, new THREE.Vector3(16, 0.18, 14.6)], { vel: 1.7 });
      etq.quitar(); c.destruir();
    });
  }

  /* ───────── clientes que traen su ropa caminando ───────── */
  // Desde su casa hasta la puerta de la lavandería; ahí esperan hasta que
  // alguien marque "Recibí la ropa" (no depende del GPS ni del internet del
  // cliente: la llegada la confirma el recepcionista).
  const caminantes = new Map(); // pedidoId → { c, etq, estado, nombre }
  function caminanteDe(p, lote, desdeCasa) {
    let w = caminantes.get(p.id);
    if (w) return w;
    const R = trazar(ciudad.recorrido(lote.frente, RUTA_PARQUEO()), 2, 5.2);
    const pts = R.pts.map(([x, z]) => new THREE.Vector3(x, 0.18, z));
    if (pts.length < 2) return null;
    const k = desdeCasa ? 0 : Math.min(pts.length - 2, Math.floor(pts.length * 0.6));
    const c = new Persona(mundo, modeloPara('cli' + p.id));
    c.ponerEn(pts[k]); c.cargar(true);
    c.raiz.userData.seleccion = { tipo: 'pedido', id: p.id };
    mundo.escena.add(c.raiz); mundo.elegibles.push(c.raiz);
    const nombre = esc((p.cliente || 'Cliente').split(' ')[0]);
    const etq = mundo.etiqueta(c.raiz, `🚶 <b>${nombre}</b> viene a dejar su ropa`, { alto: 2.15, clase: 'chip-cliente' });
    w = { c, etq, estado: 'viniendo', nombre };
    caminantes.set(p.id, w);
    c.caminar(pts.slice(k + 1), { vel: Math.min(5, Math.max(1.7, R.largo / 70)) }).then(() => {
      if (w.estado !== 'viniendo') return;
      w.estado = 'esperando';
      etq.set(`🧺 <b>${nombre}</b> llegó con su ropa`);
      c.mirar(Math.PI);
    });
    return w;
  }
  function entrarCaminante(pid, recibidaPor) {
    const w = caminantes.get(pid);
    if (!w || w.estado === 'entrando') return;
    w.estado = 'entrando';
    encolar(async () => {
      const c = w.c;
      // si lo recibieron antes de que "llegara", aparece en la puerta
      if (c.camino) { c.raiz.position.copy(c.camino.pts[c.camino.pts.length - 1]); c.camino.i = c.camino.pts.length - 1; await espera(80); }
      w.etq.set(`🧺 <b>${w.nombre}</b> entrega su ropa`);
      await recibirRopa(c, pid, recibidaPor);
      w.etq.set('👋 ¡Gracias!');
      await c.caminar([lav.puerta, new THREE.Vector3(16, 0.18, 14.6)], { vel: 1.7 });
      w.etq.quitar(); c.destruir(); caminantes.delete(pid);
    });
  }
  function quitarCaminante(pid) {
    const w = caminantes.get(pid);
    if (!w || w.estado === 'entrando') return;
    w.etq.quitar(); w.c.destruir(); caminantes.delete(pid);
  }

  /* ───────── obras (intenciones de pedido) ───────── */
  const obras = new Map();
  const nombreCorto = (n) => esc((n || 'Cliente').split(' ')[0]);
  // Casa terminada con el nombre del cliente (pedidos con recojo a domicilio).
  function casaTerminada(o, nombre, pid) {
    o.confirmar(`🏠 Casa de <b>${nombreCorto(nombre)}</b>`);
    o.casaDe = pid;
    o.g.userData.seleccion = { tipo: 'pedido', id: pid };
  }
  function sincIntenciones(lista, pedidos) {
    const ahora = Date.now();
    for (const it of lista) {
      const viejo = it.ts && ahora - it.ts > 20 * 60 * 1000;
      let o = obras.get(it.id);
      if (it.estado === 'armando' && !viejo) {
        if (!o) {
          const lote = loteDe(it.id, it.lat, it.lng);
          if (!lote) continue;
          o = new Construccion(mundo, lote, `🏗️ ${esc((it.nombre || 'Cliente').split(' ')[0])} está armando un pedido…`);
          o.g.userData.seleccion = { tipo: 'intencion', id: it.id };
          mundo.elegibles.push(o.g);
          obras.set(it.id, o);
        }
      } else if (o && o.estado === 'armando') {
        if (it.estado === 'confirmada') {
          const ped = pedidos.find((p) => p.id === it.pedidoId) || pedidos.find((p) => p.clienteId === it.id);
          // el pedido puede llegar un instante después que la confirmación
          if (!ped && !viejo && (!it.ts || ahora - it.ts < 30000)) continue;
          if (ped && ped.entrega === 'recojoDomicilio') {
            casaTerminada(o, it.nombre, ped.id);
          } else {
            // "yo llevo mi ropa": no hay casa, sale caminando hacia la lavandería
            o.cancelar(); o.etiqueta.set(`🚶 <b>${nombreCorto(it.nombre)}</b> llevará su ropa`);
            setTimeout(() => obras.delete(it.id), 3200);
            if (ped) caminanteDe(ped, o.lote, true);
          }
        } else { o.cancelar(); setTimeout(() => obras.delete(it.id), 3200); }
      }
    }
  }

  /* ───────── sincronizar todo con los datos ───────── */
  let previo = null, ultimos = null;
  function actualizarLav() {
    const d = ultimos; if (!d) return;
    const enCola = d.pedidos.filter((p) => p.estado === 'recibido' && p.recibida).length;
    lav.set({
      colgadosN: Math.max(enCola, colaExtra),
      lavando: Math.min(5, d.pedidos.filter((p) => p.estado === 'enProceso').length * 2),
      listasN: d.pedidos.filter((p) => p.estado === 'listo').length,
    });
  }
  function set(d) {
    d = { empleados: [], pedidos: [], intenciones: [], ...d };
    if (d.lavanderia) {
      if (!origen && d.lavanderia.lat != null) origen = { lat: d.lavanderia.lat, lng: d.lavanderia.lng };
      if (d.lavanderia.nombre && d.lavanderia.nombre !== lav.nombre) { lav.renombrar(d.lavanderia.nombre); lav.nombre = d.lavanderia.nombre; }
    }
    ultimos = d;
    sincEmpleados(d.empleados);
    sincIntenciones(d.intenciones, d.pedidos);

    const vivos = new Set();
    for (const p of d.pedidos) {
      const ant = previo?.pedidos.find((q) => q.id === p.id);
      const activo = p.estado !== 'entregado' && p.etapa !== 'completada';
      const conRecojo = p.entrega === 'recojoDomicilio';
      const lote = (p.lat != null || conRecojo) ? loteDe(p.clienteId || p.id, p.lat, p.lng) : null;
      // la casa del cliente con su nombre solo existe si pidió repartidor
      if (activo && lote && conRecojo) {
        const key = p.clienteId || p.id;
        let o = obras.get(key);
        if (!o) {
          o = new Construccion(mundo, lote, '');
          mundo.elegibles.push(o.g);
          casaTerminada(o, p.cliente, p.id); o.t = 3; // ya construida (p. ej. al abrir el panel)
          obras.set(key, o);
        }
        if (o.casaDe) { o.casaDe = p.id; vivos.add('casa:' + key); }
      }
      // "yo llevo mi ropa": una persona camina hacia la lavandería hasta que la reciben
      if (activo && !conRecojo && p.estado === 'recibido' && !p.recibida && lote) {
        const armando = obras.get(p.clienteId)?.estado === 'armando';
        if (!armando) caminanteDe(p, lote, false);
        vivos.add('cam:' + p.id);
      }
      if (activo && lote && conRecojo) {
        vivos.add(p.id);
        const tag = p.entrega === 'recojoDomicilio' ? (p.conRepartidor ? `🛵 ${ETAPA[p.etapa] || ''}` : '⏳ Buscando repartidor') : '🚶 Lo trae el cliente';
        pin(lote, p.id, `<b>#${esc(p.id.slice(0, 5).toUpperCase())}</b> ${esc((p.cliente || '').split(' ')[0])}<br><span>${ESTADO[p.estado] || ''} · ${tag}</span>`);
      }
      // motos según la etapa del reparto
      if (activo && p.entrega === 'recojoDomicilio' && p.conRepartidor && lote) {
        const mo = motoDe(p.id);
        const frenteLav = RUTA_PARQUEO();
        const casa = lote.frente;
        const modo = p.etapa;
        if (mo.modo !== modo && !(modo === 'enLavanderia' && mo.modo === 'llegando')) {
          mo.modo = modo; mo.quieta = false; mo.bucle = false; mo.objetivoS = null;
          if (modo === 'aceptado') { mo.R = rutaEntre({ x: ciudad.lineas[0], z: casa.z, eje: 'x' }, casa); mo.s = 0; }
          else if (modo === 'recogido') { mo.R = rutaEntre(casa, frenteLav); mo.s = 0; }
          else if (modo === 'devolviendo') { mo.R = rutaEntre(frenteLav, casa); mo.s = 0; }
          else if (modo === 'enLavanderia') {
            if (ant && ant.etapa === 'recogido') { mo.modo = 'recogido'; animEntregaRepartidor(p.id); }
            else { mo.R = rutaEntre(casa, frenteLav); mo.s = mo.R.largo; mo.quieta = true; mo.r.raiz.position.set(lav.estacionamiento.x, 0.02, lav.estacionamiento.z + 1); mo.r.raiz.rotation.y = Math.PI; }
          }
        }
        // con GPS real del repartidor, avanzar hasta la fracción real del trayecto
        if (p.repLat != null && mo.R && ['aceptado', 'recogido', 'devolviendo'].includes(modo)) {
          const yo = aMundo(p.repLat, p.repLng);
          if (yo) {
            let mejor = 0, dm = Infinity;
            for (let i = 0; i < mo.R.pts.length; i++) { const q = mo.R.pts[i]; const dd = (q[0] - yo.x) ** 2 + (q[1] - yo.z) ** 2; if (dd < dm) { dm = dd; mejor = mo.R.acum[i]; } }
            mo.objetivoS = Math.max(mo.s, mejor);
          }
        } else if (['aceptado', 'recogido', 'devolviendo'].includes(modo) && !mo.objetivoS) { mo.bucle = false; }
        mo.etq.set(`🛵 <b>${ETAPA[modo] || ''}</b> · #${esc(p.id.slice(0, 5).toUpperCase())}`);
        vivos.add('moto:' + p.id);
      }
      // la ropa la trae el cliente: animación cuando el empleado marca "ropa recibida"
      if (p.entrega !== 'recojoDomicilio' && p.recibida && caminantes.has(p.id)) { entrarCaminante(p.id, p.recibidaPor); vivos.add('cam:' + p.id); }
      else if (previo && ant && p.entrega !== 'recojoDomicilio' && !ant.recibida && p.recibida) animEntregaCliente(p.id, p.cliente, p.recibidaPor);
    }
    for (const [id, p] of pines) if (!vivos.has(id)) { mundo.escena.remove(p.g); p.etq.quitar(); pines.delete(id); }
    for (const [key, o] of obras) if (o.casaDe && o.estado !== 'fin' && !vivos.has('casa:' + key)) { o.destruir(); obras.delete(key); }
    for (const [pid] of caminantes) if (!vivos.has('cam:' + pid)) quitarCaminante(pid);
    for (const [pid] of motos) if (!vivos.has('moto:' + pid) && !corriendo) quitarMoto(pid);
    if (previo) colaExtra = 0;
    previo = d;
    actualizarLav();
  }

  /* ───────── cámara y selección ───────── */
  const centroLav = () => lav.grupo.getWorldPosition(new THREE.Vector3());
  function enfocar(obj) {
    if (obj === 'ciudad') return mundo.volarA(new THREE.Vector3(0, 0, 4), { dist: 230, polar: 0.9 });
    if (obj === 'lavanderia' || !obj) return mundo.volarA(centroLav(), { dist: 40, polar: 0.72 });
    let o = null;
    if (obj.tipo === 'empleado') o = empleados.get(obj.id)?.p.raiz;
    else if (obj.tipo === 'pedido') o = motos.get(obj.id)?.r.raiz || caminantes.get(obj.id)?.c.raiz || pines.get(obj.id)?.g || [...obras.values()].find((x) => x.casaDe === obj.id)?.g;
    else if (obj.tipo === 'intencion') o = obras.get(obj.id)?.g;
    if (o) mundo.volarA(o.getWorldPosition(new THREE.Vector3()).setY(0), { dist: obj.tipo === 'empleado' ? 24 : 55, polar: 0.85 });
  }
  const anillo = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.15, 40), new THREE.MeshBasicMaterial({ color: 0x2f6fe0, transparent: true, opacity: 0.85, depthWrite: false }));
  anillo.rotation.x = -Math.PI / 2; anillo.visible = false; mundo.escena.add(anillo);
  let elegido = null;
  mundo.cadaCuadro((dt, t) => {
    if (!elegido?.parent) { anillo.visible = false; return; }
    anillo.visible = true; elegido.getWorldPosition(anillo.position); anillo.position.y = 0.25;
    const s = elegido === lav.grupo ? 14 : elegido.userData.seleccion?.tipo === 'empleado' ? 0.8 : 3;
    anillo.scale.setScalar(s * (1 + Math.sin(t * 4) * 0.06));
  });
  mundo.alElegir((o) => {
    elegido = o;
    avisar({ tipo: 'seleccion', obj: o?.userData.seleccion || null });
  });

  addEventListener('message', (e) => {
    let m = e.data; if (typeof m === 'string') { try { m = JSON.parse(m); } catch { return; } }
    if (!m?.tipo) return;
    if (m.tipo === 'datos') set(m.datos || {});
    else if (m.tipo === 'enfocar') enfocar(m.objetivo);
    else if (m.tipo === 'zoom') { const c = mundo.controles; const off = mundo.camara.position.clone().sub(c.target).multiplyScalar(m.valor > 0 ? 0.75 : 1.33); mundo.volarA(c.target.clone(), { dist: THREE.MathUtils.clamp(off.length(), 14, 330), polar: new THREE.Spherical().setFromVector3(off).phi, dur: 0.5 }); }
    else if (m.tipo === 'rotar') { const c = mundo.controles; const sph = new THREE.Spherical().setFromVector3(mundo.camara.position.clone().sub(c.target)); mundo.volarA(c.target.clone(), { dist: sph.radius, polar: sph.phi, azimut: sph.theta + Math.PI / 2, dur: 0.9 }); }
  });

  // vista inicial: vuelo desde la ciudad hacia la lavandería
  mundo.camara.position.set(160, 190, 260);
  mundo.volarA(centroLav(), { dist: 44, polar: 0.74, azimut: 0.5, dur: 2.6 });

  if (demo) correrDemo(set);
  window.__esc = { set, enfocar, mundo, ciudad, lav: () => lav, empleados, motos, obras, pines, caminantes };
  window.__listo = true;
  avisar({ tipo: 'listo' });
}

/* ───────── demo sin Firebase (landing y pruebas): una historia completa en bucle ───────── */
function correrDemo(set) {
  const base = { lavanderia: { nombre: 'Lavandería Real Star', lat: -16.5, lng: -68.13 } };
  const empleados = [
    { id: 'e1', nombre: 'Ana Quispe', actividad: 'recepcion' },
    { id: 'e2', nombre: 'Luis Mamani', actividad: 'prensa' },
    { id: 'e3', nombre: 'Rosa Choque', actividad: 'descanso' },
  ];
  let pedidos = [
    { id: 'p1aaa', clienteId: 'c1', cliente: 'Carla Rojas', estado: 'recibido', entrega: 'recojoDomicilio', etapa: 'aceptado', conRepartidor: true, lat: -16.51, lng: -68.12, recibida: false },
    { id: 'p2bbb', clienteId: 'c2', cliente: 'Jorge Lima', estado: 'enProceso', entrega: 'clienteLleva', lat: -16.49, lng: -68.14, recibida: true },
    { id: 'p3ccc', clienteId: 'c3', cliente: 'Eva Paz', estado: 'listo', entrega: 'recojoDomicilio', etapa: 'devolviendo', conRepartidor: true, lat: -16.48, lng: -68.11, recibida: true },
    { id: 'p4ddd', clienteId: 'c4', cliente: 'Hugo Vera', estado: 'recibido', entrega: 'clienteLleva', lat: -16.505, lng: -68.145, recibida: false },
  ];
  let intenciones = [];
  const enviar = () => set({ ...base, empleados: JSON.parse(JSON.stringify(empleados)), pedidos: JSON.parse(JSON.stringify(pedidos)), intenciones: JSON.parse(JSON.stringify(intenciones)) });
  enviar();
  const pasos = [
    [4000, () => { empleados[2].actividad = 'lavando'; }],
    // Mario arma un pedido con recojo → se construye su casa con su nombre
    [3000, () => { intenciones = [{ id: 'c9', nombre: 'Mario Paredes', lat: -16.495, lng: -68.12, estado: 'armando', ts: Date.now() }]; }],
    [6000, () => { pedidos[0].etapa = 'recogido'; }],
    [7000, () => {
      pedidos.push({ id: 'p5eee', clienteId: 'c9', cliente: 'Mario Paredes', estado: 'recibido', entrega: 'recojoDomicilio', etapa: 'aceptado', conRepartidor: false, lat: -16.495, lng: -68.12, recibida: false });
      intenciones[0].estado = 'confirmada'; intenciones[0].pedidoId = 'p5eee'; intenciones[0].ts = Date.now();
    }],
    [5000, () => { pedidos[0].etapa = 'enLavanderia'; pedidos[0].recibida = true; }],
    // Hugo ya venía caminando: Ana lo recibe en el mostrador
    [9000, () => { pedidos[3].recibida = true; pedidos[3].recibidaPor = 'e1'; }],
    // Lucía elige "yo llevo mi ropa": no hay casa, sale caminando
    [8000, () => { intenciones = [{ id: 'c7', nombre: 'Lucía Mendoza', lat: -16.512, lng: -68.135, estado: 'armando', ts: Date.now() }]; }],
    [7000, () => {
      pedidos.push({ id: 'p6fff', clienteId: 'c7', cliente: 'Lucía Mendoza', estado: 'recibido', entrega: 'clienteLleva', lat: -16.512, lng: -68.135, recibida: false });
      intenciones[0].estado = 'confirmada'; intenciones[0].pedidoId = 'p6fff'; intenciones[0].ts = Date.now();
    }],
    // Sara arma uno y lo cancela
    [9000, () => { intenciones = [{ id: 'c8', nombre: 'Sara Flores', lat: -16.515, lng: -68.15, estado: 'armando', ts: Date.now() }]; }],
    [7000, () => { intenciones[0].estado = 'cancelada'; }],
    // Luis deja el vapor, recibe la ropa de Lucía, la cuelga y vuelve al vapor
    [12000, () => { empleados[1].actividad = 'vapor'; }],
    [6000, () => { const p = pedidos.find((q) => q.id === 'p6fff'); p.recibida = true; p.recibidaPor = 'e2'; }],
  ];
  (async () => { for (const [ms, f] of pasos) { await new Promise((r) => setTimeout(r, ms)); f(); enviar(); } })();
}
