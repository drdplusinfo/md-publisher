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
`site/public/`. Both depend on `make init`, which checks for Docker and copies
`.env.dist` to `.env` when you do not have one yet — it never touches an
existing `.env`.

Set `HUGO_PORT` to publish on another host port, either for one run
(`HUGO_PORT=1314 make run`) or permanently by uncommenting it in your `.env`.

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

### Posts under a name other than "blog"

The section holding posts is named by the `postsSection` param, so a site can
publish them under any word — `/jsem/2026/03/04/my-post/` instead of `/blog/…`.
Four things carry the name and must be renamed together:

```toml
[params]
  postsSection = "jsem"           # 1. the param

  [[params.menu]]
    name = "Jsem"
    id = "jsem"                   # 2. menu id, or the nav item stops highlighting
    url = "/"

[permalinks]
  jsem = "/jsem/:year/:month/:day/:slug/"   # 3. the permalink key
```

plus 4. the content directory, so posts live in
`site/content/jsem/<year>/<MM-DD-slug>/index.md`. The listing, RSS, post layout,
social-media meta and both legacy-link rewrites then follow the param. Leave it
unset to keep `blog`.

## Legacy link handling (blog-classic)

Content migrated from flat-file generators often links to sibling posts as
`YYYY-MM-DD-slug.md` (optionally `../YYYY/YYYY-MM-DD-slug.md`). A Markdown
render hook rewrites such links to `/<postsSection>/YYYY/MM/DD/slug/` at build
time, and
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
| `postsSection` | content section holding the posts; also the first URL segment | `blog` |
| `description` | RSS channel description | — |
| `author` | RSS `dc:creator` | site title |
| `rssTitle` | RSS channel title, and the `<link rel=alternate>` title in `<head>` | site title |
| `menu` | array of `{ name, url, id?, hideOnSmall? }`; item is active when `id` matches the page's `id` front matter or its section — so `id` must track `postsSection` | — |
| `showRssInMenu` | RSS icon in the menu | `true` |
| `searchDomain` | site-scoped Google search box in the menu | off |
| `footerHtml` | raw HTML in the footer | empty |
| `googleAnalyticsId` | GA tracking | off |
| `twitterSite` | `twitter:site` meta on posts | off |
| `ogLocale` | `og:locale` meta on posts | off |
| `dateFormat`, `dayMonthFormat` | Go time layouts for post dates (`dayMonthFormat` is used for the current year); month names follow the site language (see [Interface texts](#interface-texts-i18n)), so write the layout with `January`, not a translated literal | `2. 1. 2006`, `2. 1.` |

## Interface texts (i18n)

The modules' own texts — the date tooltip, the RSS icon's alt text, the search
placeholder, the 404 page, the book's TOC heading — come from the module's
`i18n/` files, picked by the site's language:

```toml
languageCode = "cs"
defaultContentLanguage = "cs"
```

Set **both**. Either one alone already switches the interface texts and the
month names, but only `defaultContentLanguage` sets `<html lang>` — so a site
that sets just `languageCode` serves Czech text inside a page declaring
`lang="en"`.

`en` and `cs` ship with both modules. To add a language, drop an `i18n/<code>.toml`
into a site (`site/i18n/de.toml`) — it shadows the module — or into the module
itself:

```toml
date = "Datum"
rssFeed = "RSS kanál"
search = "Hledat..."
notFoundTitle = "Tady nic není 😢"
notFoundText = 'Zkus <a href="/">úvodní stránku</a>'
```

Overriding a single string for one site works the same way: shadow just that key.
Note that `tableOfContentsId` in rules-classic is deliberately *not* translated —
it is a URL anchor that inbound links depend on.

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
| `tableOfContentsTitle` | TOC heading text; overrides the translation | from `i18n/` |
| `tableOfContentsId` | TOC heading id — a URL anchor, so it does *not* follow the language | `obsah` |
| `baseDomain` | links containing it are NOT marked external | — |

A site-specific stylesheet in `assets/css/custom.css` is minified,
fingerprinted and loaded last, like in blog-classic.

The full-page background artwork is site-supplied (the module ships only the
parchment texture): put an image in the site's `static/` and set it in
`assets/css/custom.css`:

```css
.background-image {
    background-image: url(/my-background.png);
}
```
