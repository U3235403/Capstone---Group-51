(() => {
  'use strict';
  let deferred, registration;
  const standalone = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const mobile = ios || /Android/.test(navigator.userAgent);
  const panel = document.getElementById('install-panel');
  const title = document.getElementById('install-title');
  const message = document.getElementById('install-message');
  const action = document.getElementById('install-action');
  const close = document.getElementById('install-close');
  // Keep Flutter's document-level pointer handlers from consuming native dialog taps.
  for (const type of ['pointerdown', 'pointerup', 'pointermove', 'pointercancel', 'touchstart', 'touchend']) {
    window.addEventListener(type, event => {
      if (panel.contains(event.target)) event.stopImmediatePropagation();
    }, {capture:true, passive:true});
  }
  let mode = 'install', previousFocus;
  const readDismissed = () => { try { return Number(localStorage.getItem('stage1.install.dismissed')) || 0; } catch { return 0; } };
  function hide() { panel.close(); panel.hidden = true; previousFocus?.focus?.(); }
  function show(update = false) {
    if (!update && standalone()) return;
    mode = update ? 'update' : 'install';
    previousFocus = document.activeElement;
    title.textContent = update ? 'An update is ready' : 'Add Stage 1 to your home screen';
    message.textContent = update ? 'Finish your current changes, then reopen the updated app. Your saved list stays on this device.' : ios ? 'In Safari, tap Share, then Add to Home Screen. Keep Open as Web App on if shown, then tap Add.' : deferred ? 'Install Stage 1 to open it from your home screen. Your list is stored on this device.' : 'Open your browser menu and choose Install app or Add to Home screen if available. You can also keep using this link.';
    action.hidden = !update && !deferred;
    action.textContent = update ? 'Update and reload' : 'Install app';
    close.textContent = update ? 'Later' : 'Not now';
    panel.hidden = false;
    if (!panel.open) panel.showModal();
  }
  close.addEventListener('click', () => {
    if (mode === 'install') { try { localStorage.setItem('stage1.install.dismissed', String(Date.now())); } catch {} }
    hide();
  });
  panel.addEventListener('keydown', event => { if (event.key === 'Escape') hide(); });
  action.addEventListener('click', async () => {
    if (mode === 'update') {
      if (registration?.waiting) {
        navigator.serviceWorker.addEventListener('controllerchange', () => location.reload(), {once:true});
        registration.waiting.postMessage({type:'ACTIVATE_UPDATE'});
        action.disabled = true;
      } else {
        location.reload();
      }
      return;
    }
    if (!deferred) return;
    const prompt = deferred; deferred = null;
    await prompt.prompt();
    await prompt.userChoice;
    hide();
  });
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault(); deferred = event;
    if (!standalone() && Date.now() - readDismissed() > 7 * 86400000) show();
  });
  window.addEventListener('appinstalled', () => { deferred = null; hide(); });
  window.addEventListener('stage1-ready', () => {
    document.getElementById('loading').hidden = true;
    if (new URL(location.href).searchParams.has('install') || (mobile && Date.now() - readDismissed() > 7 * 86400000)) show();
  });
  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register('sw.js', {updateViaCache:'none'}).then(reg => {
      registration = reg;
      if (reg.waiting) show(true);
      reg.addEventListener('updatefound', () => {
        const worker = reg.installing;
        worker?.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) show(true);
        });
      });
    }).catch(() => {
      document.getElementById('offline-status').textContent = 'Offline setup failed. Keep this page connected and reopen it to try again.';
    });
    navigator.serviceWorker.ready.then(() => {
      document.getElementById('offline-status').textContent = 'Ready to open offline on this device.';
    });
  } else {
    document.getElementById('offline-status').textContent = 'Installation and offline loading require HTTPS or localhost.';
  }
})();
