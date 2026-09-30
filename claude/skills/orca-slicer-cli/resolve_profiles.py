import json,glob,sys,os
U=os.path.expanduser('~/.dotfiles/configs/OrcaSlicer/user/default/')
idx={}
for f in glob.glob(os.path.expanduser('~/.config/OrcaSlicer/system/*/*/*.json')):
    try: d=json.load(open(f))
    except: continue
    if 'name' in d: idx.setdefault(d['name'],d)
def res(d):
    if 'inherits' in d and d['inherits'] in idx:
        p=res(idx[d['inherits']]); p.update(d); return p
    return dict(d)
def go(path,typ,out,**ov):
    d=json.load(open(U+path)); 
    if typ!='machine': d.pop('inherits',None) if False else None
    r=res(d); r['type']=typ; r.update(ov)
    if typ=='machine': r['inherits']=d['inherits']
    else: r.pop('inherits',None)
    json.dump(r,open(out,'w'),indent=1)
go('machine/core-one-obxidian.json','machine','m.json')
go('process/core-one-pla-obxidian-quality-punteiros.json','process','p.json',compatible_printers=["Prusa CORE One 0.4 nozzle"],compatible_printers_condition="")
go('filament/core-one-pla-polymaker-panchroma.json','filament','f.json',compatible_printers=[],compatible_printers_condition="",compatible_prints=[],compatible_prints_condition="")
