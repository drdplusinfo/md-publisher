#!/usr/bin/env bash
# Smoke tests for the presentation modules.
#
# There is no application code here, so Hugo itself is the test runner: build a
# site, then assert on the generated HTML. Every check below stands for a bug
# that actually shipped — a section-named layout directory that stopped matching
# a renamed section, a Czech string hardcoded into a generic module, a date
# formatter that ignores the site language, an unrelated section inheriting the
# blog's chrome. They all built successfully and produced wrong output, which is
# why "it builds" is not the assertion.
set -u -o pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'chmod -R u+w "$WORK_DIR" 2>/dev/null; rm -rf "$WORK_DIR"' EXIT

HUGO_IMAGE="hugomods/hugo:0.161.1"
FAILURES=0
CHECKS=0

pass() { CHECKS=$((CHECKS + 1)); printf '  ok   %s\n' "$1"; }
fail() {
    CHECKS=$((CHECKS + 1))
    FAILURES=$((FAILURES + 1))
    printf '  FAIL %s\n' "$1"
    [ -n "${2:-}" ] && printf '       %s\n' "$2"
}

# Assert a regex occurs in a built file.
assert_matches() {
    local label=$1 file=$2 pattern=$3
    if [ ! -f "$file" ]; then
        fail "$label" "missing file: ${file#"$WORK_DIR"/}"
    elif grep -qE -- "$pattern" "$file"; then
        pass "$label"
    else
        fail "$label" "no match for /$pattern/ in ${file#"$WORK_DIR"/}"
    fi
}

assert_not_matches() {
    local label=$1 file=$2 pattern=$3
    if [ ! -f "$file" ]; then
        fail "$label" "missing file: ${file#"$WORK_DIR"/}"
    elif grep -qE -- "$pattern" "$file"; then
        fail "$label" "unexpected match for /$pattern/ in ${file#"$WORK_DIR"/}"
    else
        pass "$label"
    fi
}

assert_file() {
    local label=$1 file=$2
    if [ -f "$file" ]; then pass "$label"; else fail "$label" "missing: ${file#"$WORK_DIR"/}"; fi
}

# Build a site directory into <work>/<name>/public. The modules always come from
# this checkout, so a module change is what the assertions see.
build_site() {
    local name=$1 src=$2
    local dest="$WORK_DIR/$name"
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
    rm -rf "$dest/public" "$dest/resources" "$dest/.hugo_build.lock"
    local log="$WORK_DIR/$name.log"
    if ! docker run --rm \
        -u "$(id -u):$(id -g)" -e HOME=/tmp \
        -v "$REPO_DIR/modules:/modules:ro" \
        -v "$dest:/src" \
        -w /src \
        "$HUGO_IMAGE" hugo --minify --themesDir /modules > "$log" 2>&1
    then
        fail "build $name" "$(tail -3 "$log")"
        return 1
    fi
    pass "build $name"
}

echo "Hugo module smoke tests"
echo

# --- the shipped demo: default postsSection, English -------------------------
echo "demo blog (site/, postsSection defaults to blog, en)"
if build_site blog "$REPO_DIR/site"; then
    P="$WORK_DIR/blog/public"
    assert_file      "post is at /blog/YYYY/MM/DD/slug/"   "$P/blog/2026/07/22/hello-world/index.html"
    assert_matches   "site declares its language"          "$P/index.html" '<html lang=en>'
    assert_matches   "date label is translated (en)"       "$P/index.html" 'title=Date'
    assert_matches   "404 uses the i18n string"            "$P/404.html"   'Nothing here'
    assert_matches   "404 keeps its link unescaped"        "$P/404.html"   '<a href=/>home page</a>'
    assert_matches   "RSS links the post"                  "$P/rss.xml"    '<link>http://localhost:1313/blog/2026/07/22/hello-world/</link>'
    assert_matches   "RSS pubDate is RFC-822"              "$P/rss.xml"    '<pubDate>[A-Z][a-z]{2}, [0-9]{2} [A-Z][a-z]{2} [0-9]{4}'
    assert_matches   "redirect.js targets the section"     "$(ls "$P"/js/redirect.min.*.js 2>/dev/null | head -1)" '/blog/\$\{'
    # The Go template must be executed, not shipped verbatim.
    assert_not_matches "no unrendered template syntax"     "$P/index.html" '\{\{'
fi
echo

# --- renamed section, Czech, plus an unrelated section -----------------------
echo "renamed section (postsSection = jsem, cs)"
if build_site renamed "$REPO_DIR/tests/fixtures/renamed-section"; then
    P="$WORK_DIR/renamed/public"
    POST="$P/jsem/2024/03/11/stary/index.html"

    assert_file      "post follows postsSection"           "$POST"
    assert_not_matches "nothing is served under /blog/"    "$P/index.html" 'href=/blog/'
    assert_file      "section listing follows the param"   "$P/jsem/index.html"

    # .Date.Format always emits English; only time.Format localizes.
    assert_matches   "month name is localized"             "$POST" 'brezna|března'
    assert_not_matches "no English month leaked"           "$POST" '>11\. March'
    # Machine-readable attribute stays ISO regardless of language.
    assert_matches   "datetime attribute stays ISO"        "$POST" 'datetime=2024-03-11'

    assert_matches   "date label is translated (cs)"       "$POST" 'title=Datum'
    assert_matches   "search placeholder is translated"    "$P/index.html" 'placeholder=Hledat'
    assert_matches   "404 is translated"                   "$P/404.html"   'Tady nic není'
    assert_matches   "html lang follows the site"          "$P/index.html" '<html lang=cs>'

    # RFC-822 mandates English names even on a Czech site; localizing pubDate
    # emits "po, 11 bre 2024" and an invalid feed. Only a non-English site can
    # catch this, which is why the assertion lives here and not on the demo.
    assert_matches   "RSS pubDate stays English on a cs site" "$P/rss.xml" '<pubDate>Mon, 11 Mar 2024'
    assert_not_matches "RSS pubDate is not localized"       "$P/rss.xml" '<pubDate>(po|út|st|čt|pá|so|ne),'

    # A legacy flat-file link must be rewritten to the renamed section.
    assert_matches   "legacy .md link is rewritten"        "$POST" 'href=/jsem/2024/03/11/stary/'
    assert_matches   "redirect.js follows the rename"      "$(ls "$P"/js/redirect.min.*.js 2>/dev/null | head -1)" '/jsem/\$\{'

    # Titles are markdown; emphasis renders, and reaches attributes plainified.
    assert_matches   "markdown title renders emphasis"     "$P/index.html" '<em>článek</em>'

    # The menu item highlights only when its id tracks postsSection.
    assert_matches   "menu item is active on a post"       "$POST" '<li class=active>'

    # layouts/_default/list.html must not dress a non-post section as the blog.
    assert_file      "unrelated section still builds"      "$P/pages/index.html"
    assert_not_matches "no blog chrome on /pages/"         "$P/pages/index.html" 'id=blog'
    assert_not_matches "no bogus date on a dateless page"  "$P/pages/index.html" '0001-01-01'
    assert_matches   "unrelated section shows content"     "$P/pages/index.html" 'Úvod sekce'
fi
echo

# --- the book module ---------------------------------------------------------
echo "demo book (site-rules/)"
if build_site book "$REPO_DIR/site-rules"; then
    P="$WORK_DIR/book/public"
    assert_matches   "chapters are concatenated"           "$P/index.html" 'id=introduction'
    assert_matches   "chapters stay headless"              "$P/index.html" 'id=elements'
    # tableOfContentsTitle is set by this site and must win over the translation.
    assert_matches   "TOC title param wins over i18n"      "$P/index.html" '<h1 id=contents>Contents'
    assert_not_matches "no unrendered template syntax"     "$P/index.html" '\{\{'
fi
echo

printf '%d checks, %d failed\n' "$CHECKS" "$FAILURES"
[ "$FAILURES" -eq 0 ]
