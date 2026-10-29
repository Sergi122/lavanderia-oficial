import { crearEscena, webglDisponible } from './escena3d.js';
const caja = document.querySelector('.escena');
const cv = document.getElementById('escena');
if (caja && cv && webglDisponible()) {
  const host = document.createElement('div');
  host.id = 'escena3d';
  cv.replaceWith(host);
  const esc = crearEscena(host, { ligero: false });
  window.__escena3d = esc;
  const N = 'Lavandería Central';
  const CAP = [
    ['Tu repartidor va a recoger la ropa', { motos: [{ rol: 'recogiendo' }], nombre: N }, 5],
    ['Camino a la lavandería, por las calles de La Paz', { motos: [{ rol: 'llevando' }], nombre: N }, 10],
    ['Recibida en recepción', { colgadas: 3, destacarMia: true, nombre: N }, 6],
    ['Lavando y secando', { ciclo: true, colgadas: 2, lavando: 1, destacarMia: true, nombre: N }, 12],
    ['Ropa limpia, doblada y lista', { listas: 3, colgadas: 1, destacarMia: true, nombre: N }, 6],
    ['Vuelve a tu casa', { motos: [{ rol: 'devolviendo' }], listas: 1, nombre: N }, 10],
    ['¡Entregada en tu puerta!', { paquete: true, nombre: N }, 6],
  ];
  const capEl = document.getElementById('escena-cap'), dots = document.getElementById('escena-dots');
  if (dots) dots.innerHTML = CAP.map(() => '<i></i>').join('');
  let i = -1, timer = 0, pausado = false;
  function ir(k) {
    i = (k + CAP.length) % CAP.length;
    esc.set(CAP[i][1]);
    if (capEl) capEl.textContent = CAP[i][0];
    if (dots) [...dots.children].forEach((d, j) => (d.className = j === i ? 'on' : ''));
    clearTimeout(timer);
    timer = setTimeout(() => { if (!pausado) ir(i + 1); else timer = setTimeout(() => ir(i), 1000); }, CAP[i][2] * 1000);
  }
  ir(0);
  const fase = document.getElementById('escena-fase');
  if (fase) fase.remove();
  let exp = false;
  const hint = caja.querySelector('.hint');
  document.querySelectorAll('[data-zoom]').forEach((b) => b.addEventListener('click', () => {
    const k = b.dataset.zoom;
    if (k === '0') { exp = false; esc.reset(); pausado = false; if (hint) hint.textContent = 'Tocá ＋ y arrastrá para explorar la ciudad'; return; }
    if (!exp) { exp = true; pausado = true; esc.explorar(true); if (hint) hint.textContent = 'Explorando: arrastrá para girar · ⟲ para volver al recorrido'; }
    esc.zoom(k === '+' ? 1.25 : .8);
  }));
  if (hint) hint.textContent = 'Tocá ＋ y arrastrá para explorar la ciudad';
  document.querySelector('.escena .pie b')?.setAttribute('aria-live', 'polite');
}
