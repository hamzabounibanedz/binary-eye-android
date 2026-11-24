import React,{useState} from 'react';
import {euro,nav,id,test} from './platform';
const cartKey='basket-v1';
function readCart(){try{return JSON.parse(localStorage.getItem(cartKey))||{}}catch{return {}}}
function saveCart(cart){localStorage.setItem(cartKey,JSON.stringify(cart));localStorage.removeItem('checkout-request')}
export function Actions({item,setNotice}){const [qty,setQty]=useState(1);return <div className="panel"><label>Quantity<input type="number" min="1" max="20" value={qty} onChange={e=>setQty(Number(e.target.value))}/></label><button className="primary wide" {...test('add')} disabled={!Number.isInteger(qty)||qty<1||qty>20} onClick={()=>{const cart=readCart();cart[item.id]=Math.min(20,(cart[item.id]||0)+qty);saveCart(cart);nav('activity')}}>Add to basket · {euro(item.price*qty)}</button></div>}
export function Extras(){return null}
export function Records({data,mutate,busy}){
 const [cart,setCart]=useState(readCart),[address,setAddress]=useState(data.demo?'24 Market Street, demo residence':'');
 const lines=data.catalog.filter(p=>cart[p.id]>0);
 function adjust(p,n){const next={...cart,[p.id]:Math.max(0,Math.min(20,cart[p.id]+n))};setCart(next);saveCart(next)}
 function checkout(e){e.preventDefault();let requestId=localStorage.getItem('checkout-request')||id();localStorage.setItem('checkout-request',requestId);
 mutate('checkout',{requestId,address,lines:lines.map(p=>({id:p.id,qty:cart[p.id]}))},'Order received',()=>{saveCart({});setCart({})})}
 const steps=['Received','Packing','Out for delivery','Delivered'];
 return <><div className="panel"><h2>Shopping basket</h2>{lines.length?<form onSubmit={checkout}>{lines.map(p=><div className="row" key={p.id}><span>{p.title}<small className="metric">{euro(p.price)} each</small></span><div className="inline"><button type="button" className="secondary" aria-label={'Remove one '+p.title} onClick={()=>adjust(p,-1)}>−</button>{cart[p.id]}<button type="button" className="secondary" aria-label={'Add one '+p.title} disabled={cart[p.id]>=20} onClick={()=>adjust(p,1)}>+</button></div></div>)}<label>Delivery address<input required minLength={5} maxLength={160} value={address} onChange={e=>{setAddress(e.target.value);localStorage.removeItem('checkout-request')}}/></label><p>Payment on delivery</p><button className="primary" {...test('checkout')} disabled={busy}>Place order · {euro(lines.reduce((s,p)=>s+p.price*cart[p.id],0))}</button></form>:<p>Your basket is empty.</p>}</div>
 <h2>Order tracking</h2>{!data.records.length&&<p className="empty">Your orders will appear here after checkout.</p>}{data.records.map(r=><article className="record" key={r.id}><span className="small">Order {r.id.slice(0,8)}</span><h2>{euro(r.payload.total)}</h2><span className="tag">{r.status}</span><p>{r.payload.lines.map(l=>l.qty+' × '+l.title).join(', ')}</p><p>{r.payload.address}</p><ol className="track">{steps.slice(0,steps.indexOf(r.status)+1).map(s=><li key={s}>{s}</li>)}</ol>{data.admin&&r.status!=='Delivered'&&<button className="secondary" {...test('advance')} onClick={()=>mutate('advance',{id:r.id},'Order status updated')}>Admin · Mark {steps[steps.indexOf(r.status)+1].toLowerCase()}</button>}</article>)}</>
}

