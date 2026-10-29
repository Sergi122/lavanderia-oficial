# App Lavandería — Los Asustadores

Proyecto universitario (EMI). App de lavandería con delivery. Firebase project id: `laundry-app-asustadores`.

## Estructura del repo

```
lavanderia-app/
├── laundry_app/          # App Flutter (cliente, empleado, admin, verificador, repartidor, superadmin)
├── verificacion-backend/ # Servidor Node aparte, verificación automática de identidad (facial)
└── docs/requerimientos/  # .docx de la materia (capítulos, requerimientos, guía de observación)
```

`git init` está hecho en `lavanderia-app/` pero **sin commits todavía** (todo sigue "untracked"). `verificacion-backend/` tiene su propio repo git con historial real.

## App Flutter (`laundry_app/`)

- Stack: Flutter + Firebase (`firebase_auth`, `cloud_firestore`, `firebase_messaging`), `flutter_riverpod` + `go_router`, `flutter_map`/`latlong2`/`geolocator` (mapa con OpenStreetMap, sin API key), `camera` + `google_mlkit_face_detection` (verificación con cámara en vivo), `flutter_background_service` (notificaciones en foreground service, verificado real en Android 14).
- `pubspec.yaml` versión sigue en `1.0.0+1` — **no se incrementa el build number**, así que no hay forma de distinguir APKs por versión, solo por fecha de compilación del archivo.
- `lib/features/`: `auth`, `client` (13 archivos, el más grande), `shared` (models/services/widgets comunes), `employee`, `admin`, `verificador`, `repartidor`, `superadmin`.
- Roles: Cliente, Empleado, Admin (de una lavandería), Verificador, Repartidor, Superadmin. Todo usuario nuevo entra como `cliente`; nadie se autoasigna un rol más alto (reforzado en `firestore.rules`) — roles altos (admin/verificador/superadmin) se asignan a mano en Firestore.
- `lib/core/verificacion/`: pipeline de verificación de identidad con cámara en vivo:
  - `capturador_selfie_en_vivo.dart` — captura selfie con cámara en vivo + arco guía (estilo wizard "Persona")
  - `validador_selfie.dart` — prefiltro de cara con ML Kit on-device (gratis, NO compara contra el carnet, solo valida que hay una cara válida en cuadro)
  - `backend_verificacion.dart` — llama al backend Node para la comparación facial real
  - `paso_identidad.dart` — orquesta el paso dentro del wizard de registro
- Notificaciones background: foreground service confirmado real solo en **AVD Test_API_34** (el emulador de API 36 preview no sirve para probar esto).

## `verificacion-backend/`

Servidor Node/Express aparte (NO Firebase Cloud Functions, NO plan Blaze) que:
- Compara la selfie contra la foto del carnet con `@vladmandic/face-api` + `@tensorflow/tfjs-node` + `canvas`.
- Si coincide, aprueba automáticamente en Firestore vía API REST con una Service Account (el celular del usuario nunca tiene permiso de escritura directa para eso).
- Umbral de coincidencia: distancia euclidiana 0.5 (repartidor pide además ≥70% de similitud, con dos documentos + selfie).
- Detecta posibles duplicados (misma lavandería, o misma moto con otro CI).
- Flujo de aprobación de lavandería en **dos etapas**: verificador humano = identidad de la persona, superadmin = validez del local.
- Pensado para desplegar gratis en Render (Dockerfile ya probado localmente, Node 20).
- Historial real en `verificacion-backend/.git` — ahí sí hay commits legibles con `git log`.

## Dónde encontrar el APK generado

- `Downloads/laundry-app-debug.apk` y `laundry_app/build/app/outputs/flutter-apk/app-debug.apk` deberían tener el mismo tamaño/timestamp (el build copia uno a Downloads). Para saber si es reciente: comparar el mtime del APK contra el mtime de los `.dart` en `lib/core/verificacion/` — si el APK es más nuevo que esos archivos, incluye la última verificación.
- Como el build number no cambia, **la única forma confiable de saber qué versión es un APK es por fecha de archivo**, no por número de versión visible en la app.

## Gotchas / cosas ya resueltas (no re-investigar)

- Selfies + ML Kit: el prefiltro de cara es solo on-device y gratis; la comparación real contra el carnet la hace el backend. Falta probar con celular físico real (solo probado en emulador).
- No cazar clics en pruebas de UI: verificar cambios con analyze + test + 1 screenshot, no encadenando clics por pantalla.
- Notificaciones: 3 bugs ya corregidos en el foreground service; probar siempre en AVD Test_API_34, no en el de API 36 preview.
