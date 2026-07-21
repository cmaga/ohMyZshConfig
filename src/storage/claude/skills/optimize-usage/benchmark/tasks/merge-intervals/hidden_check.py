import sys
from intervals import merge
def nomutate():
    src=[[3,4],[1,2]]; merge(src); return src==[[3,4],[1,2]]
cases = [
    ("touching",   lambda: merge([[1,2],[2,3]]) == [[1,3]]),
    ("unsorted",   lambda: merge([[8,10],[1,3],[2,6]]) == [[1,6],[8,10]]),
    ("nested",     lambda: merge([[1,10],[2,3],[4,5]]) == [[1,10]]),
    ("single",     lambda: merge([[5,7]]) == [[5,7]]),
    ("empty",      lambda: merge([]) == []),
    ("no-mutate",  nomutate),
]
bad=0
for n,f in cases:
    try: ok=f()
    except Exception as e: ok=False; n+=f" ({type(e).__name__})"
    if not ok: bad+=1; print("HIDDEN FAIL:",n)
print(f"{len(cases)-bad}/{len(cases)} hidden passed"); sys.exit(1 if bad else 0)
