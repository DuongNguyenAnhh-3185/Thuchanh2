importScripts(
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBtmWDxJvbcXmo-Dqfpw0f3ElANTjXQBds',
  appId: '1:923958115750:web:eb9b6cda9e9d5d82086367',
  messagingSenderId: '923958115750',
  projectId: 'device-streaming-33cac12e',
  authDomain: 'device-streaming-33cac12e.firebaseapp.com',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(
    notification.title || 'CashewDoc',
    {
      body: notification.body || 'Bạn có cập nhật tài liệu mới.',
      icon: 'icons/Icon-192.png',
    },
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
