#!/usr/bin/env python3
"""Lamina una placa de mitades de punteiro (o un tramo de prueba) con los ajustes de CAMBIOS_SLICER.md, en dos pasadas.

Uso (desde cualquier sitio):
  python3 laminar.py pla|asa arriba|abajo|anilla [--n N] [--sin-anilla] [--sin-pie] [--espera S] [--version V] [--out DIR] [-f]
  python3 laminar.py pla|asa tramo Z0 Z1 [--n N] [--espera S] [--out DIR] [-f]
  python3 laminar.py pla|asa arriba --hasta Z [...]   # sólo el arranque (pie, espiga, resalte) hasta z modelo Z
  python3 laminar.py --congelar V   # copia perfiles (tal cual y resueltos, sin credenciales) y el laminado a stls/vV/
    arriba       do_arriba con pie de agarre (punteiro_do_arriba_pie); --sin-pie usa punteiro_do_arriba
    abajo        do_abajo con anilla; --sin-anilla usa punteiro_do_abajo_sin_anilla
    anilla       la anilla suelta, con el proceso de punteiros (en julio no había proceso de anilla)
    tramo Z0 Z1  cuerpo entre z modelo Z0 y Z1, bajado a z 0, con sus agujeros y sin soporte (pruebas)
    --n N        copias en rejilla centrada (por defecto 2; 1 en tramo); dice cuántas caben si no caben
    --espera S   en cada cambio de capa sube 1 mm, aparca en una esquina y espera S s (enfría como una placa de
                 más piezas); quita el freno por tiempo de capa, que no cuenta la espera
    --ajuste K=V ajuste de proceso (o de máquina, si la clave es de máquina) sólo para esta laminación
                 (se puede repetir; pruebas)
    --perfiles D perfiles ya resueltos de D (machine/, process/, filament/ con los nombres de siempre) en vez de
                 los de dotfiles (pruebas con perfiles antiguos)
    --rangos     con los rangos de los arcos, techos y reborde (descartados; por defecto sólo el del pie)
    --version V  set de la versión V: STL congelados de stls/vV/ y, si están, sus perfiles congelados
                 (stls/vV/perfiles/resueltos/); salida gcode/vV/<mat>/vV_<mat>_<pieza>_xN.*, sin `make`; si ya
                 existe lo salta (lo usa `make laminar V=…`)
    --out DIR    carpeta de salida (por defecto gcode/v<actual+1>/pruebas/, actual = la vN más alta de stls/)
    -f           sobrescribe si el gcode ya existe

Pasos: make → perfiles aplanados (+ sobreescrituras del §1) → rangos (pie; con --rangos, arcos_agujeros.py) → 1.ª pasada
(exporta el 3MF) → mete los rangos y recoloca los dos objetos conservando su z → 2.ª pasada → copia
gcode y 3MF a <out>/DD_MM_<mat>_<pieza>_xN.* → comprobaciones del §4.
"""
import glob, json, math, os, re, shutil, subprocess, sys, tempfile, time, uuid, zipfile
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
import arcos_agujeros as A

P = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../..'))
U = os.path.expanduser('~/.dotfiles/configs/OrcaSlicer/user/default/')
SISTEMA = os.path.expanduser('~/.config/OrcaSlicer/system/*/*/*.json')
MAQUINA = 'machine/core-one-obxidian.json'
PROCESO = 'process/core-one-{m}-obxidian-quality-punteiros.json'
FILAMENTO = {'pla': 'filament/core-one-pla-polymaker-panchroma.json', 'asa': 'filament/core-one-asa.json'}
CENTRO = (125, 110)
CAMA = (250, 220)
HUECO = 15                                           # mm entre bordes
BRIM = 12
# (STL, Ø que fija la separación, Ø en la cama, ajustes de proceso, z impreso del escalón a soportar). Arriba
# manda la mesa Ø33 (los discos Ø40 del pie quedan a 8 mm); abajo, la anilla Ø48 o la boca Ø40. El brim
# tiene que caber en la cama: margen = Ø en la cama / 2 + BRIM. El soporte forzado cubre hasta el escalón
# (resalte de la espiga, o asiento de la anilla) con 2 capas de margen.
PIEZAS = {
    ('arriba', True):  ('punteiro_do_arriba_pie', 33, 40, dict(support_on_build_plate_only='0',
                                                                support_bottom_z_distance='0'), 10),
    ('arriba', False): ('punteiro_do_arriba', 33, 17.9, {}, 6),
    ('abajo', True):   ('punteiro_do_abajo_con_anilla', 48, 48, {}, 6),
    ('abajo', False):  ('punteiro_do_abajo_sin_anilla', 40, 40, {}, 6),
    ('anilla', False): ('anilla', 48, 48, {}, 0),
}
NOMBRES = {('arriba', True): 'punteiro_arriba', ('arriba', False): 'punteiro_arriba_sin_pie',
           ('abajo', True): 'punteiro_abajo_con_anilla', ('abajo', False): 'punteiro_abajo_sin_anilla',
           ('anilla', False): 'anilla'}
PRIMERA = 0.24
DISCO = 2.0                                          # alto del disco del pie (pie_alto), z impreso
CUELLO = 2.0                                         # alto de las pestañas (pie_cuello): también a 2·base
# El disco del pie se tira: capas dobles, relleno y 100 mm/s (la primera capa sigue a 20 para agarrar).
DISCO_AJUSTES = dict(sparse_infill_density='25%', top_shell_layers='4', bottom_shell_layers='1',
                     top_shell_thickness='0', bottom_shell_thickness='0',
                     outer_wall_speed='100', inner_wall_speed='100', sparse_infill_speed='100',
                     internal_solid_infill_speed='100', top_surface_speed='50', gap_infill_speed='100')
# Las pestañas apoyan en la cara superior: 4 capas macizas (con 2 la 1.ª era puente sobre el relleno) y a 50.
# Con pie, el soporte sale de un reforzador anular sólo en el resalte (z impreso 10) y no de
# enforce_support_layers, que también soportaba la punta de la espiga entre las pestañas (y pasa por encima
# de los bloqueadores): el soporte quedaba soldado a ellas.
REFUERZO = dict(r0=8.5, r1=10.6, z0=9.6, z1=10.4)
# techo de cada agujero (fin de cada tramo de rangos = cresta): el relleno de huecos del centro de la pared (classic)
# cruza la cresta; a la velocidad de las paredes del techo, no a la normal, o se levanta y la boquilla lo engancha
TECHO = dict(antes=0.6, despues=1.0, gap_infill_speed='15')

# reborde de la mesa (z modelo): ensancha a Ø33 y cierra con un escalón plano a Ø18 en 288; con relleno disperso
# dentro, lleva puente interno y macizo y superficie superior en líneas rectas de lado a lado, que empujan la
# torre en vaivén (ahí cayeron dos torres PLA). Macizo y en vueltas hasta 288.5; de ahí a la cima, sólo en vueltas
REBORDE = dict(z0=269, z1=288.5, z2=313)
VUELTAS = dict(internal_solid_infill_pattern='concentric', top_surface_pattern='concentric')


def reborde(xml, base, off):
    a, b, c = (REBORDE[k] - off for k in ('z0', 'z1', 'z2'))
    rng = ['  <range min_z="%g" max_z="%g">' % (a, b), '   <option opt_key="layer_height">%g</option>' % base,
           '   <option opt_key="sparse_infill_density">100%</option>']
    rng += ['   <option opt_key="%s">%s</option>' % kv for kv in VUELTAS.items()]
    rng += ['  </range>', '  <range min_z="%g" max_z="%g">' % (b, c),
            '   <option opt_key="layer_height">%g</option>' % base]
    rng += ['   <option opt_key="%s">%s</option>' % kv for kv in VUELTAS.items()]
    rng += ['  </range>']
    return xml.replace(' </object>', '\n'.join(rng) + '\n </object>')


def techos(xml, base):
    def obj(m_):
        rs = re.findall(r'  <range min_z="([\d.]+)" max_z="([\d.]+)">\n(.*?)  </range>\n', m_.group(2), re.S)
        out = []
        for i, (a, b, cuerpo) in enumerate(rs):
            a, b = float(a), float(b)
            fin = i + 1 == len(rs) or abs(float(rs[i + 1][0]) - b) > 1e-6
            fin_grupo = next(float(rs[j][1]) for j in range(i, len(rs))
                             if j + 1 == len(rs) or abs(float(rs[j + 1][0]) - float(rs[j][1])) > 1e-6)
            if b > fin_grupo - TECHO['antes']:
                cuerpo += '   <option opt_key="gap_infill_speed">%s</option>\n' % TECHO['gap_infill_speed']
            out.append('  <range min_z="%g" max_z="%g">\n%s  </range>\n' % (a, b, cuerpo))
            if fin:
                out.append('  <range min_z="%g" max_z="%g">\n   <option opt_key="layer_height">%g</option>\n'
                           '   <option opt_key="gap_infill_speed">%s</option>\n  </range>\n'
                           % (b, b + TECHO['despues'], base, TECHO['gap_infill_speed']))
        return m_.group(1) + ''.join(out) + m_.group(3)
    return re.sub(r'(<object id="\d+">\n)(.*?)( </object>)', obj, xml, flags=re.S)


def rejilla(n, paso, margen):
    """Centros de n copias en rejilla centrada en la cama; error si no caben."""
    cmax = int((CAMA[0] - 2 * margen) // paso) + 1
    fmax = int((CAMA[1] - 2 * margen) // paso) + 1
    if n > cmax * fmax:
        sys.exit('caben como mucho %d (%d × %d) con paso %g mm' % (cmax * fmax, cmax, fmax, paso))
    filas = -(-n // cmax); cols = -(-n // filas)
    out = []
    for f in range(filas):
        k = min(cols, n - f * cols)
        for c in range(k):
            out.append((CENTRO[0] + (c - (k - 1) / 2) * paso, CENTRO[1] + (f - (filas - 1) / 2) * paso))
    return out
CORTE = 82                                           # cortes = [82] del .scad: un tramo por encima es de do_arriba


PERFILES = [MAQUINA] + [PROCESO.format(m=m) for m in FILAMENTO] + list(FILAMENTO.values())
SECRETOS = ('print_host', 'print_host_webui', 'printhost_authorization_type', 'printhost_password', 'printhost_user')
LAMINADO = ['.claude/skills/slice-punteiros/laminar.py', 'arcos_agujeros.py', 'CAMBIOS_SLICER.md', 'Makefile']


def congelar(ver):
    """stls/vV/perfiles/ (los JSON de usuario tal cual y resueltos sobre la base del sistema, la máquina sin
    credenciales) y stls/vV/laminado/ (script, arcos, CAMBIOS_SLICER, Makefile). Lo congelado no se pisa."""
    d = os.path.join(P, 'stls', 'v' + ver); go = aplanar(); fs = {}
    for path in PERFILES:
        typ = path.split('/')[0]
        crudo, res = json.load(open(U + path)), go(path, typ)
        for j in (crudo, res):
            for k in SECRETOS:
                j.pop(k, None)
        fs['perfiles/' + path] = json.dumps(crudo, indent=4, ensure_ascii=False) + '\n'
        fs['perfiles/resueltos/' + path] = json.dumps(res, indent=4, ensure_ascii=False, sort_keys=True) + '\n'
    for f in LAMINADO:
        fs['laminado/' + os.path.basename(f)] = open(os.path.join(P, f)).read()
    for rel, txt in fs.items():
        f = os.path.join(d, rel)
        if os.path.exists(f):
            if open(f).read() != txt:
                sys.exit('%s difiere: v%s ya está congelada' % (os.path.relpath(f, P), ver))
            continue
        os.makedirs(os.path.dirname(f), exist_ok=True); open(f, 'w').write(txt)
    print('perfiles y laminado congelados en %s' % os.path.relpath(d, P))


def aplanar(resueltos=None):
    if resueltos:                                    # perfiles congelados de una versión, ya resueltos
        def go_r(path, typ, **ov):
            r = json.load(open(os.path.join(resueltos, path))); r.update(ov); return r
        return go_r
    idx = {}
    for f in glob.glob(SISTEMA):
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if 'name' in d:
            idx.setdefault(d['name'], d)

    def res(d):
        if 'inherits' in d and d['inherits'] in idx:
            p = res(idx[d['inherits']]); p.update(d); return p
        return dict(d)

    def go(path, typ, **ov):
        d = json.load(open(U + path)); r = res(d); r['type'] = typ; r.update(ov)
        if typ == 'machine':
            r['inherits'] = d['inherits']
        else:
            r.pop('inherits', None)
        return r
    return go


def actual():
    """Versión actual: la vN más alta congelada en stls/."""
    vs = [int(d[1:]) for d in os.listdir(os.path.join(P, 'stls')) if re.fullmatch(r'v\d+', d)]
    return max(vs, default=0)


def run(cmd, log):
    with open(log, 'w') as f:
        r = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    return r.returncode


def main():
    a = sys.argv[1:]
    if a[:1] == ['--congelar'] and len(a) == 2:
        return congelar(a[1])
    if len(a) < 2 or a[0] not in FILAMENTO or a[1] not in ('arriba', 'abajo', 'anilla', 'tramo'):
        sys.exit(__doc__)
    mat, parte = a[0], a[1]
    ver = a[a.index('--version') + 1] if '--version' in a else None
    stls = os.path.join(P, 'stls', 'v' + ver) if ver else os.path.join(P, 'stls')
    if ver:
        out = os.path.join(P, 'gcode', 'v' + ver, mat)
    elif '--out' in a:
        out = os.path.abspath(a[a.index('--out') + 1])
    else:
        out = os.path.join(P, 'gcode', 'v%d' % (actual() + 1), 'pruebas')
    espera = float(a[a.index('--espera') + 1]) if '--espera' in a else 0
    seg = None
    if parte == 'tramo':
        seg = (float(a[2]), float(a[3]))
        mitad = 'arriba' if seg[0] >= CORTE else 'abajo'
        diam = 33 if mitad == 'arriba' else 48
        stl, d_cama, proc_aj, z_escalon = None, diam, dict(enable_support='0'), 0
        nombre_pieza = 'segmento_%g_%g' % seg
    else:
        mitad = parte
        extra = {'arriba': '--sin-pie' not in a, 'abajo': '--sin-anilla' not in a, 'anilla': False}[parte]
        stl, diam, d_cama, proc_aj, z_escalon = PIEZAS[(parte, extra)]
        nombre_pieza = NOMBRES[(parte, extra)]
    hasta = float(a[a.index('--hasta') + 1]) if '--hasta' in a else None
    if hasta is not None and not seg:
        if (parte, extra) != ('arriba', True):
            sys.exit('--hasta sólo con arriba (con pie)')
        nombre_pieza += '_hasta_%g' % hasta
    sop_max = z_escalon + 1
    n = int(a[a.index('--n') + 1]) if '--n' in a else (1 if seg else 2)
    centros = rejilla(n, diam + HUECO, d_cama / 2 + BRIM)
    nombre = '%s_%s_%s_x%d' % ('v' + ver if ver else time.strftime('%d_%m'), mat, nombre_pieza, n)
    destino = os.path.join(out, nombre + '.gcode')
    if os.path.exists(destino) and '-f' not in a:
        if ver:
            print('ya existe %s, se salta' % os.path.relpath(destino, P)); return
        sys.exit('ya existe %s (usa -f para sobrescribir)' % destino)

    if ver:
        if not os.path.isdir(stls):
            sys.exit('no existe %s: congela antes la versión (make congelar V=%s)' % (stls, ver))
    else:
        subprocess.run(['make', '-s'], cwd=P, check=True, stdout=subprocess.DEVNULL)
    w = tempfile.mkdtemp(prefix='laminar_')
    congelados = os.path.join(stls, 'perfiles', 'resueltos') if ver else None
    go = aplanar(os.path.abspath(a[a.index('--perfiles') + 1]) if '--perfiles' in a else
                 congelados if congelados and os.path.isdir(congelados) else None)
    m = go(MAQUINA, 'machine')
    ajustes = dict(a[i + 1].split('=', 1) for i, x in enumerate(a) if x == '--ajuste')
    aj_maq = {k: ajustes.pop(k) for k in list(ajustes) if k in m}   # claves de máquina (wipe, retracción…)
    p = go(PROCESO.format(m=mat), 'process',
           compatible_printers=[m['inherits']], compatible_printers_condition='', **proc_aj, **ajustes)
    base = float(p['layer_height'])
    p['enforce_support_layers'] = '0' if seg or not z_escalon or stl == 'punteiro_do_arriba_pie' else \
        str(int(-(-round((z_escalon - PRIMERA) / base, 6) // 1)) + 2)
    f = go(FILAMENTO[mat], 'filament', compatible_printers=[], compatible_printers_condition='',
           compatible_prints=[], compatible_prints_condition='')
    # La 2.ª pasada lamina desde el 3MF, que pierde algunos ajustes de retracción del filamento
    # (filament_retract_before_wipe sale como nil): se copian también a la máquina.
    for k in ('retract_before_wipe', 'retraction_length', 'retraction_speed', 'deretraction_speed',
              'wipe_distance', 'retract_restart_extra', 'z_hop'):
        v = f.get('filament_' + k)
        if v and v[0] != 'nil':
            m[k] = v
    for k, v in aj_maq.items():
        m[k] = [v] if isinstance(m[k], list) else v
    if espera:
        lc = m['layer_change_gcode'][0] if isinstance(m['layer_change_gcode'], list) else m['layer_change_gcode']
        m['layer_change_gcode'] = lc + ('\n{if layer_num > 0}G1 Z{layer_z + 1} F720 ; espera entre capas\n'
                                        'G1 X%g Y%g F7200\nG4 S%g\n{endif}' % (CAMA[0] - 10, CAMA[1] - 10, espera))
        f['slow_down_for_layer_cooling'] = ['0']
    for k, d in (('m', m), ('p', p), ('f', f)):
        json.dump(d, open(os.path.join(w, k + '.json'), 'w'), indent=1)
    if seg:
        scad = os.path.join(w, 'tramo.scad')
        open(scad, 'w').write('include <%s/scads/punteiro.scad>\ntranslate([0, 0, -%g]) intersection() '
                              '{ cuerpo(); losa(%g, %g); }\n' % (P, seg[0], seg[0], seg[1]))
        subprocess.run(['openscad', '-o', os.path.join(w, 'tramo.stl'), '-D', 'parte_1=0', '-D', 'parte_2=0',
                        '-D', 'con_anilla=0', '-D', 'anilla=0', '-D', 'medio=0', scad], check=True, capture_output=True)
        fuente, arcos = os.path.join(w, 'tramo.stl'), ['--seg', '%g' % seg[0], '%g' % seg[1]]
    elif hasta is not None:
        scad = os.path.join(w, 'arranque.scad')
        open(scad, 'w').write('include <%s>\nintersection() { pieza(1, lims, n); losa(-100, %g); }\n'
                              % (os.path.join(stls if ver else os.path.join(P, 'scads'), 'punteiro.scad'), hasta))
        subprocess.run(['openscad', '-o', os.path.join(w, 'arranque.stl'), '-D', 'pie=1', '-D', 'parte_1=0',
                        '-D', 'parte_2=0', '-D', 'con_anilla=0', '-D', 'anilla=0', '-D', 'medio=0', scad],
                       check=True, capture_output=True)
        # los arcos, del STL entero (misma z que el arranque): los rangos que quedan por encima no hacen nada
        fuente, arcos = os.path.join(w, 'arranque.stl'), ['--stl', os.path.relpath(os.path.join(stls, stl + '.stl'), P)]
    else:
        fuente = os.path.join(stls, stl + '.stl')
        arcos = ['--stl', os.path.relpath(fuente, P)]
    sin_rangos = '--rangos' not in a
    if sin_rangos:
        arcos = None
    for i in range(1, n + 1):
        shutil.copy(fuente, os.path.join(w, '%s%d.stl' % (parte, i)))
    xml = None if parte == 'anilla' else ('<?xml version="1.0" encoding="utf-8"?>\n<objects>\n' + ''.join(
        ' <object id="%d">\n </object>\n' % i for i in range(1, n + 1)) + '</objects>') if arcos is None else subprocess.run(
        [sys.executable, 'arcos_agujeros.py', mitad, '--base', str(base), '--xml', ','.join('0' * n)] + arcos,
        cwd=P, check=True, capture_output=True, text=True).stdout
    if arcos is not None and parte != 'anilla':
        xml = techos(xml, base)
    if mitad == 'arriba' and parte != 'anilla' and not sin_rangos:
        off = seg[0] if seg else min(v[2] for v in A.vertices(fuente))
        if (seg[1] if seg else hasta if hasta is not None else 1e9) > REBORDE['z0']:
            xml = reborde(xml, base, off)
    if stl == 'punteiro_do_arriba_pie':
        # rango del disco: capas de 2·base que acaban en un punto de la rejilla de base (no mueve los agujeros);
        # Orca busca la capa siguiente en print_z + ½·min_layer_height, que queda fuera a partir de esa z
        k = -(-round((DISCO - PRIMERA) / (2 * base), 6) // 1)
        fin = PRIMERA + k * 2 * base
        k2 = -(-round((DISCO + CUELLO - PRIMERA) / (2 * base), 6) // 1)
        fin2 = PRIMERA + k2 * 2 * base                   # pestañas (y su soporte) también a 2·base
        rng = ['  <range min_z="%g" max_z="%g">' % (PRIMERA, fin - base / 2),
               '   <option opt_key="layer_height">%g</option>' % (2 * base)]
        rng += ['   <option opt_key="%s">%s</option>' % kv for kv in DISCO_AJUSTES.items()]
        rng += ['  </range>', '  <range min_z="%g" max_z="%g">' % (fin - base / 2, fin2 - base / 2),
                '   <option opt_key="layer_height">%g</option>' % (2 * base), '  </range>']
        xml = re.sub(r'(<object id="\d+">)', lambda m_: m_.group(1) + '\n' + '\n'.join(rng), xml)

    S = ['orca-slicer', '--datadir', os.path.expanduser('~/.config/OrcaSlicer'),
         '--load-settings', os.path.join(w, 'm.json') + ';' + os.path.join(w, 'p.json'),
         '--load-filaments', os.path.join(w, 'f.json')]
    os.chdir(w); os.makedirs('o1')
    if run(S + ['--arrange', '1', '--export-3mf', 'plate.3mf', '--outputdir', 'o1'] +
           ['%s%d.stl' % (parte, i) for i in range(1, n + 1)], 'l1.txt'):
        sys.exit('falla la 1.ª pasada: %s/l1.txt' % w)
    x = os.path.join(w, 'x'); zipfile.ZipFile('o1/plate.3mf').extractall(x)
    if xml:
        open(os.path.join(x, 'Metadata/layer_config_ranges.xml'), 'w').write(xml)
    if stl == 'punteiro_do_arriba_pie':
        modificador(x, 'support_enforcer', **REFUERZO)
    mod = os.path.join(x, '3D/3dmodel.model'); s = open(mod).read()
    for oid, (cx, cy) in zip(re.findall(r'<item objectid="(\d+)"', s), centros):
        zt = re.search(r'<item objectid="%s"[^>]*?transform="([^"]*)"' % oid, s).group(1).split()[-1]
        s = re.sub(r'(<item objectid="%s"[^>]*?transform=")[^"]*"' % oid,
                   r'\g<1>1 0 0 0 1 0 0 0 1 %g %g %s"' % (cx, cy, zt), s)
    open(mod, 'w').write(s)
    for g in glob.glob(os.path.join(x, 'Metadata/plate_*.gcode*')):
        os.remove(g)
    with zipfile.ZipFile('t.3mf', 'w', zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(x):
            for fn in files:
                full = os.path.join(root, fn); z.write(full, os.path.relpath(full, x))
    if run(S + ['--arrange', '0', '--slice', '0', '--outputdir', 'o2', 't.3mf'], 'l2.txt'):
        sys.exit('falla la 2.ª pasada: %s/l2.txt' % w)
    os.makedirs(out, exist_ok=True)
    shutil.copy('t.3mf', os.path.join(out, nombre + '.3mf'))
    shutil.copy('o2/plate_1.gcode', destino + '.tmp'); os.replace(destino + '.tmp', destino)   # nunca a medias
    comprobar(destino, fuente if stl else None, mitad, sop_max, centros, seg, agujeros=hasta is None and not sin_rangos)
    shutil.rmtree(w)


def modificador(x, tipo, r0, r1, z0, z1, lados=64):
    """Añade a cada objeto del 3MF extraído en x un volumen anular (r0–r1, z impreso z0–z1) de subtipo tipo
    (support_enforcer, support_blocker…)."""
    mod = os.path.join(x, '3D/3dmodel.model'); s = open(mod).read()
    cfg = os.path.join(x, 'Metadata/model_settings.config'); c = open(cfg).read()
    nid = 1000
    for oid, path, mid, tr in re.findall(r'<object id="(\d+)"[^>]*>\s*<components>\s*<component p:path="([^"]+)" '
                                        r'objectid="(\d+)"[^>]*transform="([^"]+)"', s):
        nid += 1
        f = os.path.join(x, path.lstrip('/')); o = open(f).read()
        vmin = min(float(v) for v in re.findall(r'<vertex [^>]*z="([^"]+)"', o))   # z local de la base
        za, zb = vmin + z0, vmin + z1
        # anillos: 0 = exterior abajo, 1 = exterior arriba, 2 = interior abajo, 3 = interior arriba
        vs = [(rr * math.cos(2 * math.pi * k / lados), rr * math.sin(2 * math.pi * k / lados), zz)
              for rr, zz in ((r1, za), (r1, zb), (r0, za), (r0, zb)) for k in range(lados)]
        tri = []
        for k in range(lados):
            k2 = (k + 1) % lados
            ea, eb, ia, ib = (lambda j: (j, lados + j, 2 * lados + j, 3 * lados + j))(k)
            ea2, eb2, ia2, ib2 = (lambda j: (j, lados + j, 2 * lados + j, 3 * lados + j))(k2)
            tri += [(ea, ea2, eb2), (ea, eb2, eb),        # cara exterior
                    (ia, ib2, ia2), (ia, ib, ib2),        # cara interior
                    (eb, eb2, ib2), (eb, ib2, ib),        # tapa
                    (ea, ia2, ea2), (ea, ia, ia2)]        # fondo
        mesh = ('  <object id="%d" p:UUID="%s" type="model">\n   <mesh>\n    <vertices>\n' % (nid, uuid.uuid4())
                + ''.join('     <vertex x="%.5f" y="%.5f" z="%.5f"/>\n' % v for v in vs)
                + '    </vertices>\n    <triangles>\n'
                + ''.join('     <triangle v1="%d" v2="%d" v3="%d"/>\n' % t for t in tri)
                + '    </triangles>\n   </mesh>\n  </object>\n')
        open(f, 'w').write(o.replace(' </resources>', mesh + ' </resources>', 1))
        s = re.sub(r'(<object id="%s"[^>]*>\s*<components>.*?)(\s*</components>)' % oid,
                   lambda m_: m_.group(1) + '\n    <component p:path="%s" objectid="%d" p:UUID="%s" transform="%s"/>'
                   % (path, nid, uuid.uuid4(), tr) + m_.group(2), s, count=1, flags=re.S)
        t = tr.split()
        mat = ' '.join([t[0], t[3], t[6], t[9], t[1], t[4], t[7], t[10], t[2], t[5], t[8], t[11], '0', '0', '0', '1'])
        c = re.sub(r'(<object id="%s">.*?</part>)' % oid,
                   lambda m_: m_.group(1) + '\n    <part id="%d" subtype="%s">\n      <metadata key="name" '
                   'value="%s"/>\n      <metadata key="matrix" value="%s"/>\n    </part>' % (nid, tipo, tipo, mat),
                   c, count=1, flags=re.S)
    open(mod, 'w').write(s); open(cfg, 'w').write(c)


def comprobar(g, stl, parte, sop_max, cxs, seg=None, agujeros=True):
    txt = open(g, errors='ignore').read().splitlines()
    cfg = {l[2:].split(' = ')[0]: l.split(' = ', 1)[1] for l in txt if l.startswith('; ') and ' = ' in l}
    print('\n%s' % g)
    for k in ('printer_settings_id', 'print_settings_id', 'filament_settings_id', 'layer_height',
              'min_layer_height', 'wall_loops', 'enforce_support_layers', 'support_on_build_plate_only',
              'z_hop_types', 'travel_slope', 'ironing_type', 'nozzle_temperature',
              'nozzle_temperature_initial_layer', 'slowdown_for_curled_perimeters', 'overhang_flow_ratio',
              'retract_before_wipe', 'filament_deretraction_speed', 'seam_slope_conditional',
              'slow_down_for_layer_cooling'):
        print('  %-34s %s' % (k, cfg.get(k)))
    for pref in ('M190', ):
        print('  %-34s %s' % ('cama', next((l for l in txt if l.startswith(pref)), '?')))
    print('  %-34s %s' % ('tiempo', cfg.get('estimated printing time (normal mode)')))
    print('  %-34s %s' % ('filamento [g]', cfg.get('total filament used [g]')))
    objs = {l for l in txt if re.fullmatch(r'M486 S[0-9]+', l)}
    print('  %-34s %s' % ('objetos (M486)', sorted(objs)))
    z = None; t = None; zs = []; sop = []; plancha = set()
    for l in txt:
        if l.startswith(';Z:'):
            z = float(l[3:]); zs.append(z)
        elif l.startswith(';TYPE:'):
            t = l[6:]
            if t.startswith('Support'): sop.append(z)
            if t == 'Ironing': plancha.add(z)
    print('  %-34s %s' % ('soporte z', '%g–%g (tope %g)' % (min(sop), max(sop), sop_max) if sop else 'ninguno'))
    if sop and max(sop) >= sop_max:
        print('  !! el soporte pasa de z %g' % sop_max)
    print('  %-34s %s' % ('plancha en z', sorted(plancha) or 'ninguna'))
    esperas = sum(1 for l in txt if l.startswith('G4 S'))
    if esperas: print('  %-34s %d' % ('esperas entre capas', esperas))
    # planos críticos de los agujeros: plano medio de alguna capa a δ del suelo y de la cresta
    print('  %-34s %s' % ('centros', ' '.join('(%g, %g)' % c for c in cxs)))
    if parte == 'anilla' or not agujeros:
        return
    sys.path.insert(0, P); cwd = os.getcwd(); os.chdir(P)
    import arcos_agujeros as A
    if stl:
        A.STLS[parte] = stl
    todos, zmin, _ = A.crestas_parte(parte); os.chdir(cwd)
    if seg:                                          # z impreso del tramo = z modelo − Z0
        off = seg[0] - zmin
        todos = [(h, co - off, ci - off, bo - off, bi - off) for h, co, ci, bo, bi in todos
                 if seg[0] <= h['z'] - h['d'] / 2 and h['z'] + h['d'] / 2 <= seg[1]]
    zs = sorted(set(zs)); mids = [(a + b) / 2 for a, b in zip(zs, zs[1:])]
    peor = 0
    for h, co, ci, bo, bi in todos:
        d = A.delta_para_rendija(h['d'] / 2)
        for pl in (bo + d, co - d):
            peor = max(peor, min(abs(m - pl) for m in mids))
    print('  %-34s %.2f µm (%d agujeros)' % ('error máx planos críticos', peor * 1000, len(todos)))


if __name__ == '__main__':
    main()
