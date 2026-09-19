#!/usr/bin/env bash
# Cut a release: bump the version in FantomsPreview.json, commit, tag, and push.
# The pushed tag triggers .github/workflows/release.yml, which publishes the zip.
#
# Usage: bash release.sh [patch|minor|major|X.Y.Z] [--dry-run]
#        Defaults to a patch bump.
set -euo pipefail
cd "$(dirname "$0")"

MANIFEST="FantomsPreview.json"
BRANCH="main"
REMOTE="origin"

bump="patch"
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    patch|minor|major) bump="$arg" ;;
    [0-9]*.[0-9]*.[0-9]*) bump="$arg" ;;
    *) echo "Usage: bash release.sh [patch|minor|major|X.Y.Z] [--dry-run]" >&2; exit 1 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

current=$(sed -nE 's/.*"version": *"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' "$MANIFEST")
[ -n "$current" ] || die "could not read version from $MANIFEST"

IFS=. read -r major minor patch <<<"$current"
case "$bump" in
  major) new="$((major + 1)).0.0" ;;
  minor) new="$major.$((minor + 1)).0" ;;
  patch) new="$major.$minor.$((patch + 1))" ;;
  *)     new="$bump" ;;
esac
[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid version: $new"
tag="v$new"

[ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] || die "not on $BRANCH"
[ -z "$(git status --porcelain)" ] || die "working tree is not clean, commit or stash first"
git fetch --quiet --tags "$REMOTE"
[ -z "$(git rev-list "HEAD..$REMOTE/$BRANCH")" ] || die "$BRANCH is behind $REMOTE/$BRANCH, pull first"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists"

echo "Releasing $current -> $new ($tag)"
if $dry_run; then
  echo "Dry run, nothing changed."
  exit 0
fi

sed -i -E "s/(\"version\": *\")[0-9]+\.[0-9]+\.[0-9]+(\")/\1$new\2/" "$MANIFEST"
git add "$MANIFEST"
git commit -q -m "Release $tag"
git tag "$tag"
git push "$REMOTE" "$BRANCH" "$tag"

url=$(git remote get-url "$REMOTE")
echo "Pushed $tag. The release will appear at ${url%.git}/releases/tag/$tag"
