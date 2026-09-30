import json,itertools,functools,sys
G=json.load(open(sys.argv[1] if len(sys.argv) > 1 else 'skilltree.json'))
N=[n['id'] for n in G['nodes']]; C={n['id']:n['cost'] for n in G['nodes']}; R={n['id']:n['requires'] for n in G['nodes']}
idx={n:i for i,n in enumerate(N)}
def check(total, gated):
    # gated: dict node -> number of starfish requiring that node (star needs node owned); rest baseline
    base=total-sum(gated.values())
    @functools.lru_cache(None)
    def ok(mask):
        owned=[N[i] for i in range(15) if mask>>i&1]
        if len(owned)==15: return True
        coll=base+sum(gated.get(n,0) for n in owned)
        spent=sum(C[n] for n in owned)
        bal=coll-spent
        buy=[n for n in N if not mask>>idx[n]&1 and all(r in owned for r in R[n]) and C[n]<=bal]
        if not buy: return False
        return all(ok(mask|1<<idx[n]) for n in buy)   # EVERY legal choice must stay winnable
    return ok(0)
tier={n['id']:n['tier'] for n in G['nodes']}
t3=[n for n in N if tier[n]==3]; t2=[n for n in N if tier[n]==2]; t1=[n for n in N if tier[n]==1]
print("30 total, 1 star behind glide.3:", check(30,{'glide.3':1}))
print("30 total, 3 behind glide.1, 3 behind quick.1, 2 behind burst.2, 2 behind glide.2:", check(30,{'glide.1':3,'quick.1':3,'burst.2':2,'glide.2':2}))
for total in range(30,37):
    best=None
    for per in range(1,4):
        g={n:per for n in ['glide.3','burst.3','quick.3']}
        g.update({'glide.1':3,'quick.1':3,'burst.2':2,'glide.2':2})
        if check(total,g): best=per
    print(total,"stars: with 3 T3 nodes each gating",best,"stars (plus T1/T2 gating) ->", "OK" if best else "deadlock possible")
