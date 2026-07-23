import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { randomUUID } from 'node:crypto';
import { db, transaction } from './db.js';

const PORT = Number(process.env.PORT || 3000);
const PUBLIC = join(process.cwd(), 'public');
const json = (res, status, body) => {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
};
const body = async req => {
  let raw = '';
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 1_000_000) throw Object.assign(new Error('Request too large'), { status: 413 });
  }
  try { return raw ? JSON.parse(raw) : {}; }
  catch { throw Object.assign(new Error('Invalid JSON'), { status: 400 }); }
};
const cleanName = value => String(value || '').trim();
const num = (value, field) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw Object.assign(new Error(`${field} must be zero or greater`), { status: 400 });
  return n;
};
const productList = () => db.prepare(`
  SELECT p.*, COALESCE(s.quantity, 0) quantity
  FROM products p LEFT JOIN stock_levels s
    ON s.product_id=p.id AND s.location_type='warehouse'
  ORDER BY p.name COLLATE NOCASE
`).all();
const apartmentList = () => db.prepare(`
  SELECT a.*, COUNT(s.product_id) item_count, COALESCE(SUM(s.quantity * p.unit_price),0) stock_value
  FROM apartments a
  LEFT JOIN stock_levels s ON s.apartment_id=a.id AND s.location_type='apartment'
  LEFT JOIN products p ON p.id=s.product_id
  GROUP BY a.id ORDER BY a.name COLLATE NOCASE
`).all();

async function api(req, res, url) {
  if (req.method === 'GET' && url.pathname === '/api/dashboard') {
    const products = productList();
    const apartments = apartmentList();
    const stats = db.prepare(`
      SELECT
        (SELECT COUNT(*) FROM products) product_count,
        (SELECT COUNT(*) FROM apartments) apartment_count,
        (SELECT COALESCE(SUM(s.quantity*p.unit_price),0) FROM stock_levels s JOIN products p ON p.id=s.product_id WHERE s.location_type='warehouse') warehouse_value,
        (SELECT COUNT(*) FROM stock_levels s JOIN products p ON p.id=s.product_id WHERE s.location_type='warehouse' AND s.quantity<=p.reorder_level) low_stock_count
    `).get();
    return json(res, 200, { stats, products, apartments });
  }
  if (req.method === 'GET' && url.pathname === '/api/products') return json(res, 200, productList());
  if (req.method === 'POST' && url.pathname === '/api/products') {
    const data = await body(req);
    const name = cleanName(data.name);
    if (!name) throw Object.assign(new Error('Product name is required'), { status: 400 });
    const unit = ['Pcs','Liters','Kg','Packets','Bottles'].includes(data.unit) ? data.unit : 'Pcs';
    const result = transaction(() => {
      const r = db.prepare('INSERT INTO products(name,unit,unit_price,reorder_level,notes) VALUES (?,?,?,?,?)')
        .run(name, unit, num(data.unit_price ?? 0, 'Unit price'), num(data.reorder_level ?? 0, 'Reorder level'), cleanName(data.notes));
      db.prepare("INSERT INTO stock_levels(location_type,apartment_id,product_id,quantity) VALUES ('warehouse',NULL,?,?)")
        .run(r.lastInsertRowid, num(data.quantity ?? 0, 'Quantity'));
      return r.lastInsertRowid;
    });
    return json(res, 201, productList().find(p => p.id === result));
  }
  const productMatch = url.pathname.match(/^\/api\/products\/(\d+)$/);
  if (productMatch && req.method === 'PUT') {
    const id = Number(productMatch[1]), data = await body(req);
    const current = db.prepare('SELECT * FROM products WHERE id=?').get(id);
    if (!current) throw Object.assign(new Error('Product not found'), { status: 404 });
    transaction(() => {
      db.prepare('UPDATE products SET name=?,unit=?,unit_price=?,reorder_level=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?')
        .run(cleanName(data.name) || current.name, data.unit || current.unit, num(data.unit_price ?? current.unit_price,'Unit price'), num(data.reorder_level ?? current.reorder_level,'Reorder level'), cleanName(data.notes ?? current.notes), id);
      if (data.quantity !== undefined) db.prepare("UPDATE stock_levels SET quantity=?,updated_at=CURRENT_TIMESTAMP WHERE location_type='warehouse' AND product_id=?")
        .run(num(data.quantity,'Quantity'), id);
    });
    return json(res, 200, productList().find(p => p.id === id));
  }
  if (productMatch && req.method === 'DELETE') {
    const id = Number(productMatch[1]);
    try { db.prepare('DELETE FROM products WHERE id=?').run(id); }
    catch { throw Object.assign(new Error('Products with stock history cannot be deleted'), { status: 409 }); }
    return json(res, 200, { ok: true });
  }
  if (req.method === 'GET' && url.pathname === '/api/apartments') return json(res, 200, apartmentList());
  if (req.method === 'POST' && url.pathname === '/api/apartments') {
    const data = await body(req), name = cleanName(data.name);
    if (!name) throw Object.assign(new Error('Apartment name is required'), { status: 400 });
    const r = db.prepare('INSERT INTO apartments(name,contact) VALUES (?,?)').run(name, cleanName(data.contact));
    return json(res, 201, db.prepare('SELECT * FROM apartments WHERE id=?').get(r.lastInsertRowid));
  }
  const apartmentStockMatch = url.pathname.match(/^\/api\/apartments\/(\d+)\/stock$/);
  if (apartmentStockMatch && req.method === 'GET') {
    return json(res, 200, db.prepare(`
      SELECT s.*,p.name product_name,p.unit,p.unit_price,(s.quantity*p.unit_price) value
      FROM stock_levels s JOIN products p ON p.id=s.product_id
      WHERE s.location_type='apartment' AND s.apartment_id=? ORDER BY p.name COLLATE NOCASE
    `).all(Number(apartmentStockMatch[1])));
  }
  if (apartmentStockMatch && req.method === 'PUT') {
    const apartmentId = Number(apartmentStockMatch[1]), data = await body(req);
    db.prepare(`
      INSERT INTO stock_levels(location_type,apartment_id,product_id,quantity,monthly_use,audited_at)
      VALUES ('apartment',?,?,?,?,?)
      ON CONFLICT(location_type,apartment_id,product_id) DO UPDATE SET
        quantity=excluded.quantity,monthly_use=excluded.monthly_use,audited_at=excluded.audited_at,updated_at=CURRENT_TIMESTAMP
    `).run(apartmentId, Number(data.product_id), num(data.quantity ?? 0,'Quantity'), num(data.monthly_use ?? 0,'Monthly use'), data.audited_at || null);
    return json(res, 200, { ok: true });
  }
  if (req.method === 'POST' && url.pathname === '/api/transfers') {
    const data = await body(req);
    const apartmentId = Number(data.apartment_id), lines = Array.isArray(data.lines) ? data.lines : [];
    if (!db.prepare('SELECT 1 FROM apartments WHERE id=?').get(apartmentId)) throw Object.assign(new Error('Choose an apartment'), { status: 400 });
    if (!lines.length) throw Object.assign(new Error('Add at least one transfer item'), { status: 400 });
    const reference = `TR-${new Date().toISOString().slice(0,10).replaceAll('-','')}-${randomUUID().slice(0,6).toUpperCase()}`;
    transaction(() => {
      for (const line of lines) {
        const productId = Number(line.product_id), quantity = num(line.quantity, 'Quantity');
        if (quantity <= 0) throw Object.assign(new Error('Transfer quantity must be greater than zero'), { status: 400 });
        const product = db.prepare(`SELECT p.*,s.quantity available FROM products p JOIN stock_levels s ON s.product_id=p.id AND s.location_type='warehouse' WHERE p.id=?`).get(productId);
        if (!product || product.available < quantity) throw Object.assign(new Error(`${product?.name || 'Product'} has only ${product?.available || 0} available`), { status: 409 });
        db.prepare("UPDATE stock_levels SET quantity=quantity-?,updated_at=CURRENT_TIMESTAMP WHERE location_type='warehouse' AND product_id=?").run(quantity, productId);
        db.prepare(`
          INSERT INTO stock_levels(location_type,apartment_id,product_id,quantity)
          VALUES ('apartment',?,?,?)
          ON CONFLICT(location_type,apartment_id,product_id) DO UPDATE SET quantity=quantity+excluded.quantity,updated_at=CURRENT_TIMESTAMP
        `).run(apartmentId, productId, quantity);
        db.prepare(`INSERT INTO stock_movements(reference,movement_type,product_id,from_location,to_location,apartment_id,quantity,unit_price,movement_date,note) VALUES (?,'transfer',?,'Warehouse','Apartment',?,?,?,?,?)`)
          .run(reference, productId, apartmentId, quantity, product.unit_price, data.date || new Date().toISOString().slice(0,10), cleanName(data.note));
      }
    });
    return json(res, 201, { reference });
  }
  if (req.method === 'GET' && url.pathname === '/api/transfers') {
    return json(res, 200, db.prepare(`
      SELECT m.reference,m.movement_date,a.name apartment,COUNT(*) line_count,SUM(m.quantity) total_quantity,SUM(m.quantity*m.unit_price) total_value
      FROM stock_movements m JOIN apartments a ON a.id=m.apartment_id WHERE m.movement_type='transfer'
      GROUP BY m.reference,m.movement_date,a.name ORDER BY m.id DESC LIMIT 100
    `).all());
  }
  if (req.method === 'GET' && url.pathname === '/api/report') {
    return json(res, 200, db.prepare(`
      SELECT p.id product_id,p.name product_name,p.unit,p.unit_price,a.name apartment,s.quantity,s.monthly_use,
        CASE WHEN s.monthly_use>0 THEN ROUND(s.quantity/(s.monthly_use/30.0),1) END days_remaining,
        MAX(0,ROUND((s.monthly_use/2.0)-s.quantity,1)) need_15,
        MAX(0,ROUND(s.monthly_use-s.quantity,1)) need_30,
        COALESCE(w.quantity,0) warehouse_quantity
      FROM stock_levels s JOIN products p ON p.id=s.product_id JOIN apartments a ON a.id=s.apartment_id
      LEFT JOIN stock_levels w ON w.product_id=p.id AND w.location_type='warehouse'
      WHERE s.location_type='apartment' ORDER BY p.name,a.name
    `).all());
  }
  return json(res, 404, { error: 'Not found' });
}

export const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    if (url.pathname.startsWith('/api/')) return await api(req, res, url);
    const requested = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    const safe = normalize(requested).replace(/^(\.\.[/\\])+/, '');
    const file = join(PUBLIC, safe);
    if (!file.startsWith(PUBLIC)) return json(res, 403, { error: 'Forbidden' });
    const types = { '.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml' };
    res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream' });
    res.end(await readFile(file));
  } catch (error) {
    if (error.code === 'ENOENT') return json(res, 404, { error: 'Not found' });
    if (String(error.message).includes('UNIQUE constraint')) error = Object.assign(new Error('That name already exists'), { status: 409 });
    console.error(error);
    json(res, error.status || 500, { error: error.status ? error.message : 'Internal server error' });
  }
});

server.listen(PORT, () => console.log(`KEPR Inventory running at http://localhost:${PORT}`));
