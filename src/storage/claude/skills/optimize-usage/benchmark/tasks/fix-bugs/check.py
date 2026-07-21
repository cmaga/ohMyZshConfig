import sys
from mathkit import running_max, is_sorted_ascending, clamp
cases = [
    ("running_max", lambda: running_max([1,3,2,5,4]) == [1,3,3,5,5]),
    ("is_sorted",   lambda: is_sorted_ascending([1,2,2,3]) is True),
    ("clamp",       lambda: clamp(11,0,10) == 10),
]
bad = 0
for n,f in cases:
    try: ok = f()
    except Exception: ok = False
    if not ok: bad += 1; print("FAIL:", n)
print(f"{len(cases)-bad}/{len(cases)} passed"); sys.exit(1 if bad else 0)
