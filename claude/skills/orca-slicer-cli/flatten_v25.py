import json,glob,sys,os
R=sys.argv[1]; U=os.path.expanduser('~/.dotfiles/configs/OrcaSlicer/user/default/'); out=sys.argv[2]
idx={}
for f in glob.glob(R+'/resources/profiles/*/**/*.json',recursive=True):
    try: d=json.load(open(f))
    except Exception: continue
    if isinstance(d,dict) and 'name' in d:
        idx.setdefault(d['name'],d)
        for alias in str(d.get('renamed_from','')).split(';'):
            if alias: idx.setdefault(alias,d)
def res(d,chain):
    chain.append(d.get('name'))
    if d.get('inherits'):
        if d['inherits'] not in idx: sys.exit('MISSING parent: '+d['inherits'])
        p=res(idx[d['inherits']],chain); p.update(d); return p
    return dict(d)
def go(path,typ,fn,**ov):
    d=json.load(open(U+path)); chain=[]; r=res(d,chain); r.update(ov)
    r['type']=typ; r.pop('inherits',None); r['from']='User'
    for k in ('compatible_printers','compatible_prints'): r[k]=[]
    for k in ('compatible_printers_condition','compatible_prints_condition'): r[k]=''
    json.dump(r,open(os.path.join(out,fn),'w'),indent=1); print(fn,len(r),'keys  chain:',' <- '.join(map(str,chain)))
ov=json.loads(sys.argv[3]) if len(sys.argv)>3 else {}
go('machine/core-one-obxidian.json','machine','m.json')
go('process/core-one-pla-obxidian-quality-punteiros.json','process','p.json',**ov)
go('filament/core-one-pla-polymaker-panchroma.json','filament','f.json')
