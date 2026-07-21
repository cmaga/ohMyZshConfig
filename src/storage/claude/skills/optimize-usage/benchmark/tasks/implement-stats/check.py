import sys
from stats import median, mode, rolling_mean
cases = [
    ("median odd",  lambda: median([3,1,2]) == 2),
    ("median even", lambda: median([1,2,3,4]) == 2.5),
    ("mode",        lambda: mode([1,2,2,3]) == 2),
    ("rolling",     lambda: rolling_mean([1,2,3,4], 2) == [1.5,2.5,3.5]),
]
bad=0
for n,f in cases:
    try: ok=f()
    except Exception: ok=False
    if not ok: bad+=1; print("FAIL:",n)
print(f"{len(cases)-bad}/{len(cases)} passed"); sys.exit(1 if bad else 0)
