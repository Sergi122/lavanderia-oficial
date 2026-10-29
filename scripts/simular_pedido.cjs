// Simula, contra Firestore real, el ciclo completo de un pedido con delivery: el repartidor se acerca
// a la casa (GPS), recoge, lleva a la lavandería, el empleado la pone "en proceso" y luego "lista",
// y el repartidor la devuelve. Sirve para ver la ciudad 3D sincronizada en el cliente y el admin.
//   node simular_pedido.cjs <clienteUid> <lavanderiaId> [segundosPorPaso=5]
// Usa solo la cuenta de servicio (no toca contraseñas). Cada PATCH lleva updateMask: nunca reemplaza un doc entero.
const { GoogleAuth } = require('../verificacion-backend/node_modules/google-auth-library');
const fs = require('fs');
const key = JSON.parse(fs.readFileSync(process.env.HOME + '/Downloads/laundry-app-asustadores-firebase-adminsdk-fbsvc-adb85a5afd.json'));
const P = 'laundry-app-asustadores';
const [uid, LAV, seg = '5'] = process.argv.slice(2);
if (!uid || !LAV) { console.error('uso: node simular_pedido.cjs <clienteUid> <lavanderiaId> [segundosPorPaso]'); process.exit(1); }
const CASA = [-16.5050, -68.1450], LAVC = [-16.5000, -68.1500], LEJOS = [-16.5150, -68.1350];
const v = (x) => typeof x === 'string' ? { stringValue: x } : typeof x === 'boolean' ? { booleanValue: x } : typeof x === 'number' ? { doubleValue: x } : x === null ? { nullValue: null } : x instanceof Date ? { timestampValue: x.toISOString() } : { mapValue: { fields: Object.fromEntries(Object.entries(x).map(([k, y]) => [k, v(y)])) } };
// Convierte un documento de la API REST de Firestore a un objeto plano (para leer lo que de verdad quedó guardado).
const plano = (x) => x.stringValue !== undefined ? x.stringValue : x.booleanValue !== undefined ? x.booleanValue : x.doubleValue !== undefined ? x.doubleValue
  : x.integerValue !== undefined ? Number(x.integerValue) : x.timestampValue !== undefined ? null : x.nullValue !== undefined ? null
  : x.mapValue ? Object.fromEntries(Object.entries(x.mapValue.fields || {}).map(([k, y]) => [k, plano(y)])) : null;
const dormir = (s) => new Promise((r) => setTimeout(r, s * 1000));
const lerp = (a, b, t) => a + (b - a) * t;
(async () => {
  const T = (await (await new GoogleAuth({ credentials: key, scopes: ['https://www.googleapis.com/auth/cloud-platform'] }).getClient()).getAccessToken()).token;
  const H = { Authorization: 'Bearer ' + T, 'Content-Type': 'application/json' };
  const base = `https://firestore.googleapis.com/v1/projects/${P}/databases/(default)/documents`;
  // crear pedido nuevo
  const campos = { clienteId: uid, lavanderiaId: LAV, lavanderiaNombre: 'Lavandería de Prueba', prendas: { Camisas: 3, Pantalones: 2 }, notas: 'simulación', estado: 'recibido',
    tipoEntrega: 'recojoDomicilio', direccionRecojo: 'Calle de prueba 123', recojoLat: CASA[0], recojoLng: CASA[1], costoPrendas: 50, costoEnvio: 10, repartidorUid: null, entregaCompletada: false, creadoEn: new Date() };
  const c = await fetch(`${base}/pedidos`, { method: 'POST', headers: H, body: JSON.stringify({ fields: Object.fromEntries(Object.entries(campos).map(([k, y]) => [k, v(y)])) }) });
  const id = (await c.json()).name.split('/').pop();
  console.log('pedido creado', id);
  const patch = async (o) => {
    const m = Object.keys(o).map((k) => 'updateMask.fieldPaths=' + k).join('&');
    const r = await fetch(`${base}/pedidos/${id}?${m}`, { method: 'PATCH', headers: H, body: JSON.stringify({ fields: Object.fromEntries(Object.entries(o).map(([k, y]) => [k, v(y)])) }) });
    if (!r.ok) throw new Error(await r.text());
  };
  const gps = (a, b, t) => ({ repartidorLat: lerp(a[0], b[0], t), repartidorLng: lerp(a[1], b[1], t), repartidorActualizadoEn: new Date() });
  const instantaneas = [];
  const paso = async (txt, o, s = +seg) => {
    console.log(txt); if (Object.keys(o).length) await patch(o);   // nunca un PATCH sin máscara: reemplazaría el documento
    if (process.env.INSTANTANEAS) {   // lee de vuelta lo guardado en Firestore, tal como lo vería la app
      const d = await (await fetch(`${base}/pedidos/${id}`, { headers: H })).json();
      instantaneas.push({ paso: txt, id, datos: Object.fromEntries(Object.entries(d.fields).map(([k, y]) => [k, plano(y)])) });
    }
    await dormir(s);
  };

  await paso('1) Esperando repartidor (sin asignar)', {}, +seg);
  await paso('2) Repartidor acepta (aceptado) y sale de lejos', { repartidorUid: 'repartidor-prueba', repartidorNombre: 'Repartidor Prueba', etapaReparto: 'aceptado', ...gps(LEJOS, CASA, 0) });
  for (let i = 1; i <= 6; i++) await paso(`   se acerca a la casa ${i}/6`, gps(LEJOS, CASA, i / 6));
  await paso('3) Recogió la ropa (recogido)', { etapaReparto: 'recogido', ...gps(CASA, LAVC, 0) });
  for (let i = 1; i <= 6; i++) await paso(`   va a la lavandería ${i}/6`, gps(CASA, LAVC, i / 6));
  await paso('4) Llegó a la lavandería (enLavanderia, estado recibido)', { etapaReparto: 'enLavanderia' }, +seg * 1.5);
  await paso('5) El empleado la pone EN PROCESO: lavando y secando (dura hasta marcarla lista)', { estado: 'enProceso' }, +seg * 5);
  await paso('6) El empleado la marca LISTA', { estado: 'listo' }, +seg * 1.5);
  await paso('7) Repartidor sale a devolverla (devolviendo)', { etapaReparto: 'devolviendo', ...gps(LAVC, CASA, 0) });
  for (let i = 1; i <= 6; i++) await paso(`   vuelve a la casa ${i}/6`, gps(LAVC, CASA, i / 6));
  await paso('8) Entregada', { etapaReparto: 'completada', entregaCompletada: true, estado: 'entregado' }, +seg);
  if (process.env.INSTANTANEAS) { fs.writeFileSync(process.env.INSTANTANEAS, JSON.stringify(instantaneas, null, 1)); console.log('instantáneas:', instantaneas.length); }
  console.log('fin');
})().catch((e) => { console.error(e); process.exit(1); });
