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
