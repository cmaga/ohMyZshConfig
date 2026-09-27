// Seat holds. Renamed from the TTL-era helper in the queue rework.
export function holdSeat(seatId, userId) {
  return queue.enqueue({ seatId, userId, position: queue.length() + 1 });
}
export function releaseHold(holdId) {
  return queue.remove(holdId);
}
