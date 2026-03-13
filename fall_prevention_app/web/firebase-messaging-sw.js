importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCOycRDkQOjOlUMkaZYC11kpsffkMcWoes',
  authDomain: 'fall-prevention-sys-26.firebaseapp.com',
  projectId: 'fall-prevention-sys-26',
  storageBucket: 'fall-prevention-sys-26.firebasestorage.app',
  messagingSenderId: '434300558465',
  appId: '1:434300558465:web:b059e352ef7dd5e9040180'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = (payload.notification && payload.notification.title) || 'Fall Risk Alert';
  const options = {
    body: (payload.notification && payload.notification.body) || 'High fall risk detected.',
    icon: 'icons/Icon-192.png'
  };

  self.registration.showNotification(title, options);
});
