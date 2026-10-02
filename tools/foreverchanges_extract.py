import re,json,os
def rsc(path):
    h=open(path,encoding="utf-8").read()
    chunks=re.findall(r'self\.__next_f\.push\(\[1,"(.*?)"\]\)',h,re.S)
    b="".join(json.loads('"'+c+'"') for c in chunks)
    objs={}
    for line in b.split("\n"):
        m=re.match(r'^([0-9a-f]+):(.*)$',line)
        if m:
            try: objs[m.group(1)]=json.loads(m.group(2))
            except: pass
    return objs
def find(o,key,kind):
    if isinstance(o,dict):
        if isinstance(o.get(key),kind): return o
        for v in o.values():
            r=find(v,key,kind)
            if r is not None: return r
    elif isinstance(o,list):
        for v in o:
            r=find(v,key,kind)
            if r is not None: return r
slugs=open("slugs.txt").read().split()
catalog={d["id"]:d for d in find(rsc("the-deadmines.html"),"dungeons",list)["dungeons"]}
out=[]
for s in slugs:
    o=rsc(s+".html")
    main=find(o,"bosses",list) or {}
    while main and not (main["bosses"] and isinstance(main["bosses"][0],dict) and "english" in main["bosses"][0]):
        main=None
    if main is None:
        def boss_block(x):
            if isinstance(x,dict):
                b=x.get("bosses")
                if isinstance(b,list) and b and isinstance(b[0],dict) and "english" in b[0]: return x
                for v in x.values():
                    r=boss_block(v)
                    if r: return r
            elif isinstance(x,list):
                for v in x:
                    r=boss_block(v)
                    if r: return r
        main=boss_block(o) or {}
    mp=main.get("map") or {}
    qs=(find(o,"quests",list) or {}).get("quests",[])
    d={"slug":s,"name":catalog.get(s,{}).get("name"),"levels":catalog.get(s,{}).get("levels"),"new":catalog.get(s,{}).get("fresh"),
       "floors":[{"name":f.get("name"),"image":f.get("src"),"pins":[{k:p.get(k) for k in ("x","y","boss","face","faceKind","label")} for p in f.get("pins",[])]} for f in mp.get("floors",[])],
       "bosses":[{"english":b.get("english"),"name":b.get("name"),"kind":b.get("kind"),"level":b.get("level"),"display":b.get("display"),
                  "items":[{"id":i.get("i"),"english":i.get("ne"),"name":i.get("n"),"quality":i.get("q"),"chance":i.get("z"),"status":i.get("t")} for i in b.get("items",[])]} for b in main.get("bosses",[])],
       "fights":(lambda f: f if isinstance(f,dict) else {})(o.get(main["fights"][1:]) if isinstance(main.get("fights"),str) and main["fights"][1:] in o else main.get("fights")),
       "quests":[{k:q.get(k) for k in ("id","title","level","min","side","forever","giver","starts","text")}|{"need":[n.get("i") for n in q.get("need",[])],"rewards":[c.get("i") for c in (q.get("choice") or [])+(q.get("given") or [])]} for q in qs]}
    out.append(d)
    print(s, d["levels"], "etages",len(d["floors"]),"boss",len(d["bosses"]),"objets",sum(len(b["items"]) for b in d["bosses"]),"combats",len(d["fights"]),"quetes",len(d["quests"]))
json.dump(out,open("foreverchanges.json","w",encoding="utf-8"),ensure_ascii=False,indent=1)
# Textes seuls (combats et noms de boss), pour tools/texts/<langue>.json quand les pages sont dans une autre langue.
texts={d["slug"]:{"bosses":{b["english"]:b["name"] for b in d["bosses"]},
                  "fights":{k:{"trigger":f.get("trigger"),"abilities":[{"name":a["name"],"text":a.get("text") or ""} for a in f.get("abilities",[])]} for k,f in d["fights"].items()}} for d in out}
json.dump(texts,open("texts.json","w",encoding="utf-8",newline="\n"),ensure_ascii=False,indent=1)
print(os.path.getsize("foreverchanges.json"))
