// Configuración pública de la aplicación web SearchTeach en Firebase.
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBxvN47o6LZuxpB1k4j_fiARRQ6ZklRK4c',
  authDomain: 'searchteach-6b0dc.firebaseapp.com',
  projectId: 'searchteach-6b0dc',
  storageBucket: 'searchteach-6b0dc.firebasestorage.app',
  messagingSenderId: '405794789070',
  appId: '1:405794789070:web:46c2c75cae34410669229f',
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'SearchTeach';
  const options = {
    body: payload.notification?.body || 'Tienes un aviso nuevo.',
    icon: 'icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/notificaciones'));
});
