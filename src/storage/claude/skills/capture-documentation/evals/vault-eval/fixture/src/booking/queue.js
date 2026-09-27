export const queue = {
  items: [],
  enqueue(h) { this.items.push(h); return h; },
  remove(id) { this.items = this.items.filter((h) => h.id !== id); },
  length() { return this.items.length; },
};
