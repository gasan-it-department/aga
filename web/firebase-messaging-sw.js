importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDbtxsf5VEBGcTj789fW8-FH0A_CTDWO-8',
  authDomain: 'aga-mobile.firebaseapp.com',
  projectId: 'aga-mobile',
  storageBucket: 'aga-mobile.firebasestorage.app',
  messagingSenderId: '235079847465',
  appId: '1:235079847465:web:8192d90601703c1554d638',
  measurementId: 'G-TCL1CDW3L0',
});

const notificationLogo = '/aga_gasan_app_logo_rounded.png';
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  self.registration.showNotification(notification.title || data.title || 'AGA', {
    body: notification.body || data.body || 'You have a new notification.',
    icon: notification.icon || notificationLogo,
    image: notification.image || notificationLogo,
    tag: data.message_id || data.order_id || ('aga-' + Date.now() + '-' + Math.random()),
    renotify: true,
    data,
  });
});
