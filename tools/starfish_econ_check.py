import json,itertools,functools
G=json.load(open(__import__('sys').argv[1] if len(__import__('sys').argv) > 1 else 'skilltree.json'))
N=[n['id'] for n in G['nodes']]; R={n['id']:n['requires'] for n in G['nodes']}; T={n['id']:n['tier'] for n in G['nodes']}
idx={n:i for i,n in enumerate(N)}
def check(C, gated, total=30):
    base=total-sum(gated.values())
    @functools.lru_cache(None)
    def ok(mask):
        owned=[N[i] for i in range(15) if mask>>i&1]
        coll=base+sum(gated.get(n,0) for n in owned)
        if len(owned)==15: return coll==total   # after 15/15 every star reachable
        bal=coll-sum(C[n] for n in owned)
        buy=[n for n in N if not mask>>idx[n]&1 and all(r in owned for r in R[n]) and C[n]<=bal]
        return bool(buy) and all(ok(mask|1<<idx[n]) for n in buy)
    return ok(0)
def full_before_30(C,gated):
    # tree affordable without the Tier-III-gated stars
    t3g=sum(v for n,v in gated.items() if T[n]==3)
    return sum(C.values()) <= 30 - t3g
mid={'glide.1':3,'quick.1':2,'lunge.1':1,'burst.2':2,'glide.2':2,'quick.2':1}   # Tier I/II-gated middle stars (11)
t3=[n for n in N if T[n]==3]
res=[]
for total_cost in [27,26,25]:
    for three in itertools.combinations(t3, total_cost-25):   # T1=1,T2=2,T3=2 base (25) + some T3 at 3
        C={n:{1:1,2:2,3:2}[T[n]] for n in N}
        for n in three: C[n]=3
        for fin in itertools.combinations(t3,3):   # which three T3 nodes each gate one final star
            g=dict(mid); 
            for f in fin: g[f]=g.get(f,0)+1
            if check(C,g) and full_before_30(C,g):
                res.append((total_cost,three,fin))
                break
        else:
            continue
seen=set()
for r in res:
    if r[0] not in seen: print(r); seen.add(r[0])
print("total solutions:",len(res))
# sanity: original 1/2/3 (30) with finals
C={n:{1:1,2:2,3:3}[T[n]] for n in N}; g=dict(mid); g.update({'glide.3':1,'burst.3':1,'quick.3':1})
print("1/2/3 costs (30) with 3 T3 finals:",check(C,g))
print("--- 27 with traversal finals (glide.3, burst.3, quick.3):")
fin=('glide.3','burst.3','quick.3')
for three in itertools.combinations(t3,2):
    C={n:{1:1,2:2,3:2}[T[n]] for n in N}
    for n in three: C[n]=3
    g=dict(mid); [g.__setitem__(f,g.get(f,0)+1) for f in fin]
    print(three, "OK" if check(C,g) and full_before_30(C,g) else "deadlock")
# stress: heavier mid gating at 27 (glide.3 + burst.3 at 3)
C={n:{1:1,2:2,3:2}[T[n]] for n in N}; C['glide.3']=3; C['burst.3']=3
for extra in [dict(mid), {**mid,'magnet.1':2}, {**mid,'lunge.2':2,'magnet.2':1}]:
    g=dict(extra); [g.__setitem__(f,g.get(f,0)+1) for f in fin]
    print("mid-gated",sum(extra.values()),"->", "OK" if check(C,g) else "deadlock")
