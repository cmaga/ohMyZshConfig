import sys
from intervals import merge
cases = [
    ("overlap",  lambda: merge([[1,3],[2,6],[8,10]]) == [[1,6],[8,10]]),
    ("disjoint", lambda: merge([[1,2],[5,6]]) == [[1,2],[5,6]]),
]
bad=0
for n,f in cases:
    try: ok=f()
    except Exception: ok=False
    if not ok: bad+=1; print("FAIL:",n)
print(f"{len(cases)-bad}/{len(cases)} passed"); sys.exit(1 if bad else 0)
