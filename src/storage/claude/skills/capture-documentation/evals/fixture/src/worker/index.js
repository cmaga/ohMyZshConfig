// Minimal queue worker used only as a resolution target for vault surface entries.

function claimNextJob(queue) {
  return queue.shift();
}

function processQueueItem(item, ctx) {
  if (!item) return null;
  ctx.log('processing', item.id);
  return { ok: true, id: item.id };
}

module.exports = { claimNextJob, processQueueItem };
