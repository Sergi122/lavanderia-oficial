# Lavandería — Los Asustadores (EMI)

Aplicación móvil para la gestión de recepción, seguimiento y entrega de prendas en servicios de lavandería, mediante reconocimiento inteligente de imágenes.

## Ramas

- `main`: versión estable (solo se actualiza desde `develop`).
- `develop`: integración. Cada módulo entra aquí con un pull request.
- `feature/<módulo>`: una rama por módulo/Sprint, creada desde `develop`.

| Sprint | Módulo | Rama | Responsable |
|---|---|---|---|
| 1 | Autenticación | `feature/autenticacion` | Luis Dorado |
| 2 | Gestión de pedidos | `feature/pedidos` | Sergio Poma |
| 3 | Gestión de lavandería | `feature/lavanderia` | Paulo Ferrufino |
| 4 | Personal y empleo | `feature/personal` | Milen Aliaga |
| 5 | Finanzas | `feature/finanzas` | Emanuel Velasco |
| 6 | Reparto | `feature/reparto` | Paulo Ferrufino |
| 7 | Verificación | `feature/verificacion` | Luis Dorado |
| 8 | Administración de plataforma | `feature/plataforma` | Emanuel Velasco |
| 9 | Soporte | `feature/soporte` | Milen Aliaga |

## Cómo trabajar en tu módulo

```bash
git clone https://github.com/Sergi122/lavanderia-oficial.git
cd lavanderia-oficial
git switch feature/<tu-modulo>
# ...cambios...
git add .
git commit -m "Descripción del cambio"
git push
```

Al terminar, abre un pull request de `feature/<tu-modulo>` hacia `develop`.

Antes de tu primer commit, configura tu nombre y el correo de tu cuenta de GitHub para que los commits aparezcan a tu nombre:

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "correo-de-tu-cuenta@github"
```

No subir claves (`*adminsdk*.json`, `.env`, keystores) ni APK; ya están en `.gitignore`.
