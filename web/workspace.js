import {$,download,message} from './ui.js';
const canvas=$('#code'),context=canvas.getContext('2d');
qrcode.stringToBytes=qrcode.stringToBytesFuncs['UTF-8'] || (str=>Array.from(new TextEncoder().encode(str)));
function render(){
 const input=$('#payload').value;context.fillStyle='#fff';context.fillRect(0,0,canvas.width,canvas.height);
 if(!input){$('#matrix').textContent='';return false;}
 try{
  const qr=qrcode(0,$('#level').value);qr.addData(input,'Byte');qr.make();
  const n=qr.getModuleCount(),step=Math.floor(700/(n+8));canvas.width=canvas.height=step*(n+8);
  context.fillStyle='#fff';context.fillRect(0,0,canvas.width,canvas.height);context.fillStyle='#102d22';
  for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(qr.isDark(y,x))context.fillRect((x+4)*step,(y+4)*step,step,step);
  $('#matrix').textContent=n+' × '+n;return true;
 }catch{$('#matrix').textContent='Capacity exceeded';return false}
}
$('#payload').oninput=render;$('#level').onchange=render;
$('#create').onsubmit=e=>{e.preventDefault();if(render())download(canvas,'signalpress-qr.png');else message('Shorten the content or lower error correction.')};
for(const mode of ['make','scan'])$('#'+mode).onclick=()=>{const make=mode==='make';$('#create').hidden=!make;$('#reader').hidden=make;$('#make').setAttribute('aria-pressed',make);$('#scan').setAttribute('aria-pressed',!make)};
$('#file').onchange=async e=>{
 const file=e.target.files[0];if(!file)return;$('#result').value='';
 try{const image=await createImageBitmap(file);const scale=Math.min(1,1600/Math.max(image.width,image.height));const c=document.createElement('canvas');c.width=Math.max(1,image.width*scale);c.height=Math.max(1,image.height*scale);const ctx=c.getContext('2d',{willReadFrequently:true});ctx.drawImage(image,0,0,c.width,c.height);image.close();const data=ctx.getImageData(0,0,c.width,c.height);const code=jsQR(data.data,c.width,c.height);if(!code)throw Error('No QR code found in that image.');$('#result').value=code.data;message('QR code decoded.');}catch(err){message(err.message||'Unable to read this image.')}
};render();

