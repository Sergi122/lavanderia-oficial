/* Vida de la ciudad: autos que recorren calles al azar y peatones en las veredas. */
import * as THREE from 'three';
import { copia, disponible } from './modelos.js';
import { trazar, puntoEn, PASO, MANZANA, RADIO } from './ciudad.js';
import { Persona, MODELOS_GENTE } from './personajes.js';

const AUTOS = ['car/sedan', 'car/taxi', 'car/van', 'car/suv', 'car/hatchback-sports', 'car/sedan-sports', 'car/suv-luxury', 'car/delivery', 'car/police', 'car/truck', 'car/garbage-truck', 'car/ambulance'];

export function crearTrafico(mundo, ciudad, { autos = 16, peatones = 10 } = {}) {
  const { lineas } = ciudad;
  const azar = (a) => a[Math.floor(Math.random() * a.length)];
  const cruces = []; for (const x of lineas) for (const z of lineas) cruces.push([x, z]);

  function rutaAzar(desde) {
    // 2–4 tramos rectos entre cruces vecinos (sin dar media vuelta)
    const pts = [desde];
    let [x, z] = desde, dirPrev = null;
    for (let k = 0; k < 3 + Math.floor(Math.random() * 3); k++) {
      const op = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([dx, dz]) => {
        if (dirPrev && dx === -dirPrev[0] && dz === -dirPrev[1]) return false;
        const nx = x + dx * PASO, nz = z + dz * PASO;
        return Math.abs(nx) <= lineas[lineas.length - 1] + 0.1 && Math.abs(nz) <= lineas[lineas.length - 1] + 0.1;
      });
      const [dx, dz] = azar(op); x += dx * PASO; z += dz * PASO; dirPrev = [dx, dz];
      pts.push([x, z]);
    }
    return pts;
  }

  const lista = [];
  const modelos = AUTOS.filter(disponible);
  for (let i = 0; i < autos && modelos.length; i++) {
    const o = copia(azar(modelos));
    mundo.escena.add(o);
    const a = { o, R: null, s: 0, vel: 7 + Math.random() * 5, fin: azar(cruces) };
    a.R = trazar(rutaAzar(a.fin), 4.2);
    a.s = Math.random() * a.R.largo;
    lista.push(a);
  }

  const peat = [];
  const gente = MODELOS_GENTE.filter(disponible);
  const veredaPts = () => {
    // un rectángulo alrededor de una manzana al azar (sobre la vereda)
    const i = Math.floor(Math.random() * (RADIO * 2 + 1)) - RADIO, j = Math.floor(Math.random() * (RADIO * 2 + 1)) - RADIO;
    const h = MANZANA / 2 - 1, cx = i * PASO, cz = j * PASO;
    return [[cx - h, cz + h], [cx + h, cz + h], [cx + h, cz - h], [cx - h, cz - h]].map(([x, z]) => new THREE.Vector3(x, 0.18, z));
  };
  for (let i = 0; i < peatones && gente.length; i++) {
    const p = new Persona(mundo, azar(gente));
    const pts = veredaPts();
    const k = Math.floor(Math.random() * 4);
    p.ponerEn(pts[k]);
    mundo.escena.add(p.raiz);
    const vuelta = async () => {
      for (;;) {
        const ord = [...pts.slice(k + 1), ...pts.slice(0, k + 1)];
        await p.caminar(ord, { vel: 1.1 + Math.random() * 0.5 });
      }
    };
    vuelta();
    peat.push(p);
  }

  mundo.cadaCuadro((dt) => {
    for (const a of lista) {
      a.s += a.vel * dt;
      if (a.s >= a.R.largo) {
        const ult = a.R.pts[a.R.pts.length - 1];
        // reanuda desde el cruce más cercano al final
        const c = cruces.reduce((b, q) => (Math.hypot(q[0] - ult[0], q[1] - ult[1]) < Math.hypot(b[0] - ult[0], b[1] - ult[1]) ? q : b));
        a.R = trazar(rutaAzar(c), 4.2); a.s = 0;
      }
      const p = puntoEn(a.R, a.s);
      a.o.position.set(p.x, 0.02, p.z);
      a.o.rotation.y = p.ang;
    }
  });
  return { autos: lista, peatones: peat };
}
