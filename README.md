# md-publisher

Generic Markdown-based site publisher. **[Hugo](https://gohugo.io/)** in Docker,
with pluggable presentation **modules** (Hugo theme components).

## Run

```sh
make run
```

Then open [http://localhost:1313](http://localhost:1313) — you should see a
"Hello, World!" page. No local Hugo/Go install needed, only Docker.

`make stop` shuts it down, `make build` produces a production build in
`site/public/`. Set `HUGO_PORT` to publish on another host port
(`HUGO_PORT=1314 make run`).

The dev server watches `site/` and `modules/` and rebuilds automatically,
including drafts and future-dated posts.

## Layout

```
site/                  # your site: config + content + site-specific static files
  hugo.toml            # identity: title, language, menu, params
  content/             # Markdown content
  static/              # site images etc., served from the web root
modules/               # presentation modules (Hugo theme components)
  blog-classic/        # classic blog look: featured first post, year archive, RSS
```

A site selects its modules in `site/hugo.toml`:

```toml
theme = ["blog-classic"]
themesDir = "../modules"
```

Modules stack — later entries override earlier ones, so a site can add its own
override module (e.g. `theme = ["blog-classic", "my-skin"]`) or simply shadow
single files: anything in `site/layouts/` or `site/static/` wins over the module.

## Add a post

Create `site/content/blog/<year>/<MM-DD-slug>/index.md`:

```yaml
---
date: 2026-03-04
slug: my-post
title: "My post"
image: /assets/images/posts/some_image.png
perex: |
    Short lead paragraph.
---

Post body in Markdown.
```

Served at `/blog/2026/03/04/my-post/` (the URL date comes from `date:`, not the
directory name). Optional front matter: `facebook_image`, `image_author`,
`deprecated_since` (hides the post from listings and RSS).

## Legacy link handling (blog-classic)

Content migrated from flat-file generators often links to sibling posts as
`YYYY-MM-DD-slug.md` (optionally `../YYYY/YYYY-MM-DD-slug.md`). A Markdown
render hook rewrites such links to `/blog/YYYY/MM/DD/slug/` at build time, and
`redirect.js` does the same in the browser for legacy `#!clanky/…` hash URLs.
Absolute URLs are never touched.

Fragments are covered by a heading render hook: every heading gets, besides
Hugo's own id (`magická-šestka`), invisible anchor aliases in the legacy
shapes (`Magická_šestka`, `magicka_sestka`, `magicka-sestka`), so old
fragment links — including inbound ones from external sites — still scroll
to their section.

## blog-classic module parameters

Set under `[params]` in `site/hugo.toml`:

| Param | Meaning | Default |
|---|---|---|
| `description` | RSS channel description | — |
| `author` | RSS `dc:creator` | site title |
| `rssTitle` | RSS channel title | site title |
| `menu` | array of `{ name, url, id?, hideOnSmall? }`; item is active when `id` matches the page's `id` front matter or its section | — |
| `showRssInMenu` | RSS icon in the menu | `true` |
| `searchDomain` | site-scoped Google search box in the menu | off |
| `searchPlaceholder` | search box placeholder | `Search...` |
| `footerHtml` | raw HTML in the footer | empty |
| `googleAnalyticsId` | GA tracking | off |
| `twitterSite` | `twitter:site` meta on posts | off |
| `ogLocale` | `og:locale` meta on posts | off |
| `dateFormat`, `dayMonthFormat` | Go time layouts for post dates | `2. 1. 2006`, `2. 1.` |
| `notFoundTitle`, `notFoundText` | 404 page texts | English defaults |
