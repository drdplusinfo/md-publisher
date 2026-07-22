# md-publisher

Generic Markdown-based site publisher. **[Hugo](https://gohugo.io/)** in Docker,
with pluggable presentation **modules** (Hugo theme components).

## Run

```sh
make run
```

Then open the demos — no local Hugo/Go install needed, only Docker:

- [http://localhost:1313](http://localhost:1313) — "Hello, World!" blog
  (`site/`, **blog-classic** module)
- [http://localhost:1314](http://localhost:1314) — "Hello World Rules"
  single-page book (`site-rules/`, **rules-classic** module)

`make stop` shuts it down, `make build` produces a production build in
`site/public/`. Set `HUGO_PORT` to publish on another host port
(`HUGO_PORT=1314 make run`).

The dev server watches `site/` and `modules/` and rebuilds automatically,
including drafts and future-dated posts.

## Layout

```
site/                  # blog demo site: config + content + site-specific static files
  hugo.toml            # identity: title, language, menu, params
  content/             # Markdown content
  static/              # site images etc., served from the web root
site-rules/            # single-page book demo site
modules/               # presentation modules (Hugo theme components)
  blog-classic/        # classic blog look: featured first post, year archive, RSS
  rules-classic/       # one large page from Markdown chapters, TOC, anchor-heavy
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

## rules-classic module

One large single page — a book — composed from Markdown **chapters**, in the
look of the classic DrD+ rules (pph.drdplus.info): parchment background,
contacts bar on top, a generated table of contents, and heavily interlinked
sections.

Content structure (see `site-rules/` for a working example):

```
content/
  _index.md                # optional intro rendered above the TOC
  chapters/
    _index.md              # cascade: build: {render: never, list: local}
    01-introduction.md     # weight: 10 — chapters are ordered by weight
    02-elements.md         # weight: 20
```

Chapters are headless: they exist only concatenated on the homepage, in
`weight` order. The `build:` cascade in `chapters/_index.md` is what makes
them headless — keep it when creating a new site.

Every heading links to itself and gets, besides Hugo's own id
(`combining-items`), invisible anchor aliases in the legacy shapes
(`combining_items` and the verbatim heading text), so fragments survive a
migration from the original PHP publisher. External links are marked
`external-url` and open in a new tab. The classic skin's CSS classes
(`example`, `quote`, `introduction`, `calculation`, `item-combination`, table
styles…) are all available in Markdown via raw HTML.

Params (`site-rules/hugo.toml` shows them all):

| Param | Meaning | Default |
|---|---|---|
| `description` | meta description | — |
| `home` | `{ url, image?, label? }` for the top-left home button | hidden |
| `contacts` | array of `{ icon, label, url, class? }` (Font Awesome icons) | — |
| `showTableOfContents` | render the generated TOC | `true` |
| `tableOfContentsTitle`, `tableOfContentsId` | TOC heading text and id | `Obsah`, `obsah` |
| `baseDomain` | links containing it are NOT marked external | — |

A site-specific stylesheet in `assets/css/custom.css` is minified,
fingerprinted and loaded last, like in blog-classic.
