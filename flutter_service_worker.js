'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"manifest.json": "61354f8d4d578b1d28b6b4f18cc85b24",
"main.dart.js": "d567d497c8b1ac45afeb9cbb3123ec99",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"index.html": "5b1760d310852718bbddde7bc256d77e",
"/": "5b1760d310852718bbddde7bc256d77e",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/AssetManifest.bin.json": "170c1244939cea5dafa464a627f5a519",
"assets/AssetManifest.bin": "c6f129b4275dd4c403744e27ac036c3c",
"assets/NOTICES": "4a1c87ddb3c21a2804eb25c8fb7f81b9",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/assets/images/equipment/t-line/T-mop.PNG": "f4c3bc87780b1356d4b3ed49693f1304",
"assets/assets/images/equipment/t-line/T-line.PNG": "8aa2b872b0018a63db31ef0d821b8f6e",
"assets/assets/images/equipment/t-line/TLO-1500.PNG": "4491b52fe015ffaba5f8339092df7232",
"assets/assets/images/equipment/ipc/CT70%2520B%25D0%25A255.PNG": "c7a7ae91c80950defa73a4d52721c44b",
"assets/assets/images/equipment/ipc/CT30.PNG": "9852d2dde80c32f59969cf4670851dd9",
"assets/assets/images/equipment/ipc/CT45%2520B50.PNG": "b312d12bd96176d5534ecfef047881f1",
"assets/assets/images/equipment/ipc/CT51%2520B%25D0%25A255.PNG": "63e200072e3b30d27481cff939ffbcbc",
"assets/assets/images/equipment/gadlee/GTS%25201200.PNG": "7b427ec9650120f643101ff113608974",
"assets/assets/images/equipment/gadlee/GT55.PNG": "b33d8dcd688e6509e68597a3e4c38856",
"assets/assets/images/equipment/gadlee/GT70.PNG": "44cde9170cdc1a65242aaad7308f82ea",
"assets/assets/images/equipment/gadlee/GT50.PNG": "eec62c1f1d7ac4f8e72b78ef92bd21d4",
"assets/assets/images/equipment/gadlee/GT110.PNG": "dad221c4375e794b22a503683133d186",
"assets/assets/images/equipment/gadlee/GTS1450.PNG": "50126cec41d096bf69c5fa70bfbedb3b",
"assets/assets/images/equipment/gadlee/GTS920.PNG": "cedbcbb0cc5e2d9dfa5bbceff514f887",
"assets/assets/images/equipment/gadlee/GT180%2520B95.PNG": "e7ae36f82811cb9e51c2a6ed664c95dd",
"assets/assets/images/equipment/gadlee/GT30.PNG": "bb051dc42494f4277177b973760755f9",
"assets/assets/images/equipment/gadlee/GT85.PNG": "bfaa301d5d17bdf614828e77259348e1",
"assets/assets/images/equipment/gadlee/GTS%25201900.PNG": "fffed6df57396aa9799bd971730e0082",
"assets/assets/images/equipment/gadlee/GT180%252075RS.PNG": "52208188e1cd5638083cfa21444e759d",
"assets/assets/images/equipment/tennant/M17.PNG": "eb75fa53e8136bf87e2d54dde10e0c02",
"assets/assets/images/equipment/tennant/T2.PNG": "549de0a5061e316cff5ff36d5a583ec1",
"assets/assets/images/equipment/tennant/T17.PNG": "6a5c51ed38047f435d3d898e12def719",
"assets/assets/images/equipment/tennant/T300.PNG": "d522950d2297ca1dc32d99fc4dc34230",
"assets/assets/images/equipment/tennant/T500.PNG": "9fda5953202cdf727ab90ffbb55aa82d",
"assets/assets/images/equipment/tennant/T16.PNG": "b114f87714893deacd39bca7ac7e417d",
"assets/assets/images/equipment/tennant/T7.PNG": "9df7b673c847a4b2213122274554d3c2",
"assets/assets/images/equipment/tennant/M30.PNG": "ac759d4a28a0f28e2a395c3bf479094e",
"assets/assets/images/equipment/tennant/S30.PNG": "6449a13e56f951404bace5b898138892",
"assets/assets/images/equipment/tennant/M20.PNG": "30db6b6f3538709effe2d9c752844ea9",
"assets/assets/images/equipment/tennant/T20.PNG": "b053aa9f2f85082db7f3b7183465615c",
"assets/assets/images/equipment/tennant/T12.PNG": "ab193058b031d5a5ee2f3f013f492d50",
"assets/assets/images/equipment/gausium/Phantas.PNG": "661e6d46f2a5722ad51984a67b5c48c6",
"assets/assets/images/equipment/gausium/Vacuum%252040.PNG": "61b5fd0d974486f0e039d1e932d3bc6e",
"assets/assets/images/equipment/gausium/Beetle.PNG": "53b98a4639d91b4206fccf7e361bdb6e",
"assets/assets/images/equipment/gausium/Scrubber%252075.PNG": "ba8f55d22e2518c2e9660e64c03776c9",
"assets/assets/images/equipment/gausium/Scrubber%252050.PNG": "209d5c20fcae8667442921c25b316064",
"assets/assets/images/equipment/gausium/Scrubber%252050%2520Pro.PNG": "acb7b0d3e05628ce7fdf32cfc541b6d2",
"assets/assets/images/equipment/gausium/Omnie.PNG": "f6a4889251ef794a45046c902b37203b",
"assets/AssetManifest.json": "70034fa4b8ed99372d81f90468cadaeb",
"assets/fonts/MaterialIcons-Regular.otf": "aea15543bfbd6f36e95b06aa44111ad2",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"flutter_bootstrap.js": "d7cabcc39ef12171aa84dcac5592cf67",
"version.json": "d6daa527e2e350fb7f4a4dce3ae036db"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
