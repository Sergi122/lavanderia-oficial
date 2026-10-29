/* Carga y clona los modelos GLB (Kenney, CC0). Cada modelo se carga una sola vez;
   las copias comparten geometría y materiales. Los personajes se clonan con
   SkeletonUtils para que cada uno tenga su propio esqueleto y animaciones. */
import * as THREE from 'three';
import { GLTFLoader } from '../vendor/jsm/loaders/GLTFLoader.js';
import { clone as clonarEsqueleto } from '../vendor/jsm/utils/SkeletonUtils.js';

const loader = new GLTFLoader();
const cache = new Map();
const BASE = new URL('../modelos/', import.meta.url).href;

/** Escala de cada pack para que 1 unidad = 1 metro. */
export const ESCALA = { sub: 7, com: 7, road: 7, car: 1.75, mueble: 1.8, gente: 1 };

/** Tono pastel tipo WareTrack: aclara y desatura un poco los colores de los packs. */
function pastelizar(mat, fuerza = 0.22) {
  if (mat.userData.pastel) return;
  mat.userData.pastel = true;
  mat.onBeforeCompile = (sh) => {
    sh.fragmentShader = sh.fragmentShader.replace(
      '#include <map_fragment>',
      `#include <map_fragment>
       float _l = dot(diffuseColor.rgb, vec3(0.299, 0.587, 0.114));
       diffuseColor.rgb = mix(diffuseColor.rgb, vec3(_l), ${(fuerza * 0.9).toFixed(3)});
       diffuseColor.rgb = mix(diffuseColor.rgb, vec3(1.0), ${(fuerza * 0.55).toFixed(3)});`,
    );
  };
  mat.customProgramCacheKey = () => 'pastel' + fuerza;
}

export function cargar(ruta) {
  if (!cache.has(ruta)) {
    const p = loader.loadAsync(BASE + ruta + '.glb').then((g) => {
      g.scene.traverse((o) => {
        if (o.isMesh) {
          o.castShadow = true; o.receiveShadow = true;
          const mats = Array.isArray(o.material) ? o.material : [o.material];
          for (const m of mats) {
            if (m.map) { m.map.anisotropy = 4; m.map.colorSpace = THREE.SRGBColorSpace; }
            if (!ruta.startsWith('gente/')) pastelizar(m, ruta.startsWith('mueble/') ? 0.04 : 0.1);
          }
        }
      });
      p.__valor = g; // para clonar sin await
      return g;
    });
    cache.set(ruta, p);
  }
  return cache.get(ruta);
}

/** Precarga varias rutas en paralelo; ignora las que fallen (se dibuja sin ellas). */
export async function precargar(rutas, alAvanzar) {
  let n = 0;
  await Promise.all(rutas.map((r) => cargar(r).catch((e) => console.warn('modelo', r, e)).finally(() => alAvanzar?.(++n / rutas.length))));
}

/** Copia estática de un modelo ya cargado, escalada a metros. */
export function copia(ruta, escala) {
  const p = cache.get(ruta);
  if (!p) throw new Error('modelo no precargado: ' + ruta);
  const g = p.__valor;
  const s = escala ?? ESCALA[ruta.split('/')[0]] ?? 1;
  const o = g.scene.clone(true);
  o.scale.setScalar(s);
  o.userData.pack = ruta.split('/')[0];
  return o;
}

/** Personaje animado (esqueleto propio) normalizado a `alto` metros. */
export function personaje(ruta, alto = 1.7) {
  const g = cache.get(ruta).__valor;
  const o = clonarEsqueleto(g.scene);
  const caja = new THREE.Box3().setFromObject(o);
  const h = caja.max.y - caja.min.y || 1;
  o.scale.setScalar(alto / h);
  return { obj: o, clips: g.animations };
}

export const disponible = (ruta) => !!cache.get(ruta)?.__valor;
