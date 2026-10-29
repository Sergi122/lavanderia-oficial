#!/usr/bin/env python3
"""Genera landing/public/{privacidad,terminos,eliminar-cuenta}.html desde
assets/legal/legal.json (la misma fuente que muestra la app). Lo llama
deploy_web.sh antes de copiar la landing."""
import html
import json
import pathlib

raiz = pathlib.Path(__file__).resolve().parents[1]
datos = json.loads((raiz / 'assets/legal/legal.json').read_text())
salida = raiz.parent / 'landing/public'
e = html.escape

PLANTILLA = """<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{titulo} · {servicio}</title>
<link rel="icon" href="favicon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Geist:wght@400;600;700&display=swap" rel="stylesheet">
<style>
:root{{--bg:#0a1c33;--card:#0f2746;--text:#eaf4ff;--muted:#a9c4e4;--accent:#8fd7ff;--line:#1f4470}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:16px/1.6 Geist,system-ui,sans-serif}}
main{{max-width:760px;margin:auto;padding:32px 16px 64px}}a{{color:var(--accent)}}
nav{{display:flex;gap:16px;flex-wrap:wrap;font-size:14px;margin-bottom:24px}}
h1{{font-size:clamp(26px,5vw,36px);margin:0 0 4px}}h2{{font-size:19px;margin:32px 0 6px}}
.fecha{{color:var(--muted);font-size:14px}}.intro{{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:16px 18px;margin:20px 0}}
li{{margin:6px 0}}footer{{color:var(--muted);font-size:13px;margin-top:48px;border-top:1px solid var(--line);padding-top:16px}}
</style></head><body><main>
<nav><a href="/">Inicio</a><a href="/privacidad">Privacidad</a><a href="/terminos">Términos</a><a href="/eliminar-cuenta">Eliminar cuenta</a></nav>
<h1>{titulo}</h1><div class="fecha">Actualizado el {actualizado} · versión {version}</div>
{cuerpo}
<footer>{servicio} · Los Asustadores © 2026 · Escuela Militar de Ingeniería, La Paz</footer>
</main></body></html>
"""


def pagina(nombre, titulo, cuerpo):
    (salida / f'{nombre}.html').write_text(PLANTILLA.format(
        titulo=e(titulo), servicio=e(datos['servicio']), actualizado=e(datos['actualizado']),
        version=e(datos['version']), cuerpo=cuerpo))


for clave, doc in datos['documentos'].items():
    partes = [f'<p class="intro">{e(doc["intro"])}</p>']
    for s in doc['secciones']:
        partes.append(f'<h2>{e(s["titulo"])}</h2>')
        partes += [f'<p>{e(p)}</p>' for p in s.get('parrafos', [])]
        if s.get('items'):
            partes.append('<ul>' + ''.join(f'<li>{e(i)}</li>' for i in s['items']) + '</ul>')
    pagina(clave, doc['titulo'], '\n'.join(partes))

pagina('eliminar-cuenta', 'Eliminar tu cuenta', """
<p class="intro">Puedes eliminar tu cuenta de «Unión de Lavanderías La Paz» y sus datos en cualquier momento.</p>
<h2>Desde la app</h2>
<ol><li>Abre la app e inicia sesión.</li><li>Entra a <b>Perfil</b>.</li>
<li>Toca <b>Eliminar mi cuenta</b> y confirma. Si hace rato que iniciaste sesión, la app te pedirá entrar de nuevo por seguridad.</li></ol>
<h2>Qué se borra</h2>
<ul><li>Tu perfil (nombre, celular, dirección y ubicación de casa).</li>
<li>Tus solicitudes de repartidor, empleado o lavandería, con las fotos del carnet y las selfies.</li>
<li>Tu cuenta de acceso (correo y contraseña o vínculo con Google).</li></ul>
<h2>Qué se conserva</h2>
<ul><li>Los pedidos ya entregados, porque forman parte de la contabilidad de la lavandería.</li></ul>
<h2>Cuentas de lavandería</h2>
<p>Si eres dueño de una lavandería, pide la eliminación desde <b>Contáctanos</b> en tu panel, para no dejar pedidos de clientes sin atender. Respondemos en un máximo de 15 días hábiles.</p>
<p>Más detalles en la <a href="/privacidad">Política de privacidad</a>.</p>""")
print('legal: privacidad.html, terminos.html, eliminar-cuenta.html')
