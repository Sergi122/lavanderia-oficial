/* Objetos 3D flotantes del hero (SVG con brillos y sombras) con parallax de mouse + scroll. */
(function () {
  const hero = document.querySelector('.hero');
  if (!hero) return;
  const reduce = matchMedia('(prefers-reduced-motion:reduce)').matches;
  const defs = `<defs>
    <linearGradient id="gBot" x1="0" x2="1"><stop offset="0" stop-color="#2a6fd0"/><stop offset=".45" stop-color="#6fb6ff"/><stop offset="1" stop-color="#1c4f9c"/></linearGradient>
    <linearGradient id="gTap" x1="0" x2="1"><stop offset="0" stop-color="#e9f4ff"/><stop offset="1" stop-color="#9cc7f0"/></linearGradient>
    <linearGradient id="gCam" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#bcdcff"/></linearGradient>
    <radialGradient id="gBur" cx=".35" cy=".3"><stop offset="0" stop-color="#fff" stop-opacity=".95"/><stop offset=".35" stop-color="#bfe6ff" stop-opacity=".5"/><stop offset="1" stop-color="#5aa8f0" stop-opacity=".25"/></radialGradient>
    <radialGradient id="gMaq" cx=".4" cy=".35"><stop offset="0" stop-color="#7cc2ff"/><stop offset=".6" stop-color="#2a6fd0"/><stop offset="1" stop-color="#0d2a4a"/></radialGradient>
  </defs>`;
  const OBJ = {
    botella: `<svg viewBox="0 0 120 220" width="100%">${defs}<ellipse cx="60" cy="210" rx="44" ry="8" fill="#000" opacity=".28"/>
      <rect x="44" y="6" width="32" height="22" rx="6" fill="url(#gTap)"/><rect x="38" y="26" width="44" height="14" rx="5" fill="#fff"/>
      <path d="M30 56q0-16 20-16h20q20 0 20 16v140q0 12-14 12H44q-14 0-14-12z" fill="url(#gBot)"/>
      <rect x="38" y="92" width="44" height="64" rx="10" fill="#fff" opacity=".92"/><circle cx="60" cy="116" r="12" fill="#6fb6ff"/><rect x="46" y="136" width="28" height="5" rx="2.5" fill="#2a6fd0"/>
      <path d="M38 62q-4 60 0 130" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".55" fill="none"/></svg>`,
    camisa: `<svg viewBox="0 0 200 190" width="100%">${defs}<ellipse cx="100" cy="182" rx="62" ry="7" fill="#000" opacity=".22"/>
      <path d="M62 14l-50 30 20 36 24-12v96h88V68l24 12 20-36-50-30q-10 18-38 18T62 14z" fill="url(#gCam)"/>
      <path d="M62 14q10 18 38 18t38-18" fill="none" stroke="#6fb6ff" stroke-width="5"/>
      <path d="M100 32v136" stroke="#8fc3f5" stroke-width="3" stroke-dasharray="3 7"/><circle cx="100" cy="62" r="3.4" fill="#6fb6ff"/><circle cx="100" cy="92" r="3.4" fill="#6fb6ff"/><circle cx="100" cy="122" r="3.4" fill="#6fb6ff"/>
      <path d="M44 70l14 56" stroke="#fff" stroke-width="5" stroke-linecap="round" opacity=".7"/></svg>`,
    maquina: `<svg viewBox="0 0 160 190" width="100%">${defs}<ellipse cx="80" cy="182" rx="56" ry="7" fill="#000" opacity=".25"/>
      <rect x="14" y="8" width="132" height="168" rx="20" fill="url(#gCam)"/><rect x="14" y="8" width="132" height="34" rx="20" fill="#8fc3f5"/>
      <circle cx="40" cy="26" r="6" fill="#fff"/><circle cx="60" cy="26" r="6" fill="#fff"/><circle cx="124" cy="26" r="6" fill="#3DDC84"/>
      <circle cx="80" cy="108" r="50" fill="#c9d6e6"/><circle cx="80" cy="108" r="42" fill="url(#gMaq)"/>
      <path d="M42 112q19 14 38 0t38 0v8a42 42 0 0 1-76 0z" fill="#5bb6ff" opacity=".85"/>
      <circle cx="64" cy="92" r="8" fill="#ff8e72"/><circle cx="96" cy="104" r="7" fill="#f2b84b"/><circle cx="76" cy="126" r="7" fill="#46c2a5"/>
      <ellipse cx="62" cy="84" rx="16" ry="8" fill="#fff" opacity=".35" transform="rotate(-25 62 84)"/></svg>`,
    burbuja: `<svg viewBox="0 0 100 100" width="100%"><defs><radialGradient id="gB2" cx=".32" cy=".28"><stop offset="0" stop-color="#fff" stop-opacity=".95"/><stop offset=".4" stop-color="#bfe6ff" stop-opacity=".45"/><stop offset="1" stop-color="#5aa8f0" stop-opacity=".3"/></radialGradient></defs>
      <circle cx="50" cy="50" r="46" fill="url(#gB2)" stroke="#fff" stroke-opacity=".5" stroke-width="1.5"/><ellipse cx="34" cy="30" rx="12" ry="7" fill="#fff" opacity=".7" transform="rotate(-30 34 30)"/></svg>`,
  };
  const capa = document.createElement('div');
  capa.className = 'flot'; capa.setAttribute('aria-hidden', 'true');
  const items = [
    ['botella', 'left:1%;top:86%;width:clamp(56px,6vw,96px)', 1.0, -10],
    ['camisa', 'right:3%;top:20%;width:clamp(90px,10vw,150px)', 1.4, 12],
    ['maquina', 'left:40%;top:88%;width:clamp(64px,7vw,110px)', 0.7, -6],
    ['burbuja', 'left:47%;top:14%;width:clamp(40px,5vw,72px)', 1.8, 0],
    ['burbuja', 'right:12%;top:72%;width:clamp(56px,7vw,100px)', 1.2, 0],
  ];
  items.forEach(([k, css, depth, rot], i) => {
    const el = document.createElement('div');
    el.className = 'fl'; el.style.cssText = css;
    el.dataset.d = depth; el.dataset.r = rot;
    el.innerHTML = `<div class="fi" style="animation-delay:${-i * 1.3}s">${OBJ[k]}</div>`;
    capa.appendChild(el);
  });
  hero.appendChild(capa);
  if (reduce) return;
  let mx = 0, my = 0, sy = 0, raf = 0;
  const aplicar = () => {
    raf = 0;
    capa.querySelectorAll('.fl').forEach(el => {
      const d = +el.dataset.d, r = +el.dataset.r;
      el.style.transform = `translate3d(${mx * 26 * d}px,${my * 20 * d - sy * 0.12 * d}px,0) rotate(${r + mx * 6 * d}deg)`;
    });
  };
  const pide = () => { if (!raf) raf = requestAnimationFrame(aplicar); };
  hero.addEventListener('pointermove', e => {
    const r = hero.getBoundingClientRect();
    mx = (e.clientX - r.left) / r.width - .5; my = (e.clientY - r.top) / r.height - .5; pide();
  });
  addEventListener('scroll', () => { sy = scrollY; pide(); }, { passive: true });
  pide();
})();
