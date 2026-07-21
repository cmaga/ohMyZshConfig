import sys
from stats import median, mode, rolling_mean
def raises(fn):
    try: fn(); return False
    except ValueError: return True
    except Exception: return False
cases = [
    ("median single",   lambda: median([5]) == 5),
    ("median even avg", lambda: median([1,2]) == 1.5),
    ("median empty",    lambda: raises(lambda: median([]))),
    ("mode tie->min",   lambda: mode([3,3,1,1]) == 1),
    ("mode empty",      lambda: raises(lambda: mode([]))),
    ("rolling k>len",   lambda: rolling_mean([1,2], 5) == []),
    ("rolling k=len",   lambda: rolling_mean([2,4], 2) == [3.0]),
    ("rolling k<=0",    lambda: raises(lambda: rolling_mean([1,2,3], 0))),
]
bad=0
for n,f in cases:
    try: ok=f()
    except Exception as e: ok=False; n+=f" ({type(e).__name__})"
    if not ok: bad+=1; print("HIDDEN FAIL:",n)
print(f"{len(cases)-bad}/{len(cases)} hidden passed"); sys.exit(1 if bad else 0)
