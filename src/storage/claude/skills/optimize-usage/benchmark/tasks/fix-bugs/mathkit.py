def running_max(nums):
    """Return a list where element i is the max of nums[0..i]."""
    out = []
    best = None
    for n in nums:
        if best is None or n < best:   # BUG: should be n > best
            best = n
        out.append(best)
    return out


def is_sorted_ascending(nums):
    """True if nums is in non-decreasing order."""
    for i in range(1, len(nums)):
        if nums[i - 1] > nums[i]:
            return False
    return True


def clamp(x, lo, hi):
    """Clamp x into [lo, hi]."""
    if x < lo:
        return lo
    if x > hi:
        return lo                       # BUG: should return hi
    return x
