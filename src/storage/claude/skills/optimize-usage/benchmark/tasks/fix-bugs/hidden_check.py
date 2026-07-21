import sys
from mathkit import running_max, is_sorted_ascending, clamp
cases = [
    ("running_max asc",   lambda: running_max([1,2,3]) == [1,2,3]),
    ("running_max desc",  lambda: running_max([3,2,1]) == [3,3,3]),
    ("running_max dup",   lambda: running_max([5,1,1,9]) == [5,5,5,9]),
    ("running_max neg",   lambda: running_max([-2,-5,-1]) == [-2,-2,-1]),
    ("is_sorted eq",      lambda: is_sorted_ascending([2,2,2]) is True),
    ("is_sorted false",   lambda: is_sorted_ascending([1,3,2]) is False),
    ("clamp hi",          lambda: clamp(11,0,10) == 10),
    ("clamp lo",          lambda: clamp(-1,0,10) == 0),
    ("clamp mid",         lambda: clamp(5,0,10) == 5),
]
bad = 0
for n,f in cases:
    try: ok = f()
    except Exception as e: ok = False; n += f" ({type(e).__name__})"
    if not ok: bad += 1; print("HIDDEN FAIL:", n)
print(f"{len(cases)-bad}/{len(cases)} hidden passed"); sys.exit(1 if bad else 0)
