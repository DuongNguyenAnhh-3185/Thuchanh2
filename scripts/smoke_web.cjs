const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const {spawn}=require('node:child_process');
const root=path.resolve('build/web');
const out=path.resolve('build/web-verification');
fs.mkdirSync(out,{recursive:true});
const server=http.createServer((req,res)=>{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const target=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!target.startsWith(root+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(target,(error,data)=>{
    if(error){res.writeHead(404).end();return;}
    const types={'.wasm':'application/wasm','.js':'application/javascript','.html':'text/html','.json':'application/json'};
    res.setHeader('Content-Type',types[path.extname(target)]||'application/octet-stream');res.end(data);
  });
});
let browser,ws;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const url='http://127.0.0.1:'+server.address().port;
 browser=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',[
  '--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check',
  '--remote-debugging-port=9443','--remote-debugging-address=127.0.0.1',
  '--user-data-dir='+path.join(out,'chrome-profile'),'--window-size=1440,900','about:blank'
 ],{windowsHide:true,stdio:'ignore'});
 let page;
 for(let i=0;i<40;i++){
  try{const pages=await(await fetch('http://127.0.0.1:9443/json')).json();page=pages.find(p=>p.type==='page');if(page)break;}catch{}
  await sleep(250);
 }
 if(!page)throw Error('Chrome debugging target did not start');
 ws=new WebSocket(page.webSocketDebuggerUrl);
 await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
 let id=0;const pending=new Map();const errors=[];
 ws.addEventListener('message',event=>{
  const message=JSON.parse(event.data);
  if(message.id){const p=pending.get(message.id);pending.delete(message.id);message.error?p.reject(message.error):p.resolve(message.result);}
  if(message.method==='Runtime.exceptionThrown')errors.push(JSON.stringify(message.params.exceptionDetails));
 });
 const call=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject});ws.send(JSON.stringify({id:key,method,params}));});
 await call('Runtime.enable');await call('Page.enable');
 await call('Page.navigate',{url});
 await sleep(12000);
 await call('Runtime.evaluate',{expression:"document.querySelector('flt-semantics-placeholder')?.click()"});
 await sleep(1500);
 const dom=await call('Runtime.evaluate',{expression:'document.body.innerText',returnByValue:true});
 fs.writeFileSync(path.join(out,'visible-text.txt'),dom.result.value||'');
 const shot=await call('Page.captureScreenshot',{format:'png'});
 fs.writeFileSync(path.join(out,'desktop.png'),Buffer.from(shot.data,'base64'));
 await call('Emulation.setDeviceMetricsOverride',{width:360,height:800,deviceScaleFactor:1,mobile:true});
 await sleep(2000);
 const mobile=await call('Page.captureScreenshot',{format:'png'});
 fs.writeFileSync(path.join(out,'mobile.png'),Buffer.from(mobile.data,'base64'));
 if(errors.length)throw Error(errors.join('\n'));
 if(!(dom.result.value||'').includes('CashewDoc'))throw Error('Home screen text not found; inspect screenshots');
 console.log('PASS: release Web starts in Chrome, renders CashewDoc and has no uncaught runtime errors.');
 console.log('Screenshots: build/web-verification/desktop.png and mobile.png');
 await call('Browser.close');
})().catch(error=>{console.error(error.message);process.exitCode=1;}).finally(()=>{
 ws?.close();browser?.kill();server.close();
});
