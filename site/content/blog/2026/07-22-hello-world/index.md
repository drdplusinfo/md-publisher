---
date: 2026-07-22
slug: hello-world
title: "Hello, World!"
perex: |
    Welcome to your new Markdown-based site. This lead paragraph is called *perex*
    and is shown on the homepage and in social-media previews.
---

## It works

You are looking at a post rendered by the **blog-classic** module.

To make this site yours:

1. Edit `site/hugo.toml` — title, language, menu, params.
2. Replace this post: create `site/content/blog/<year>/<MM-DD-slug>/index.md`
   with `date`, `slug`, `title` and `perex` in the front matter.
3. Put site images into `site/static/` (e.g. `site/static/assets/images/`).

The post URL is built from the `date` and `slug` front matter:
this one is served at `/blog/2026/07/22/hello-world/`.

```js
console.log('Code highlighting via Prism works too.');
```
