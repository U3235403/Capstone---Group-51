/* Local-only services. No fetch, cloud speech, analytics or remote endpoints. */
(() => {
  'use strict';
  const slot = 'sav.shopping.v1';
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  const random = n => crypto.getRandomValues(new Uint8Array(n));
  const b64 = buffer => {
    const data=new Uint8Array(buffer);
    let text='';
    for(let i=0;i<data.length;i+=16384) text+=String.fromCharCode(...data.subarray(i,i+16384));
    return btoa(text);
  };
  const bytes = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
  let key = null, record = null;
  const load = () => JSON.parse(localStorage.getItem(slot) || 'null');
  async function derive(password, salt) {
    const material = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveKey']);
    return crypto.subtle.deriveKey({name:'PBKDF2', salt:bytes(salt), iterations:600000, hash:'SHA-256'},
      material, {name:'AES-GCM',length:256}, false, ['encrypt','decrypt']);
  }
  async function seal(k, text) {
    const iv = random(12);
    const cipher = await crypto.subtle.encrypt({name:'AES-GCM',iv}, k, encoder.encode(text));
    return {iv:b64(iv), cipher:b64(cipher)};
  }
  async function open(k, envelope) {
    return decoder.decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes(envelope.iv)}, k, bytes(envelope.cipher)));
  }
  function commit(next) {
    // setItem is atomic: retain previous record and session on quota failure.
    localStorage.setItem(slot, JSON.stringify(next));
    record = next;
  }
  function requireCurrent() {
    if (JSON.stringify(load()) !== JSON.stringify(record))
      throw Error('Another tab changed the local vault. Discard unsaved changes and lock, then unlock to load its latest data.');
  }
  async function prfKey(output) {
    const hash = await crypto.subtle.digest('SHA-256', output);
    return crypto.subtle.importKey('raw', hash, 'AES-GCM', false, ['encrypt','decrypt']);
  }
  async function credential(action) {
    if (!window.PublicKeyCredential || !navigator.credentials) throw Error('Device unlock is not supported by this browser. Use your passphrase.');
    const challenge = random(32);
    const credential = action === 'create'
      ? await navigator.credentials.create({publicKey:{
          challenge, rp:{name:'Stage 1'},
          user:{id:random(32),name:'local-household',displayName:'Local household'},
          pubKeyCredParams:[{type:'public-key',alg:-7},{type:'public-key',alg:-257}],
          authenticatorSelection:{authenticatorAttachment:'platform',userVerification:'required',residentKey:'preferred'},
          attestation:'none', timeout:60000,
          extensions:{prf:{eval:{first:bytes(record.prfSalt)}}}
        }})
      : await navigator.credentials.get({publicKey:{
          challenge,allowCredentials:[{type:'public-key',id:bytes(record.credentialId),transports:['internal']}],
          userVerification:'required',timeout:60000,
          extensions:{prf:{eval:{first:bytes(record.prfSalt)}}}
        }});
    const result = credential.getClientExtensionResults().prf?.results?.first;
    if (!result) throw Error('This authenticator cannot unlock an encrypted offline vault. Your passphrase still works.');
    return {credential, wrappingKey:await prfKey(result)};
  }
  let recognition = null, voiceGeneration = 0;
  async function voice() {
    const generation = ++voiceGeneration;
    const Speech = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!Speech || !('processLocally' in Speech.prototype) || typeof Speech.available !== 'function')
      throw Error('Offline voice entry is unavailable in this browser. Please type the item name.');
    const status = await Speech.available({langs:['en-US'],processLocally:true});
    if (generation !== voiceGeneration) throw Error('Voice entry cancelled. You can type instead.');
    if (status !== 'available') throw Error('An on-device English speech model is not installed. No cloud recognition will be used.');
    return new Promise((resolve,reject) => {
      recognition = new Speech();
      recognition.processLocally = true;
      recognition.lang = 'en-US';
      recognition.continuous = false;
      recognition.interimResults = false;
      let settled = false;
      const finish = (value, error) => {
        if(settled) return;
        settled = true;
        clearTimeout(timer);
        recognition?.stop();
        recognition = null;
        error ? reject(Error(error)) : resolve(value);
      };
      const timer = setTimeout(() => { recognition?.abort(); finish('', 'No speech received. Try again or type the item.'); },20000);
      recognition.onresult = event => finish(event.results[0][0].transcript);
      recognition.onerror = event => finish('', 'Voice entry stopped (' + event.error + '). You can type instead.');
      recognition.onend = () => finish('', 'No speech received. You can type instead.');
      recognition.start();
    });
  }
  const execute = async (action, payload) => {
    const input = JSON.parse(payload || '{}');
    try {
      let result = {};
      if (action === 'wireframeLoad') {
        const raw = localStorage.getItem('stage1.figma.v1');
        const saved = raw ? JSON.parse(raw) : null;
        result = {data:saved?.data ?? null,revision:saved?.revision ?? 0};
      } else if (action === 'wireframeSave') {
        const raw = localStorage.getItem('stage1.figma.v1');
        const prior = raw ? JSON.parse(raw) : null;
        if ((prior?.revision ?? 0) !== input.revision)
          throw Error('This list changed in another tab. Reload to use the latest saved list.');
        const revision = input.revision + 1;
        localStorage.setItem('stage1.figma.v1',JSON.stringify({revision,data:input.data}));
        result = {revision};
      } else if (action === 'status') {
        const r = load();
        result = {exists:!!r,deviceUnlock:!!r?.deviceWrap};
      } else if (action === 'create') {
        if(load()) throw Error('A local account already exists. Unlock it instead.');
        if(input.password.length < 12) throw Error('Use a passphrase with at least 12 characters.');
        const salt = b64(random(16));
        const passwordKey = await derive(input.password, salt);
        const nextKey = await crypto.subtle.generateKey({name:'AES-GCM',length:256},true,['encrypt','decrypt']);
        const rawKey = b64(await crypto.subtle.exportKey('raw',nextKey));
        const next = {version:1,salt,passwordWrap:await seal(passwordKey,rawKey),data:await seal(nextKey,input.data)};
        commit(next); key=nextKey;
        result = {data:input.data};
      } else if (action === 'login') {
        const r=load();
        if(!r) throw Error('No local account exists yet.');
        try {
          const passwordKey=await derive(input.password,r.salt);
          const raw=await open(passwordKey,r.passwordWrap);
          const nextKey=await crypto.subtle.importKey('raw',bytes(raw),'AES-GCM',true,['encrypt','decrypt']);
          const data=await open(nextKey,r.data);
          key=nextKey; record=r; result={data};
        } catch (_) {throw Error('Could not unlock. Check your passphrase. Damaged local data also cannot be unlocked.');}
      } else if (action === 'save') {
        if(!key || !record) throw Error('Your session is locked. Unlock before saving.');
        requireCurrent();
        commit({...record,data:await seal(key,input.data)});
      } else if (action === 'lock') {
        voiceGeneration++; recognition?.abort(); key=null; record=null;
      } else if (action === 'voice') {
        result={text:await voice()};
      } else if (action === 'cancelVoice') {
        voiceGeneration++; recognition?.abort();
      } else if (action === 'enableDevice') {
        if(!key) throw Error('Unlock with your passphrase first.');
        requireCurrent();
        const prior=record;
        record={...record,prfSalt:b64(random(32))};
        try {
          const {credential: c,wrappingKey}=await credential('create');
          const wrap=await seal(wrappingKey,b64(await crypto.subtle.exportKey('raw',key)));
          commit({...record,credentialId:b64(c.rawId),deviceWrap:wrap});
        } catch(error) {record=prior;throw error;}
      } else if (action === 'deviceLogin') {
        record=load();
        if(!record?.deviceWrap) throw Error('Device unlock has not been enabled.');
        const {wrappingKey}=await credential('get');
        const raw=await open(wrappingKey,record.deviceWrap);
        const nextKey=await crypto.subtle.importKey('raw',bytes(raw),'AES-GCM',true,['encrypt','decrypt']);
        const data=await open(nextKey,record.data);
        key=nextKey;result={data};
      } else if (action === 'disableDevice') {
        if(!key) throw Error('Unlock first.');
        requireCurrent();
        const next={...record};
        delete next.deviceWrap;delete next.credentialId;delete next.prfSalt;commit(next);
      } else {throw Error('Unsupported local operation.');}
      return JSON.stringify({ok:true,...result});
    } catch(error) {
      return JSON.stringify({ok:false,error:error.message || 'The local operation could not be completed.'});
    }
  };
  window.localServices = async (action, payload) => {
    if (['status','voice','cancelVoice'].includes(action)) return execute(action,payload);
    if (!navigator.locks?.request) return JSON.stringify({ok:false,error:'This browser cannot safely coordinate local storage. Open Stage 1 in a browser with Web Locks support.'});
    // One transaction per origin, including across browser tabs. Hold the lock
    // through encryption and commit so a second writer cannot race the check.
    return navigator.locks.request('stage1-shopping-vault',()=>execute(action,payload));
  };
})();
