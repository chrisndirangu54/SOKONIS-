const CACHE_NAME = 'flutter-cache-v2'; // Updated cache version
const urlsToCache = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/manifest.json',
  // Add other assets you want to cache here
];

// Install event: Cache essential files
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(urlsToCache);
      })
      .catch((error) => {
        console.error('[Service Worker] Error during install:', error);
      })
  );
});

// Activate event: Clean up old caches
self.addEventListener('activate', (event) => {
  const cacheWhitelist = [CACHE_NAME];
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheWhitelist.indexOf(cacheName) === -1) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
    .catch((error) => {
      console.error('[Service Worker] Error during activation:', error);
    })
  );
});

// Fetch event: Serve content from cache or fetch from network with a timeout
self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetchWithTimeout(event.request, 5000) // Set timeout to 5000ms (5 seconds)
      .then((response) => {
        if (!response || response.status !== 200 || response.type !== 'basic') {
          return response; // Skip caching if response is invalid
        }
        // Cache the fetched response if it's successful
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, clone);
        });
        return response;
      })
      .catch((error) => {
        console.error('[Service Worker] Fetch failed:', error);
        // Serve from cache if fetch fails
        return caches.match(event.request)
          .then((response) => {
            if (response) {
              return response;
            }
            // Fallback to a default offline page if available
            if (event.request.mode === 'navigate') {
              return caches.match('/offline.html');
            }
            return new Response('Network error occurred, and no cache is available.', {
              status: 503,
              statusText: 'Service Unavailable'
            });
          });
      })
  );
});

// Function to fetch with timeout
function fetchWithTimeout(request, timeout) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('Fetch timeout'));
    }, timeout);

    fetch(request).then((response) => {
      clearTimeout(timer);
      resolve(response);
    }).catch((error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}
