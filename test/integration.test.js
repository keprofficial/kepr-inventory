import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const dataDir = mkdtempSync(join(tmpdir(), 'kepr-inventory-'));
process.env.DATA_DIR = dataDir;
process.env.PORT = '0';
const { server } = await import('../server.js');
await new Promise(resolve => server.listening ? resolve() : server.once('listening', resolve));
const base = `http://127.0.0.1:${server.address().port}`;

async function request(path, options = {}) {
  const response = await fetch(base + path, {
    ...options,
    headers: { 'content-type': 'application/json' },
  });
  return { status: response.status, data: await response.json() };
}

test('creates stock and transfers it atomically', async () => {
  const product = await request('/api/products', {
    method: 'POST',
    body: JSON.stringify({ name: 'Floor Cleaner', unit: 'Liters', quantity: 100, unit_price: 85, reorder_level: 20 }),
  });
  assert.equal(product.status, 201);
  const apartment = await request('/api/apartments', {
    method: 'POST',
    body: JSON.stringify({ name: 'Lakeview Residency' }),
  });
  assert.equal(apartment.status, 201);
  const transfer = await request('/api/transfers', {
    method: 'POST',
    body: JSON.stringify({ apartment_id: apartment.data.id, date: '2026-07-23', lines: [{ product_id: product.data.id, quantity: 12 }] }),
  });
  assert.equal(transfer.status, 201);
  assert.match(transfer.data.reference, /^TR-/);

  const dashboard = await request('/api/dashboard');
  assert.equal(dashboard.data.products[0].quantity, 88);
  const stock = await request(`/api/apartments/${apartment.data.id}/stock`);
  assert.equal(stock.data[0].quantity, 12);

  const rejected = await request('/api/transfers', {
    method: 'POST',
    body: JSON.stringify({ apartment_id: apartment.data.id, lines: [{ product_id: product.data.id, quantity: 500 }] }),
  });
  assert.equal(rejected.status, 409);
  const unchanged = await request('/api/dashboard');
  assert.equal(unchanged.data.products[0].quantity, 88);
});

test.after(async () => {
  await new Promise(resolve => server.close(resolve));
  const { db } = await import('../db.js');
  db.close();
  rmSync(dataDir, { recursive: true, force: true });
});
