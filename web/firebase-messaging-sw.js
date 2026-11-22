// Service worker FCM — proyecto foody-pin2 (app cliente web).
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAGoBuKPfWDAjMgd0m_AQXWHlm--q9hXP0',
  appId: '1:518497313333:web:3fb376e3669b8a8766877c',
  messagingSenderId: '518497313333',
  projectId: 'foody-pin2',
  authDomain: 'foody-pin2.firebaseapp.com',
  storageBucket: 'foody-pin2.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title || 'Foody';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  return self.registration.showNotification(title, options);
});

function resolverUrlDesdeData(data) {
  if (data.ruta) {
    return data.ruta.startsWith('http') ? data.ruta : self.location.origin + data.ruta;
  }
  const tipo = data.tipo || '';
  if (data.pedido_id) {
    if (tipo.includes('cliente') || tipo.includes('seguimiento') || tipo === 'pedido_cliente') {
      return self.location.origin + '/pedidos/' + data.pedido_id + '/seguimiento';
    }
    return self.location.origin + '/admin/panel?tab=pedidos&pedido=' + data.pedido_id;
  }
  if (tipo.includes('cocina') || tipo.includes('kds')) {
    return self.location.origin + '/admin/cocina';
  }
  if (tipo.includes('mesero') || tipo.includes('qr_pendiente')) {
    return self.location.origin + '/admin/mesero';
  }
  if (tipo.includes('domiciliario') || tipo.includes('oferta')) {
    return self.location.origin + '/domiciliario/independiente';
  }
  return self.location.origin + '/';
}

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const data = event.notification.data || {};
  const url = resolverUrlDesdeData(data);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        client.postMessage({ type: 'FCM_NOTIFICATION_CLICK', data: data });
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
