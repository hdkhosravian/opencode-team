import re, json, yaml, pathlib
SRC = pathlib.Path(__file__).resolve().parent.parent / 'global'
DST = pathlib.Path(__file__).resolve().parent.parent / 'global-v2'
ACTION = {'edit':'edit','bash':'shell','task':'subagent','skill':'skill','webfetch':'webfetch','read':'read','external_directory':'external_directory'}
MODEL = {
 'developer-strong':'anthropic/claude-sonnet-5-5',
 'lead':'anthropic/claude-opus-5-5#high',
 'tech-lead':'anthropic/claude-sonnet-5-5',
 'reviewer':'anthropic/claude-sonnet-5-5',
 'developer':'google/gemini-3.8-flash#high',
}
def both(r):
    # cover relative and absolute path forms
    if r.startswith(('*','/','~')): return [r]
    return [r, '*/'+r]
def shell_res(r):
    # V2: a pattern ending in " *" matches the command with or without arguments
    if r.endswith('*') and not r.startswith('*') and len(r)>1 and not r[-2].isspace() and r[-2] not in '*/':
        return [r[:-1], r[:-1]+' *']
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
for f in sorted((SRC/'agents').glob('*.md')):
    fm,body=split(f.read_text())
    name=f.stem
    new={'description':fm['description'],'mode':fm['mode'],'model':MODEL[name],'steps':fm['steps'],
         'permissions':convert_perm(fm['permission'])}
    (DST/'agents'/f.name).write_text(dump(new,body))
for f in sorted((SRC/'commands').glob('*.md')):
    fm,body=split(f.read_text())
    new={'description':fm['description'],'agent':fm['agent']}
    if fm.get('subtask'): new['subagent']=True
    (DST/'commands'/f.name).write_text(dump(new,body))
cfg=json.loads((SRC/'opencode.json').read_text())
perms=convert_perm(cfg['permission'])
G='google/gemini-3.8-flash'
v2={
 "$schema":"https://opencode.ai/config.json",
 "model":"anthropic/claude-sonnet-5-5",
 "default_agent":"tech-lead",
 "update":"notify",
 "share":"disabled",
 "compaction":{"auto":True},
 "tool_output":{"max_lines":600,"max_bytes":24576},
 "formatter":True,
 "experimental":{"subagent_depth":2},
 "agents":{
   "explore":{"model":G},"general":{"model":G},"title":{"model":G},"compaction":{"model":G},
   "build":{"disabled":True},"plan":{"disabled":True}},
 "permissions":perms,
}
(DST/'opencode.json').write_text(json.dumps(v2,indent=2)+'\n')
print('global-v2 regenerated from global')
