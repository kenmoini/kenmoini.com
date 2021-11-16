---
title: "Automate Converting Images to WebP"
date: 2021-11-15T04:20:47-05:00
draft: true
publiclisting: true
toc: false
hero: /images/posts/heroes/lightweight-webp.png
tags:
  - google
  - webp
  - image optimization
  - open source
  - oss
  - containers
  - kubernetes
  - git
  - blogging
  - automation
authors:
  - Ken Moini
---

> Well, this is a big mood...

![I thought I just got rid of you...](/images/posts/2021/11/meme-simpsons-google.png)

---

It seems only natural that after I detail how to remove and [replace Google Analytics with Plausible Analytics](https://kenmoini.com/post/2021/11/goodbye-google-hello-plausible/) that I would bring Google back into the fold in another capacity - this time by converting my images to the [WebP format](https://developers.google.com/speed/webp).

---

## Why WebP?

Simply put, I want a higher score on [Lighthouse](https://developers.google.com/web/tools/lighthouse) and the biggest issue is the massive image file sizes that are being served as high quality PNGs.

{{< imgSet cols="1" name="bad-light-house" >}}
{{< imgItem src="/images/posts/2021/11/kenmoini-lighthouse-score.png" alt="This could be better" >}}
{{< /imgSet >}}

WebP provides similar quality at a fraction of the file size - and we can load it in addition to a backup PNG, just in case the [browser doesn't support WebP](https://developers.google.com/speed/webp/faq#which_web_browsers_natively_support_webp) yet.

---

## Getting the WebP Binaries

The WebP libraries are open-source and you can compile them yourself - Google's trustable enough to where we can also just grab the [precompiled binaries](https://developers.google.com/speed/webp/docs/precompiled).

Grab the latest version of the binaries and libraries and extract it:

```bash
## Download the tar package
wget https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.1-linux-x86-64.tar.gz

## Extract it
tar zxvf libwebp-1.2.1-linux-x86-64.tar.gz
```

A few of the notable binaries are:

- `libwebp-1.2.1-linux-x86-64/bin/cwebp` - Converts JPEG, PNG, and TIFF images to WebP
- `libwebp-1.2.1-linux-x86-64/bin/dwebp` - Decodes WebP back to original JPEG, PNG, and TIFF formats
- `libwebp-1.2.1-linux-x86-64/bin/gif2webp` - Converts GIFs to WebP

---

## Automate WebP Conversions

Now that we have the binaries available it's about as easy as just running them to convert files - we can batch that out to add to our automated build processes.

```bash
#!/bin/bash

# converting JPEG images
find $1 -type f -and \( -iname "*.jpg" -o -iname "*.jpeg" \) -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;

# converting PNG images
find $1 -type f -and -iname "*.png" -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;
```

With that script saved, make sure to set the executable bit with `chmod a+x`.

Use it by calling the script with a directory parameter where all the JP{EG,G}s and PNGs located in it and the subdirectories will be converted to WebP format, eg `./convert_to_webp.sh site/static/images/`

---

## Bonus - Wiring up a Hugo Site

Say your website uses Hugo and you deploy to a container - how do you include this in your build processes and then Hugo content?

### Add to a Containerfile

This step is pretty easy - just drop it into your Containerfile before you build the Hugo static site content.

```docker
FROM quay.io/polyglotsystems/golang-ubi AS builder

WORKDIR /workspace

COPY . /workspace

RUN cd /workspace/site \
 && /workspace/bin/convert_images_to_webp.sh /workspace/site/static/images/ \
 && /workspace/bin/hugo-linux-amd64
```

### Modify Hugo Templates

