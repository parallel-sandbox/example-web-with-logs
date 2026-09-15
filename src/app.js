const status = document.getElementById('status');
const cfg = window.PSBX_LOG;

document.getElementById('project').textContent = cfg.project;
document.getElementById('endpoint').textContent = cfg.endpoint;
document.getElementById('release').textContent = cfg.release;

function chargeCard(order) {
  throw new Error(`card declined for order ${order.id} (amount ${order.amount})`);
}

function prepareOrder(id) {
  const order = { id, amount: 42, currency: 'USD' };
  return chargeCard(order);
}

function handleCheckout() {
  prepareOrder(`ord_${Date.now().toString(36)}`);
}

window.addEventListener('error', (event) => {
  status.dataset.state = 'thrown';
  status.textContent = `Thrown at ${new Date().toISOString()}\n${event.error?.stack || event.message}`;
});

document.getElementById('crash').addEventListener('click', handleCheckout);
