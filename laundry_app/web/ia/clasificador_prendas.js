// IA de prendas en el navegador: el mismo modelo .tflite que usa Android,
// ejecutado con tfjs-tflite (WebAssembly). Lo carga clasificador_web.dart
// solo cuando el empleado abre "Registrar prendas".
(function () {
  const CDN = 'https://cdn.jsdelivr.net/npm/';
  const LIBS = [
    '@tensorflow/tfjs-core@4.22.0/dist/tf-core.min.js',
    '@tensorflow/tfjs-backend-cpu@4.22.0/dist/tf-backend-cpu.min.js',
    '@tensorflow/tfjs-tflite@0.0.1-alpha.10/dist/tf-tflite.min.js',
  ];
  const LADO = 224;
  let modelo = null;

  function cargar(src) {
    return new Promise((ok, mal) => {
      const s = document.createElement('script');
      s.src = CDN + src; s.onload = ok; s.onerror = mal;
      document.head.appendChild(s);
    });
  }

  async function listo() {
    if (modelo) return modelo;
    for (const l of LIBS) await cargar(l);
    tflite.setWasmPath(CDN + '@tensorflow/tfjs-tflite@0.0.1-alpha.10/wasm/');
    modelo = await tflite.loadTFLiteModel('assets/assets/models/prendas_mobilenetv2.tflite');
    return modelo;
  }

  // Recorte cuadrado central a 224×224 (igual que en Android y en el
  // entrenamiento); el modelo recibe píxeles 0..255 y normaliza adentro.
  window.clasificarPrenda = async function (base64) {
    const m = await listo();
    const img = new Image();
    img.src = 'data:image/jpeg;base64,' + base64;
    await img.decode();
    const lado = Math.min(img.width, img.height);
    const c = document.createElement('canvas');
    c.width = c.height = LADO;
    c.getContext('2d').drawImage(img, (img.width - lado) / 2, (img.height - lado) / 2, lado, lado, 0, 0, LADO, LADO);
    const entrada = tf.tidy(() => tf.expandDims(tf.cast(tf.browser.fromPixels(c), 'float32'), 0));
    const salida = m.predict(entrada);
    const probs = Array.from(await salida.data());
    entrada.dispose(); salida.dispose();
    return probs;
  };
})();
