const $ = (s, root=document) => root.querySelector(s);
const $$ = (s, root=document) => [...root.querySelectorAll(s)];
const money = n => new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:0}).format(Number(n||0));
const qty = n => new Intl.NumberFormat('en-IN',{maximumFractionDigits:1}).format(Number(n||0));
const esc = s => String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const state = { dashboard:null, products:[], apartments:[] };
const titles = {dashboard:['OPERATIONS / OVERVIEW','Good inventory starts here.'],warehouse:['INVENTORY / WAREHOUSE','Warehouse stock'],apartments:['INVENTORY / LOCATIONS','Apartment inventory'],transfers:['MOVEMENTS / TRANSFERS','Move stock with confidence.'],report:['PLANNING / FORECAST','30-day requirement forecast']};

async function api(path, options={}) {
  if (location.hostname !== 'localhost' && location.hostname !== '127.0.0.1') {
    return localApi(path, options);
  }
  const res = await fetch(path,{...options,headers:{'Content-Type':'application/json',...(options.headers||{})}});
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Something went wrong');
  return data;
}
const localStore = {
  read(){return JSON.parse(localStorage.getItem('kepr-inventory-v1')||'{"products":[],"apartments":[],"stocks":[],"transfers":[]}')},
  write(data){localStorage.setItem('kepr-inventory-v1',JSON.stringify(data))}
};
function localApi(path, options={}){
  const d=localStore.read(), method=options.method||'GET', input=options.body?JSON.parse(options.body):{};
  const products=()=>d.products.map(p=>({...p,quantity:d.stocks.find(s=>s.type==='warehouse'&&s.product_id===p.id)?.quantity||0})).sort((a,b)=>a.name.localeCompare(b.name));
  const apartments=()=>d.apartments.map(a=>{const rows=d.stocks.filter(s=>s.type==='apartment'&&s.apartment_id===a.id);return {...a,item_count:rows.length,stock_value:rows.reduce((n,s)=>n+s.quantity*(d.products.find(p=>p.id===s.product_id)?.unit_price||0),0)}}).sort((a,b)=>a.name.localeCompare(b.name));
  if(path==='/api/dashboard'){const ps=products();return {stats:{product_count:ps.length,apartment_count:d.apartments.length,warehouse_value:ps.reduce((n,p)=>n+p.quantity*p.unit_price,0),low_stock_count:ps.filter(p=>p.quantity<=p.reorder_level).length},products:ps,apartments:apartments()}}
  if(path==='/api/products'&&method==='POST'){const id=Date.now();const p={id,name:input.name.trim(),unit:input.unit,unit_price:+input.unit_price||0,reorder_level:+input.reorder_level||0,notes:input.notes||''};d.products.push(p);d.stocks.push({type:'warehouse',product_id:id,quantity:+input.quantity||0});localStore.write(d);return {...p,quantity:+input.quantity||0}}
  const pm=path.match(/^\/api\/products\/(\d+)$/);if(pm&&method==='PUT'){const id=+pm[1],p=d.products.find(x=>x.id===id),s=d.stocks.find(x=>x.type==='warehouse'&&x.product_id===id);Object.assign(p,{name:input.name,unit:input.unit,unit_price:+input.unit_price,reorder_level:+input.reorder_level,notes:input.notes||''});s.quantity=+input.quantity;localStore.write(d);return {...p,quantity:s.quantity}}
  if(path==='/api/apartments'&&method==='POST'){const a={id:Date.now(),name:input.name.trim(),contact:input.contact||''};d.apartments.push(a);localStore.write(d);return a}
  if(path==='/api/apartments')return apartments();
  const sm=path.match(/^\/api\/apartments\/(\d+)\/stock$/);if(sm){const aid=+sm[1];return d.stocks.filter(s=>s.type==='apartment'&&s.apartment_id===aid).map(s=>{const p=d.products.find(x=>x.id===s.product_id);return {...s,product_name:p.name,unit:p.unit,unit_price:p.unit_price,value:s.quantity*p.unit_price}})}
  if(path==='/api/transfers'&&method==='POST'){const ref=`TR-${(input.date||'').replaceAll('-','')}-${Math.random().toString(36).slice(2,8).toUpperCase()}`;for(const line of input.lines){const pid=+line.product_id,q=+line.quantity,w=d.stocks.find(s=>s.type==='warehouse'&&s.product_id===pid);if(!w||w.quantity<q)throw new Error(`${d.products.find(p=>p.id===pid)?.name||'Product'} has only ${w?.quantity||0} available`);w.quantity-=q;let a=d.stocks.find(s=>s.type==='apartment'&&s.apartment_id===+input.apartment_id&&s.product_id===pid);if(a)a.quantity+=q;else d.stocks.push({type:'apartment',apartment_id:+input.apartment_id,product_id:pid,quantity:q,monthly_use:0});d.transfers.unshift({reference:ref,movement_date:input.date,apartment_id:+input.apartment_id,product_id:pid,quantity:q})}localStore.write(d);return {reference:ref}}
  if(path==='/api/transfers'){const groups={};for(const t of d.transfers){const g=groups[t.reference]??={reference:t.reference,movement_date:t.movement_date,apartment:d.apartments.find(a=>a.id===t.apartment_id)?.name,line_count:0,total_quantity:0,total_value:0};g.line_count++;g.total_quantity+=t.quantity;g.total_value+=t.quantity*(d.products.find(p=>p.id===t.product_id)?.unit_price||0)}return Object.values(groups)}
  if(path==='/api/report')return d.stocks.filter(s=>s.type==='apartment').map(s=>{const p=d.products.find(x=>x.id===s.product_id),a=d.apartments.find(x=>x.id===s.apartment_id),m=s.monthly_use||0,w=d.stocks.find(x=>x.type==='warehouse'&&x.product_id===s.product_id);return {product_id:p.id,product_name:p.name,unit:p.unit,unit_price:p.unit_price,apartment:a.name,quantity:s.quantity,monthly_use:m,days_remaining:m?Math.round(s.quantity/(m/30)*10)/10:null,need_15:Math.max(0,m/2-s.quantity),need_30:Math.max(0,m-s.quantity),warehouse_quantity:w?.quantity||0}})
  throw new Error('Not found');
}
function toast(message){const t=$('#toast');t.textContent=message;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),2600)}
function modal(html){$('#modalBody').innerHTML=html;$('#modal').hidden=false}
function closeModal(){ $('#modal').hidden=true }
$('#modal').addEventListener('click',e=>{if(e.target.matches('[data-close],.modal-backdrop'))closeModal()});
$('#today').textContent=new Intl.DateTimeFormat('en-IN',{day:'2-digit',month:'short',year:'numeric'}).format(new Date());
$('#menuBtn').onclick=()=>$('.sidebar').classList.toggle('open');

async function refresh(){
  state.dashboard=await api('/api/dashboard');
  state.products=state.dashboard.products;
  state.apartments=state.dashboard.apartments;
}
function tableProducts(products, compact=false){
  if(!products.length)return `<div class="empty"><b>No products yet</b>Add your first warehouse item to begin tracking stock.</div>`;
  return `<div class="table-wrap"><table><thead><tr><th>Product</th><th>Available</th><th>Unit price</th><th>Value</th><th>Status</th>${compact?'':'<th></th>'}</tr></thead><tbody>${products.map(p=>`<tr>
    <td><div class="product-cell"><span class="product-icon">${esc(p.name[0])}</span><div><strong>${esc(p.name)}</strong><small style="display:block;color:var(--muted)">${esc(p.unit)}</small></div></div></td>
    <td class="mono">${qty(p.quantity)} ${esc(p.unit)}</td><td>${money(p.unit_price)}</td><td class="mono">${money(p.quantity*p.unit_price)}</td>
    <td><span class="badge ${p.quantity<=p.reorder_level?'low':''}">${p.quantity<=p.reorder_level?'Low stock':'Healthy'}</span></td>
    ${compact?'':`<td><button class="btn small" data-edit-product="${p.id}">Edit</button></td>`}</tr>`).join('')}</tbody></table></div>`;
}
function dashboard(){
  const {stats,products,apartments}=state.dashboard;
  $('#app').innerHTML=`<div class="stats">
    <div class="stat"><span class="label">Warehouse value</span><strong>${money(stats.warehouse_value)}</strong><small>Current inventory</small></div>
    <div class="stat"><span class="label">Active products</span><strong>${stats.product_count}</strong><small>Warehouse catalogue</small></div>
    <div class="stat"><span class="label">Apartments</span><strong>${stats.apartment_count}</strong><small>Service locations</small></div>
    <div class="stat warn"><span class="label">Needs attention</span><strong>${stats.low_stock_count}</strong><small>At or below reorder level</small></div>
  </div><div class="split"><div class="panel"><div class="panel-head"><div><h2>Warehouse snapshot</h2><p>Live quantity and valuation</p></div><a class="btn small" href="#warehouse">View all</a></div>${tableProducts(products.slice(0,6),true)}</div>
  <div class="panel"><div class="panel-head"><div><h2>Apartment locations</h2><p>Stock distributed to customers</p></div></div><div class="apt-list">${apartments.length?apartments.slice(0,6).map(a=>`<div class="apt-card" data-apartment="${a.id}"><div><strong>${esc(a.name)}</strong><small>${a.item_count} products</small></div><span class="mono">${money(a.stock_value)}</span></div>`).join(''):`<div class="empty"><b>No apartments</b>Add a customer location to start transferring stock.</div>`}</div></div></div>`;
}
function productForm(p={}){
  modal(`<h2>${p.id?'Edit':'Add'} warehouse product</h2><p class="subtitle">Set the product details and current physical quantity.</p><form id="productForm" class="form-grid">
    <div class="field full"><label>Product name</label><input name="name" required value="${esc(p.name||'')}" placeholder="e.g. Floor Cleaner"></div>
    <div class="field"><label>Unit</label><select name="unit">${['Pcs','Liters','Kg','Packets','Bottles'].map(u=>`<option ${p.unit===u?'selected':''}>${u}</option>`)}</select></div>
    <div class="field"><label>Available quantity</label><input type="number" min="0" step=".1" name="quantity" required value="${p.quantity??0}"></div>
    <div class="field"><label>Unit price (₹)</label><input type="number" min="0" step=".01" name="unit_price" value="${p.unit_price??0}"></div>
    <div class="field"><label>Reorder at</label><input type="number" min="0" step=".1" name="reorder_level" value="${p.reorder_level??0}"></div>
    <div class="field full"><label>Notes</label><textarea name="notes" rows="2">${esc(p.notes||'')}</textarea></div>
    <div class="form-actions field full"><button type="button" class="btn" data-close>Cancel</button><button class="btn primary">Save product</button></div></form>`);
  $('#productForm').onsubmit=async e=>{e.preventDefault();const data=Object.fromEntries(new FormData(e.target));try{await api(`/api/products${p.id?'/'+p.id:''}`,{method:p.id?'PUT':'POST',body:JSON.stringify(data)});closeModal();toast('Product saved');await refresh();render()}catch(err){toast(err.message)}};
}
function warehouse(){
  $('#app').innerHTML=`<div class="panel"><div class="toolbar"><div><h2>All warehouse products</h2><p class="subtitle">Quantities are persisted in the inventory database.</p></div><div><input class="search" id="search" placeholder="Search products…"> <button class="btn primary" id="addProduct">+ Add product</button></div></div><div id="productTable">${tableProducts(state.products)}</div></div>`;
  $('#addProduct').onclick=()=>productForm();$('#search').oninput=e=>$('#productTable').innerHTML=tableProducts(state.products.filter(p=>p.name.toLowerCase().includes(e.target.value.toLowerCase())));
}
function apartmentForm(){
  modal(`<h2>Add apartment</h2><p class="subtitle">Create a customer location for stock allocation.</p><form id="apartmentForm" class="form-grid"><div class="field full"><label>Apartment name</label><input name="name" required placeholder="e.g. Lakeview Residency"></div><div class="field full"><label>Contact / notes</label><input name="contact" placeholder="Optional"></div><div class="form-actions field full"><button type="button" class="btn" data-close>Cancel</button><button class="btn primary">Add apartment</button></div></form>`);
  $('#apartmentForm').onsubmit=async e=>{e.preventDefault();try{await api('/api/apartments',{method:'POST',body:JSON.stringify(Object.fromEntries(new FormData(e.target)))});closeModal();toast('Apartment added');await refresh();render()}catch(err){toast(err.message)}};
}
async function apartmentDetail(id){
  const apartment=state.apartments.find(a=>a.id===Number(id)),stock=await api(`/api/apartments/${id}/stock`);
  modal(`<h2>${esc(apartment.name)}</h2><p class="subtitle">Current stock, usage, and coverage at this apartment.</p>${stock.length?`<div class="table-wrap"><table><thead><tr><th>Product</th><th>Stock</th><th>Monthly use</th><th>Coverage</th></tr></thead><tbody>${stock.map(s=>`<tr><td>${esc(s.product_name)}</td><td class="mono">${qty(s.quantity)} ${esc(s.unit)}</td><td>${qty(s.monthly_use)}</td><td>${s.monthly_use?qty(s.quantity/(s.monthly_use/30))+' days':'—'}</td></tr>`).join('')}</tbody></table></div>`:`<div class="empty"><b>No stock at this location</b>Use a transfer to allocate warehouse inventory.</div>`}`);
}
function apartments(){
  $('#app').innerHTML=`<div class="panel"><div class="toolbar"><div><h2>Customer locations</h2><p class="subtitle">Open a location to inspect its stock.</p></div><button class="btn primary" id="addApartment">+ Add apartment</button></div><div class="apt-list">${state.apartments.length?state.apartments.map(a=>`<div class="apt-card" data-apartment="${a.id}"><div><strong>${esc(a.name)}</strong><small>${esc(a.contact||'No contact details')} · ${a.item_count} products</small></div><div style="text-align:right"><strong>${money(a.stock_value)}</strong><small>stock value</small></div></div>`).join(''):`<div class="empty"><b>No apartments added</b>Add the first customer location.</div>`}</div></div>`;$('#addApartment').onclick=apartmentForm;
}
function transferForm(){
  if(!state.apartments.length||!state.products.length)return toast('Add a product and apartment first');
  modal(`<h2>New stock transfer</h2><p class="subtitle">The entire transfer commits atomically—either every line succeeds or none do.</p><form id="transferForm"><div class="form-grid"><div class="field"><label>Apartment</label><select name="apartment_id">${state.apartments.map(a=>`<option value="${a.id}">${esc(a.name)}</option>`)}</select></div><div class="field"><label>Transfer date</label><input name="date" type="date" value="${new Date().toISOString().slice(0,10)}"></div></div><div id="lines"></div><button type="button" class="btn small" id="addLine">+ Add item</button><div class="form-actions"><button type="button" class="btn" data-close>Cancel</button><button class="btn primary">Complete transfer</button></div></form>`);
  const add=()=>{$('#lines').insertAdjacentHTML('beforeend',`<div class="transfer-line"><div class="field"><select class="line-product">${state.products.map(p=>`<option value="${p.id}">${esc(p.name)} · ${qty(p.quantity)} ${esc(p.unit)} available</option>`)}</select></div><div class="field"><input class="line-qty" type="number" min=".1" step=".1" required placeholder="Qty"></div><button type="button" class="close-line btn small">×</button></div>`)};add();$('#addLine').onclick=add;$('#lines').onclick=e=>{if(e.target.matches('.close-line'))e.target.parentElement.remove()};
  $('#transferForm').onsubmit=async e=>{e.preventDefault();const fd=new FormData(e.target),lines=$$('.transfer-line').map(l=>({product_id:$('.line-product',l).value,quantity:$('.line-qty',l).value}));try{const r=await api('/api/transfers',{method:'POST',body:JSON.stringify({apartment_id:fd.get('apartment_id'),date:fd.get('date'),lines})});closeModal();toast(`Transfer ${r.reference} completed`);await refresh();render()}catch(err){toast(err.message)}};
}
async function transfers(){
  const rows=await api('/api/transfers');$('#app').innerHTML=`<div class="panel"><div class="toolbar"><div><h2>Transfer history</h2><p class="subtitle">Every stock movement has a durable audit reference.</p></div><button class="btn primary" id="newTransfer">+ New transfer</button></div>${rows.length?`<div class="table-wrap"><table><thead><tr><th>Reference</th><th>Date</th><th>Apartment</th><th>Items</th><th>Quantity</th><th>Value</th></tr></thead><tbody>${rows.map(r=>`<tr><td class="mono">${esc(r.reference)}</td><td>${esc(r.movement_date)}</td><td>${esc(r.apartment)}</td><td>${r.line_count}</td><td class="mono">${qty(r.total_quantity)}</td><td>${money(r.total_value)}</td></tr>`).join('')}</tbody></table></div>`:`<div class="empty"><b>No transfers recorded</b>Move stock from the warehouse to an apartment.</div>`}</div>`;$('#newTransfer').onclick=transferForm;
}
async function report(){
  const rows=await api('/api/report'),groups=Object.groupBy(rows,r=>r.product_name);$('#app').innerHTML=`<div class="panel"><div class="panel-head"><div><h2>Requirement forecast</h2><p>Coverage uses each apartment's monthly consumption rate.</p></div></div>${rows.length?Object.entries(groups).map(([name,items])=>{const need30=items.reduce((s,x)=>s+x.need_30,0),wh=items[0].warehouse_quantity;return `<div class="report-group"><div class="report-title"><div><h3>${esc(name)}</h3><span class="subtitle">Warehouse: ${qty(wh)} ${esc(items[0].unit)} · 30-day requirement: ${qty(need30)} ${esc(items[0].unit)}</span></div><span class="badge ${need30>wh?'low':''}">${need30>wh?`Short ${qty(need30-wh)}`:`Covered`}</span></div><div class="table-wrap"><table><thead><tr><th>Apartment</th><th>Available</th><th>Monthly use</th><th>Days left</th><th>Need 15d</th><th>Need 30d</th></tr></thead><tbody>${items.map(x=>`<tr><td>${esc(x.apartment)}</td><td>${qty(x.quantity)}</td><td>${qty(x.monthly_use)}</td><td>${x.days_remaining??'—'}</td><td>${qty(x.need_15)}</td><td>${qty(x.need_30)}</td></tr>`).join('')}</tbody></table></div></div>`}).join(''):`<div class="empty"><b>No forecast data yet</b>Transfer stock and enter monthly usage for apartment products.</div>`}</div>`;
}
async function render(){
  const page=location.hash.slice(1)||'dashboard',meta=titles[page]||titles.dashboard;$('#eyebrow').textContent=meta[0];$('#pageTitle').textContent=meta[1];$$('[data-page]').forEach(a=>a.classList.toggle('active',a.dataset.page===page));$('.sidebar').classList.remove('open');
  try{if(!state.dashboard)await refresh();({dashboard,warehouse,apartments,transfers,report}[page]||dashboard)()}catch(err){$('#app').innerHTML=`<div class="panel empty"><b>Could not load inventory</b>${esc(err.message)}</div>`}
}
document.addEventListener('click',e=>{const edit=e.target.closest('[data-edit-product]'),apt=e.target.closest('[data-apartment]');if(edit)productForm(state.products.find(p=>p.id===Number(edit.dataset.editProduct)));if(apt)apartmentDetail(apt.dataset.apartment)});
window.addEventListener('hashchange',render);render();
