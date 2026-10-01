"""Regenerate the model settings in global/ (V1) and the whole of global-v2/ (V2) from models.conf
and global/. Needs pyyaml. Usage: python3 tools/gen_v2.py   (--help for this text)"""
import importlib.util, json, pathlib, re, sys, yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC, DST = ROOT / 'global', ROOT / 'global-v2'
spec = importlib.util.spec_from_file_location('models', SRC / 'team' / 'models.py')
models = importlib.util.module_from_spec(spec); spec.loader.exec_module(models)

ACTION = {'edit':'edit','bash':'shell','task':'subagent','skill':'skill','webfetch':'webfetch','read':'read','external_directory':'external_directory'}
# V2 matches "cmd *" only with arguments, so a V1 "cmd*" becomes two rules. These also get a "cmd:*" rule (npm run test:unit).
COLON_VARIANTS = {'npm run test', 'npm run lint', 'npm run typecheck'}

def both(r):
    # cover relative and absolute path forms
    if r.startswith(('*','/','~')): return [r]
    return [r, '*/'+r]
def shell_res(r):
    # V2: a pattern ending in " *" matches the command with or without arguments
    if r.endswith('*') and not r.startswith('*') and len(r)>1 and not r[-2].isspace() and r[-2] not in '*/':
        out = [r[:-1], r[:-1]+' *']
        if r[:-1] in COLON_VARIANTS: out.append(r[:-1]+':*')
        return out
    return [r]
def convert_perm(p):
    out=[]
    for k,v in p.items():
        act=ACTION[k]
        if isinstance(v,str):
            out.append({'action':act,'resource':'*','effect':v}); continue
        for res,eff in v.items():
            if act=='shell': rs=shell_res(res)
            elif act in ('edit','read'): rs=both(res)
            else: rs=[res]
            for r in rs: out.append({'action':act,'resource':r,'effect':eff})
    return out
def dump(fm, body):
    y=yaml.safe_dump(fm, sort_keys=False, allow_unicode=True, width=100000, default_flow_style=False)
    return '---\n'+y+'---\n'+body
def split(text):
    m=re.match(r'^---\n(.*?)\n---\n(.*)$', text, re.S)
    return yaml.safe_load(m.group(1)), m.group(2)

def main():
    conf = models.load_conf(ROOT / 'models.conf')
    models.apply_dir(str(SRC), conf)  # V1: model, small_model and agent models in global/opencode.json
    for f in sorted((SRC/'agents').glob('*.md')):
        fm,body=split(f.read_text())
        new={'description':fm['description'],'mode':fm['mode'],'model':models.agent_value(conf, f.stem),'steps':fm['steps'],
             'permissions':convert_perm(fm['permission'])}
        (DST/'agents'/f.name).write_text(dump(new,body))
    for f in sorted((SRC/'commands').glob('*.md')):
        fm,body=split(f.read_text())
        new={'description':fm['description'],'agent':fm['agent']}
        if fm.get('subtask'): new['subagent']=True
        (DST/'commands'/f.name).write_text(dump(new,body))
    cfg=json.loads((SRC/'opencode.json').read_text())
    bg=conf['BACKGROUND']
    v2={
     "$schema":"https://opencode.ai/config.json",
     "model":conf['TECH_LEAD'],
     "default_agent":cfg['default_agent'],
     "update":"notify",
     "share":"disabled",
     "compaction":{"auto":True},
     "tool_output":{"max_lines":600,"max_bytes":24576},
     "formatter":True,
     "experimental":{"subagent_depth":cfg['subagent_depth']},
     "agents":{**{n:{"model":bg} for n in models.V2_JSON_AGENTS}, "build":{"disabled":True},"plan":{"disabled":True}},
     "permissions":convert_perm(cfg['permission']),
    }
    (DST/'opencode.json').write_text(json.dumps(v2,indent=2)+'\n')
    print('global/ models and global-v2/ regenerated from models.conf and global/')

if __name__ == '__main__':
    if '-h' in sys.argv or '--help' in sys.argv:
        print(__doc__)
    else:
        main()
