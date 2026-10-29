/* Fusión de mallas estáticas: mismas formas y colores, muchas menos llamadas de dibujo.
   Agrupa por material "equivalente" (mismo pack/textura o mismos parámetros) y por si proyecta sombra. */
import * as THREE from 'three';
import { mergeGeometries } from '../vendor/jsm/utils/BufferGeometryUtils.js';

const aFloat = (a, n) => {
  const out = new Float32Array(a.count * n);
  for (let i = 0; i < a.count; i++) {
    out[i * n] = a.getX(i);
    if (n > 1) out[i * n + 1] = a.getY(i);
    if (n > 2) out[i * n + 2] = a.getZ(i);
  }
  return new THREE.BufferAttribute(out, n);
};

function preparar(m, base) {
  const g0 = m.geometry, g = new THREE.BufferGeometry();
  g.setAttribute('position', aFloat(g0.attributes.position, 3));
  if (g0.attributes.normal) g.setAttribute('normal', aFloat(g0.attributes.normal, 3));
  g.setAttribute('uv', g0.attributes.uv ? aFloat(g0.attributes.uv, 2) : new THREE.BufferAttribute(new Float32Array(g0.attributes.position.count * 2), 2));
  g.setIndex(g0.index ? Array.from(g0.index.array) : [...Array(g0.attributes.position.count).keys()]);
  if (!g.attributes.normal) g.computeVertexNormals();
  g.applyMatrix4(base ? new THREE.Matrix4().copy(base).invert().multiply(m.matrixWorld) : m.matrixWorld);
  return g;
}

function claveMaterial(mt, pack) {
  if (pack) return pack + '|' + mt.name + '|' + (mt.color?.getHexString() || '');
  return [mt.type, mt.color?.getHexString(), mt.roughness, mt.metalness, mt.transparent, mt.opacity, mt.map?.uuid || '', mt.emissive?.getHexString() || '', mt.side].join('|');
}

/** Fusiona `objetos` (con sus hijos) y devuelve las mallas nuevas, en coordenadas de `padre`. */
export function fusionar(objetos, padre) {
  const grupos = new Map();
  padre.updateMatrixWorld(true);
  const base = padre.matrixWorld;
  for (const o of objetos) {
    o.updateMatrixWorld(true);
    const pack = o.userData.pack;
    o.traverse((m) => {
      if (!m.isMesh || m.isSkinnedMesh || m.isInstancedMesh || Array.isArray(m.material)) return;
      const k = claveMaterial(m.material, pack) + '|' + (m.castShadow ? 1 : 0);
      if (!grupos.has(k)) grupos.set(k, { mat: m.material, sombra: m.castShadow, geos: [] });
      grupos.get(k).geos.push(preparar(m, o.parent === padre ? base : null));
    });
  }
  const mallas = [];
  for (const { mat, sombra, geos } of grupos.values()) {
    const g = mergeGeometries(geos, false);
    geos.forEach((x) => x.dispose());
    if (!g) continue;
    const malla = new THREE.Mesh(g, mat);
    malla.castShadow = sombra; malla.receiveShadow = true; malla.matrixAutoUpdate = false;
    mallas.push(malla);
  }
  return mallas;
}
