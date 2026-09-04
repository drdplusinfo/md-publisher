# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A generic Markdown-based site publisher: **Hugo in Docker** (no local Hugo/Go
install) plus pluggable presentation **modules** — Hugo theme components living
in `modules/`, each extracted from a legacy hand-written PHP/Statie site of the
DrD+ family. There is no application code and no build tooling; everything is
Hugo templates, CSS and content. `README.md` is the user-facing
documentation and documents every module parameter — keep it in sync when you
change a module's template contract.

## Commands

```sh
make init    # checks docker, seeds .env from .env.dist if absent
make run     # docker compose up -d; prints both demo URLs
make stop    # docker compose down
make build   # production build of site/ into site/public/ (--minify)
make test    # module smoke tests (tests/run.sh)
```

Two demo sites run side by side from one compose file:

| Service | Site dir | Module | Port | Env override |
|---|---|---|---|---|
| `hugo` | `site/` | blog-classic | 1313 | `HUGO_PORT` |
| `hugo-rules` | `site-rules/` | rules-classic | 1314 | `HUGO_RULES_PORT` |

The dev server watches `site/`, `site-rules/` and `modules/` and rebuilds on
change, with `--buildDrafts --buildFuture`. `make build` only builds `site/`;
for the book demo run `docker compose run --rm hugo-rules --minify`.

Ad-hoc Hugo commands go through the container, e.g.
`docker compose run --rm hugo list all`.

Both services run as `${HOST_UID}:${HOST_GID}`, so what Hugo generates into the
bind mount (`public/`, `resources/`, `.hugo_build.lock`) stays owned by the host
user instead of root. Two things supply those variables: the Makefile exports
them from `id -u`/`id -g`, and a gitignored `.env` (Compose reads it
automatically) covers a bare `docker compose` invocation — without either, the
`:-1000` fallback would write files owned by whoever uid 1000 happens to be.
The container also needs `HOME=/tmp`, since the host uid has no home directory
inside the image.

`.env` is the developer's own file and is **never** written to by the Makefile:
`make init` copies `.env.dist` onto it only when it does not exist, the same
`[ -e .env ] || cp .env.dist .env` shape the other projects here use. `run` and
`build` depend on `init`, so a fresh clone needs no separate step. An earlier
version regenerated `.env` on every `make run` and silently discarded a
`HUGO_PORT` set there — don't reintroduce that.

A checkout that predates this carries root-owned artifacts, and Hugo then dies
with `failed to acquire a build lock: … permission denied`. Clear them once
through a container rather than with sudo:

```sh
docker run --rm -v "$PWD":/src alpine:3.20 \
    sh -c 'rm -rf /src/site/public /src/site/resources /src/site/.hugo_build.lock \
                  /src/site-rules/public /src/site-rules/resources /src/site-rules/.hugo_build.lock'
```

## Architecture

### Sites vs. modules

A site directory (`site/`, `site-rules/`) holds **only** identity: `hugo.toml`,
`content/`, and optionally `static/` and `assets/css/custom.css`. All layout,
CSS and vendored front-end assets live in the module. A site picks its modules:

```toml
theme = ["blog-classic"]
themesDir = "../modules"
```

Modules stack — later entries win — and anything in `site/layouts/` or
`site/static/` shadows the module. That is the intended extension point: prefer
an override module or a shadowed file over editing a module for one site's sake.
A module must stay site-agnostic; anything site-specific (background artwork,
brand colours, contacts) is supplied through `hugo.toml` params or
`assets/css/custom.css`, which both modules load last, minified and
fingerprinted.

Adding a module = a new `modules/<name>/` with `theme.toml`, `layouts/` and
whatever `assets/`+`static/` it needs, then `theme = ["<name>"]` in a site.

### Legacy-URL compatibility is the point of both modules

These modules replace older publishers whose URLs are already indexed and linked
to from outside. Preserving those URLs is a hard requirement, handled in three
places — touch them carefully:

- **blog-classic `_default/_markup/render-link.html`** rewrites flat-file post
  links (`YYYY-MM-DD-slug.md`, `../YYYY/YYYY-MM-DD-slug.md`) to the permalink
  shape `/<postsSection>/YYYY/MM/DD/slug/` at build time. Absolute URLs pass
  through.
- **`assets/js/redirect.js`** does the same mapping in the browser for legacy
  `#!clanky/…` hash URLs. It and the render hook must agree on the mapping.
- **Both modules' `render-heading.html`** emit, next to Hugo's own heading id,
  invisible `<span id>` anchor aliases in the old id shapes (verbatim heading
  text, ASCII-folded lowercase with underscores, with hyphens) so inbound
  fragment links still scroll. The Czech diacritics fold table is inline in both
  hooks. rules-classic additionally wraps the heading in a self-link.

Note the differing hook paths: blog-classic uses `layouts/_default/_markup/`,
rules-classic uses `layouts/_markup/` — both work, don't "fix" one to match.

### blog-classic

Classic blog: `layouts/index.html` renders the newest post as a featured card
with `perex` and image, the rest as a year-grouped list (the current year gets
no year heading). Posts are `site/content/<postsSection>/<year>/<MM-DD-slug>/index.md`;
the URL date comes from `date:` front matter via `[permalinks]`, **not** the
directory name. RSS is a custom `_default/rss.xml` served at `/rss.xml`
(`[outputFormats.RSS] baseName = "rss"`), holding back future-dated posts even
though the dev server builds them.

The section holding posts is configurable — `params.postsSection`, default
`blog` — so a site can publish them under any word (jsem.tu uses `jsem`). Six
places read it, and all of them must keep the `| default "blog"` fallback:
`index.html`, `_default/list.html`, `_default/single.html`, `_default/rss.xml`,
`_default/_markup/render-link.html` and `partials/head.html`. Consequences worth
knowing:

- Post layouts live in `_default/`, **not** `layouts/blog/`, because a
  section-named directory only matches a section literally called `blog`.
  `_default/single.html` therefore branches on `eq .Section $postsSection`:
  the post layout for posts, bare `{{ .Content }}` for every other page.
- `redirect.js` is a Go template, so `head.html` pipes it through
  `resources.ExecuteAsTemplate` before `minify | fingerprint`. Its JS
  `${...}` interpolations are untouched by Go templating, but a new `{{ }}`
  in that file is now template syntax.
- A site renames three things together: the content directory, the
  `[permalinks]` key, and `postsSection`.

`deprecated_since` in front matter hides a post from listings and RSS — the
filter `where … "Params.deprecated_since" nil` is repeated in `index.html`,
`_default/list.html` and `rss.xml`; change all three together.

Titles are Markdown (`| markdownify`), so anywhere a title reaches an
attribute, a `<title>` or RSS it needs `| plainify` (and `| htmlUnescape` in
RSS) as well.

Dates use **`time.Format`, never `.Date.Format`**, for anything a reader sees.
`.Date.Format` is Go's raw formatter and always emits English month and day
names whatever `languageCode` says; only Hugo's `time.Format` localizes (and it
declines correctly, e.g. Czech genitive `22. července`). Three `.Date.Format`
calls are deliberately left raw and must stay that way: the machine-readable
`<time datetime="2006-01-02">` attribute, the `"2006"` year comparisons in
`index.html` and `post-metadata-line.html`, and the RSS `pubDate`/`lastBuildDate`
— RFC-822 mandates English names, so localizing those would emit an invalid feed.

A related trap in a site's `dateFormat`/`dayMonthFormat`: Go layouts are
*reference-based*, the layout string being an example of `Mon Jan 2 15:04:05 MST
2006`. A literal month name written into the layout (`"2. ledna"`) is not a
token — it is copied verbatim into every date. Write `"2. January 2006"` and let
`languageCode` translate it.

### rules-classic

One long single page — a book. `layouts/index.html` renders the home page's own
content, then a generated TOC, then every chapter's `.Content` concatenated in
`weight` order. Chapters are **headless**: `content/chapters/_index.md` carries
a `cascade` of `build: {render: never, list: local}`, which is what keeps them
off their own URLs — keep it when creating a new site of this kind.

`partials/toc.html` builds the classic nested-table TOC from
`.Fragments.Headings` (h1 → table per chapter heading, h2 `main` rows, h3 plain
rows), so the TOC follows the chapters' heading structure, not a Hugo TOC.

`render-link.html` marks off-site links `external-url` + `target="_blank"`;
`params.baseDomain` exempts the site's own absolute URLs.

The parchment texture ships with the module, but the full-page background
artwork is site-supplied via `.background-image` in the site's
`assets/css/custom.css`.

### Interface texts

Module-owned texts live in each module's `i18n/` (`en.toml`, `cs.toml`) and are
looked up with `{{ i18n "key" }}`. Either `languageCode` or
`defaultContentLanguage` drives the lookup (and `time.Format`'s month names),
but only `defaultContentLanguage` sets `<html lang>` — a site should set both,
and the demos do.

There are no per-string params any more — `searchPlaceholder`, `notFoundTitle`
and `notFoundText` were removed in favour of translations; a site overrides one
string by shadowing that key in its own `site/i18n/<code>.toml`.

Two deliberate exceptions, both because the value is not really a label:

- `tableOfContentsId` (rules-classic) stays a param — it is a URL anchor that
  inbound legacy links depend on, so it must not move with the language. Its
  heading text `tableOfContentsTitle` does fall back to `i18n`, and a site that
  sets one without the other gets a translated heading under an untranslated id.
  That is intended.
- `rssTitle` stays a param — it names the specific feed, not the UI.

Anything reader-visible added to a layout belongs in `i18n/`, not inline: the
modules are generic, so an untranslated literal (there used to be a Czech
`title="Datum"` and an `"Obsah"` default) is a bug even when it looks harmless.

## Tests

`make test` runs `tests/run.sh`: it builds `site/`, `site-rules/` and the
`tests/fixtures/renamed-section/` fixture with Hugo in Docker, then greps the
generated HTML. Hugo is the test runner — there is nothing else to run.

The fixture is the interesting one: a Czech site with `postsSection = "jsem"`,
an unrelated `pages/` section and a past-year post, so one build covers the
rename, the translations, localized dates and the non-post-section case.

Every assertion stands for a bug that actually shipped, and each one builds
cleanly while producing wrong output — which is why "it builds" is not the
assertion. When adding a check, confirm it *fails* against the reintroduced bug
before trusting it: an earlier version of the RSS check asserted only the
RFC-822 *shape*, which Czech abbreviations also match, so it passed against a
feed reading `po, 11 bře 2024`. It now asserts the English names on the Czech
fixture, where the difference is visible.

The suite builds into a `mktemp -d`, never into `site/public/`, so it is safe to
run while a dev server is up. CI runs it on every pull request.

## Conventions

- `markup.goldmark.renderer.unsafe = true` in both sites: content is trusted and
  uses raw HTML for the classic skin's CSS classes (`example`, `quote`,
  `introduction`, `calculation`, `item-combination`, table styles).
- Vendored front-end assets under a module's `static/assets/` are version-named
  (`bootstrap-4.0.0`, `font-awesome.5.0.13`, `prism-1.15.0`); keep that shape
  and reference them by absolute `/assets/…` path from `head.html`.
- Module CSS/JS that a site may want fingerprinted goes in `assets/`; third-party
  vendored files go in `static/`.
- `.editorconfig`: 4 spaces, 2 for `yml`/`yaml`/`toml`, tabs in `Makefile`.
- Template comments explain the legacy constraint being satisfied — that is the
  non-obvious "why" worth keeping; don't add comments restating what a template
  line does.
- Commit messages state the user-visible effect ("Emit valid XML in RSS feed"),
  under ~50 chars.
