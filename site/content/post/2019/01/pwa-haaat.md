---
title: "PWA-Haaat"
date: 2019-01-03T22:31:48-05:00
draft: false
listed: true
aliases:
    - /blog/pwa-haaat/
hero: /images/posts/heroes/resized/resized-pwhaaat.png
tags: 
  - progressive web design
  - pwa
  - service workers
  - javascript
  - js
  - Fierce Software
authors:
  - Ken Moini
---

I'm sure you've heard of RWD, or Responsive Web Design.  HA, that's _soooo_ two-thousand-and-_late_

What's hot on the streets these days is PWA, or Progressive Web Applications.
You know how Google has pretty much taken over how the web is shaped due to our consumption and reliance and development around Chrome?  Yeah, well they've rolled out AMP which I'm sure you've seen, but otherwise there's another thing - these Progressive Web Applications.

See, the idea is to bring more native application functions into web application platforms in an easy manner.  Down side is pretty much only Chrome-based browser support these features.  Yay!

Considering that's what I cater to as well, I decided to take a plunge into PWAs with a great guenea pig - [the website for the company I work for!](https://fiercesw.com)

### Project: Fierce Software
#### Task: Finish PWA deployment & testing

There were a few key things I wanted to offer via the Service Worker extensions in deploying the PWA components...

 - Pre-caching of files
 - On-the-go caching of files with filtering
 - Offline banner notice at bottom of page when disconnected
 - Add to Homescreen functionality (more native app like look)
 - Custom offline page for non-cached pages
 - Custom 404 page

First off, I must admit I did not code all of this today.  Most of it I did before when transitioning the company website to a new host.
However, the 404 page and some of the finer logic was completed today after a lot of labor because these service worker things aren't easy and the examples out there are very different and not all correct...

What I will go about are some of the files that make of the COMPLETE working of a PWA-enabled WordPress website running on Nginx.  There are a lot of details, most of it is verbose enough and has pretty solid comments, otherwise there are a lot of moving parts - keep up.
This will assume you generated your site.manifest file and needed icons with the [Favicon Generator](https://realfavicongenerator.net/).

**/con.txt** - This is just a sample file that exists for a connection test because 

**/sw.js** - This is the Service Worker, a lot of the brains behind the operation
{{< highlight js >}}
//===================================================================================
// Setup
// - Define the name you want for your cache (var CACHE)
// - List the files and paths you want pre-cached
// -- NOTE: Different path variables on the same file do count as different assets
// --   eg /css/style.css != /css/style.css?v=4.2.0 that is loaded from your header,
// --   you'll need to list the specific asset path that is loaded to properly cache
//===================================================================================
var CACHE = "fsw-offline";
var VERBOSE = false;
var precacheFiles = [
	'/',
	'/404.html',
	'/offline.html',
	'/offline-files/offline-feline-tiny.jpeg',
	'/offline-files/cropped-logo3.png',
	'/offline-files/404Img_smaller.png',
	'/android-chrome-144x144.png',
	'/android-chrome-192x192.png',
	'/android-chrome-256x256.png',
	'/android-chrome-36x36.png',
	'/android-chrome-384x384.png',
	'/android-chrome-48x48.png',
	'/android-chrome-512x512.png',
	'/android-chrome-72x72.png',
	'/android-chrome-96x96.png',
	'/apple-touch-icon-114x114.png',
	'/apple-touch-icon-120x120.png',
	'/apple-touch-icon-144x144.png',
	'/apple-touch-icon-152x152.png',
	'/apple-touch-icon-180x180.png',
	'/apple-touch-icon-57x57.png',
	'/apple-touch-icon-60x60.png',
	'/apple-touch-icon-72x72.png',
	'/apple-touch-icon-76x76.png',
	'/apple-touch-icon.png',
	'/apple-touch-icon-114x114-precomposed.png',
	'/apple-touch-icon-120x120-precomposed.png',
	'/apple-touch-icon-144x144-precomposed.png',
	'/apple-touch-icon-152x152-precomposed.png',
	'/apple-touch-icon-180x180-precomposed.png',
	'/apple-touch-icon-57x57-precomposed.png',
	'/apple-touch-icon-60x60-precomposed.png',
	'/apple-touch-icon-72x72-precomposed.png',
	'/apple-touch-icon-76x76-precomposed.png',
	'/apple-touch-icon-precomposed.png',
	'/favicon-16x16.png',
	'/favicon-32x32.png',
	'/favicon.ico'
    ];

//===================================================================================
// Service Worker Install Event Listener
// - Install stage sets up the offline page in the cache and opens a new cache
// - All we're doing in this function though is listening to the 'install' event that
//    is fired on initial Service Worker deployment.  When this event is fired, we'll
//    run the function preLoad() and waitUntil it is completed.
//===================================================================================
self.addEventListener('install', function(event) {
	if (VERBOSE) {
	  console.log('[ServiceWorker] Install Event starting');
	}
  event.waitUntil(preLoad());
	if (VERBOSE) {
		console.log('[ServiceWorker] Install Event complete');
	}
});

//===================================================================================
// preLoad function
// - This function will be run once the Service Worker's 'install' event is fired
// - We're opening a cache (var CACHE defined earlier), then with that cache we'll
//    add all of the files we defined earlier to this cache.
//===================================================================================
var preLoad = function(){
  return caches.open(CACHE).then(function(cache) {
		if (VERBOSE) {
	    console.log('[ServiceWorker] Precaching core files and offline page');
		}
    return cache.addAll(precacheFiles);
  }).catch(function(ex) {
    console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
  });
}

//===================================================================================
// Service Worker Fetch Event Listener
// - This is where most of the magic is piped together.
// - For every request's 'fetch' event, the Service Worker will basically hijack it
//    First it'll run checkResponse which will determine if it's a proper request or
//    if it's a 404.  Then we'll take the proper requests and route through the
//    returnFromCache function, which will serve the files if they're in the cache.
//    Finally we'll also run those hijacked fetch requests thruogh the addToCache
//    function in order to proactively cache other assets as well
//===================================================================================
self.addEventListener('fetch', function(event) {
	var destination = event.request.destination;
	var url = event.request.url;
	if ( !url.includes("/wp-admin/") && !url.includes("wp-login.php") && !url.includes("con.txt") ) {
	  event.respondWith(checkResponse(event.request).catch(function() {
			if (VERBOSE) {
		    console.log('[ServiceWorker] The service worker is serving this asset from cache: ' + event.request.url);
			}
	    return returnFromCache(event.request)}
	  ));
	  event.waitUntil(addToCache(event.request));
	}
});

//===================================================================================
// checkResponse function
// - This function will create a new Promise that will determine if a fetch's reponse
//    code is something other than a 404, if so it'll continue if not then it won't
//    attempt to proceed with the cache matching
//===================================================================================
var checkResponse = function(request){
  return new Promise(function(fulfill, reject) {
    fetch(request).then(function(response){
      //if(response.status !== 404) {
        fulfill(response)
      //} else {
        //reject(response);
      //}
    }, reject).catch(function(ex) {
	    console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
	  });
  });
};

//===================================================================================
// addToCache function
// - This function will handle opening the cache and adding files to it
// - Before we simply add any file to the cache we want to do some filtering or else
//    we run over our cache quota.  Also maybe you only want to cache certain types
//    of files, or files from specific domains and not under specific directories...
//===================================================================================
var addToCache = function(request){
	var destination = request.destination;
	var url = request.url;
	// Only continue to cache if the asset is from our example.com domain and not under the /wp-admin/ folder
	if ( url.includes("fiercesw.com/") && !url.includes("/wp-admin/") && !url.includes("wp-login.php") && !url.includes("con.txt") ) {
		// We also only want to cache a certain type of asset, the more static types
		//console.log(destination);
		switch (destination) {
			case 'style':
			case 'script':
			case 'document':
			case 'image':
			case 'font':
			case 'manifest':
			  return caches.open(CACHE).then(function (cache) {
			    return fetch(request).then(function (response) {
						if (VERBOSE) {
	            console.log('[ServiceWorker] Added asset to offline cache: ' + url);
						}
            return cache.put(request, response);
			    }).catch(function(ex) {
				    console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
				  });
			  });
			break;
			default:
				//Nada to see here, no caching
				return;
			break;
		}
	}

};
//===================================================================================
// returnFromCache function
// - This function will take a request and see if it matches a cached asset
//===================================================================================
var returnFromCache = function(request){
  return caches.open(CACHE).then(function (cache) {
    return cache.match(request).then(function (matching) {
     if(!matching || matching.status == 404) {
				if (!matching) {
					return cache.match('/offline.html');
				}
			 return cache.match('/404.html');
     } else {
       return matching;
     }
    }).catch(function(ex) {
	    console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
	  });
  }).catch(function(ex) {
    console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
  });
};

{{< / highlight >}}

**/wp-content/themes/THEME_NAME/global_templates/pwa_header.php** - This file is included across all of my various header.php files in my WordPress install.  Basically the idea is to load this across your site inside the _&lt;head&gt;_ tag.  It will load the icons you generated, set some additional manifest info, styles for an Add-to-Homescreen banner, and the needed JS to register/use the service worker and all the extras built on top of it

{{< highlight html >}}
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="192x192" href="/android-chrome-192x192.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="manifest" href="/site.webmanifest">
<link rel="mask-icon" href="/safari-pinned-tab.svg" color="#1b75bc">
<link rel="shortcut icon" href="/favicon.ico">
<meta name="msapplication-TileColor" content="#fafafa">
<meta name="theme-color" content="#fafafa">
<style type="text/css">
  .a2hs-banner {
	display: none;
	position: fixed;
	width: calc(100% - 4rem);
	padding: 1rem;
	bottom: 0;
	background: rgb(12, 121, 177);
	color: rgb(255, 255, 255);
	z-index: 99999;
	margin: 2rem;
	box-shadow: 0px 0px 8px -1px rgba(0,0,0,0.45);
  }
</style>
<script type="text/javascript">
  function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    var expires = "expires="+d.toUTCString();
    document.cookie = cname + "=" + cvalue + ";" + expires + ";";
  }

  function getCookie(cname) {
    var name = cname + "=";
    var ca = document.cookie.split(';');
    for(var i = 0; i < ca.length; i++) {
      var c = ca[i];
      while (c.charAt(0) == ' ') {
        c = c.substring(1);
      }
      if (c.indexOf(name) == 0) {
        return c.substring(name.length, c.length);
      }
    }
    return "";
  }
  // closeAndIgnore function
  // - This just binds to the PWA banners/modals such as the Offline or Add-to-Homescreen notice and sets a cookie in order to not display it again for the next 30 days
  function closeAndIgnore(target,name) {
    target.parentNode.parentNode.removeChild(target.parentNode);
    setCookie("ignorePopup-" + name, "true", 30);
  }
  // additionalConnectionTest function
  // - The only reason this exists is because Chrome has a bug that sometimes returns the wrong value for navigator.onLine and so desktop clients will get the offline banner when operating normally...
  // - Otherwise, this function basically just pings a file with a rangom URI to break cache in order to do a "real" "ping" "test"
  function additionalConnectionTest() {
    console.log("Running additional connection test...")
    const Http = new XMLHttpRequest();
    const url = 'https://fiercesw.com/con.txt?v=' + Math.floor(Math.random() * 1001);
    Http.timeout = 2000;
    Http.open("HEAD", url, true);
    Http.send();
    function processRequest(e) {
      if (Http.readyState == 4) {
        if (Http.status >= 200 && Http.status < 304) {
          console.log("Additional connection test successful");
          return true;
        } else {
          console.log("Additional connection test timed out");
          return false;
        }
      }
      else {
        return false;
      }
    }
    return Http.addEventListener("readystatechange", processRequest, false);
  }

  // updateOnlineStatus function
  // - This function adds the "You are offline" notice banner at the bottom of the page when the device is offline or removes it otherwise.
  function updateOnlineStatus() {
    if (!window.navigator.onLine) {
      //Do an additional connection test...Chrome bug...
      if (!additionalConnectionTest()) {
        if ((document.querySelectorAll('.offlineNotice').length === 0) && (getCookie("ignorePopup-offlineNotice") !== "true")) {
          var elem = document.createElement('div');
          elem.style.cssText = 'position:fixed;width:100%;padding:1rem;bottom:0;background:#0c79b1;color:#FFF;z-index:99999;';
          elem.className = 'offlineNotice';
          elem.innerHTML = "<a style='margin:0 0 0 0.5rem;float:right;padding: 0.25rem 0.5rem;background:rgba(255,255,255,0.4);color: #FFF;font-weight: bold;' href='#' onclick='closeAndIgnore(this,\"offlineNotice\");'>X</a><p style='margin:0.25rem 0;'><strong>You're offline &dash; </strong> It seems as if you're disconnected from the Internet, but some resources are still available.</p>";
          document.body.appendChild(elem);
        }
      }
    }
    else {
      if (document.querySelectorAll('.offlineNotice').length > 0) {
        var elems = document.querySelectorAll('.offlineNotice');
        for(i=0;i<elems.length;i++) {
          elems[i].parentElement.removeChild(elems[i]);
        }
      }
    }
    //Live coverage
    //document.querySelector('.connection').innerHTML = window.navigator.onLine;
  }

  //This is the service worker with the combined offline experience (Offline page + Offline copy of pages)

  //Add this below content to your HTML page, or add the js file to your page at the very top to register service worker
  if (navigator.serviceWorker.controller) {
    console.log('[ServiceWorker] Active service worker found, no need to register');
  } else {

  //Register the ServiceWorker
    navigator.serviceWorker.register('/sw.js', {
      scope: './'
    }).then(function(reg) {
      console.log('[ServiceWorker] Service worker has been registered for scope: '+ reg.scope);
    }).catch(function(ex) {
      console.log("[ServiceWorker][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
    });
  }
  // Vanilla JS' jQuery.ready lolololo
  window.addEventListener('load', function(ev) {

    // Online/offline detection and banner alert
    window.addEventListener('online',  updateOnlineStatus);
    window.addEventListener('offline', updateOnlineStatus);
    updateOnlineStatus();

    //Setup Add to Home Screen button triggers
    if (getCookie("ignorePopup-a2hs") !== "true") {
      var a2hs = document.createElement('div');
      a2hs.className = 'a2hs-banner';
      a2hs.innerHTML = "<a style='margin:0 0 0 0.5rem;float:right;padding: 0.25rem 0.5rem;' class='btn btn-light' href='#' id='installA2HS'>Add</a><a style='margin: 0 1rem 0 0;float: left;padding: 0.25rem 0.5rem;background:rgba(255,255,255,0.4);color: #FFF;font-weight: bold;' href='#' onclick='closeAndIgnore(this,\"a2hs\");' class='btn btn-link'>X</a><p style='margin:0.25rem 0;'><strong>Fierce at your Fingertips -</strong> Get the Fierce Software Web App</p>";
      document.body.appendChild(a2hs);

      let deferredPrompt;
      window.addEventListener('beforeinstallprompt', (event) => {

        // Prevent Chrome 67 and earlier from automatically showing the prompt
        event.preventDefault();

        // Stash the event so it can be triggered later.
        deferredPrompt = event;

        // Attach the install prompt to a user gesture
        document.querySelector('#installA2HS').addEventListener('click', event => {

          // Show the prompt
          deferredPrompt.prompt();

          // Wait for the user to respond to the prompt
          deferredPrompt.userChoice
            .then((choiceResult) => {
              if (choiceResult.outcome === 'accepted') {
                console.log('[ServiceWorker][A2HS] User accepted the A2HS prompt');
              } else {
                console.log('[ServiceWorker][A2HS] User dismissed the A2HS prompt');
              }
              deferredPrompt = null;
            }).catch(function(ex) {
              console.log("[ServiceWorker][A2HS][Error Code " + ex.code +"] " + ex.name + ": " + ex.message);
            });
        });
        // Update UI notify the user they can add to home screen
        document.querySelector('.a2hs-banner').style.display = 'block';

        return false;
      });
    }

  });

</script>
{{< / highlight >}}

**nginx config** The configured site has a 404 directive to point to the /404.html file we have at our webroot
{{< highlight bash >}}
error_page 404 /404.html;
{{< / highlight >}}

Now what I have is the [Fierce Software](https://fiercesw.com) loading lickity-split, caching resources, providing offline guidance and fallbacks, an integrated 404 page, Add-to-Homescreen functionality, and efficient routing!  For some reason the Service Worker and Chrome kept returning extra responses for a while which is why some things are commented out in the _sw.js - checkResponse_ function - the PWABuilder code isn't quite correct...

<div class="row text-center">
{{< figure src="/images/posts/legacyUnsorted/Screenshot_20190103-221758_Chrome.jpg" link="/content-stuff/Screenshot_20190103-221758_Chrome.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
{{< figure src="/images/posts/legacyUnsorted/Screenshot_20190103-221827_Chrome.jpg" link="/content-stuff/Screenshot_20190103-221827_Chrome.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
{{< figure src="/images/posts/legacyUnsorted/Screenshot_20190103-221847_Chrome.jpg" link="/content-stuff/Screenshot_20190103-221847_Chrome.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
{{< figure src="/images/posts/legacyUnsorted/Screenshot_20190103-221922_Chrome.jpg" link="/content-stuff/Screenshot_20190103-221922_Chrome.jpg" target="_blank" class="col-sm-12 col-md-4 offset-md-4" >}}
</div>