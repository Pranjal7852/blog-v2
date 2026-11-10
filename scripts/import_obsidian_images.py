"""Copy local images referenced by an Obsidian note into Hugo's static assets."""

import hashlib
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

IMAGE_EXTENSIONS = {".avif", ".bmp", ".gif", ".jpeg", ".jpg", ".png", ".svg", ".tif", ".tiff", ".webp"}
OBSIDIAN_IMAGE = re.compile(r"!\[\[([^\]]+)\]\]")
MARKDOWN_IMAGE = re.compile(r"!\[([^\]]*)\]\((<[^>]+>|[^)]+)\)")


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def find_vault_root(source: Path) -> Path:
    for parent in (source.parent, *source.parent.parents):
        if (parent / ".obsidian").is_dir():
            return parent.resolve()
    return source.parent.resolve()


def resolve_image(reference: str, source: Path, vault_root: Path) -> Path:
    reference = unquote(reference.strip()).replace("\\", "/").lstrip("/")
    relative = Path(reference)
    candidates = [source.parent / relative, vault_root / relative]
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved.is_file() and is_within(resolved, vault_root):
            return resolved

    if relative.parent == Path("."):
        matches = [
            path.resolve()
            for path in vault_root.rglob(relative.name)
            if path.is_file()
            and not any(part.startswith(".") for part in path.relative_to(vault_root).parts)
        ]
        if len(matches) == 1:
            return matches[0]
        if len(matches) > 1:
            raise ValueError(f"image name is ambiguous in the vault: {reference}")

    raise ValueError(f"could not find image in the vault: {reference}")


def copy_image(image: Path, repo_root: Path, slug: str, created: list[Path]) -> str:
    safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", image.name).strip("-")
    destination = repo_root / "static" / "images" / f"{slug}-{safe_name}"
    image_data = image.read_bytes()
    if destination.exists():
        digest = hashlib.sha256(image_data).hexdigest()[:10]
        destination = destination.with_name(f"{slug}-{digest}-{safe_name}")
        if destination.exists():
            raise ValueError(f"image destination already exists: {destination}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(image, destination)
    created.append(destination)
    return destination.name


def main() -> int:
    if len(sys.argv) != 6:
        print("Usage: import_obsidian_images.py <source> <target> <repo-root> <slug> <manifest>", file=sys.stderr)
        return 2

    source, target, repo_root, slug, manifest = map(Path, sys.argv[1:])
    source = source.resolve()
    repo_root = repo_root.resolve()
    vault_root = find_vault_root(source)
    created: list[Path] = []
    text = target.read_text(encoding="utf-8")

    def import_obsidian(match: re.Match[str]) -> str:
        value = match.group(1)
        reference, _, alias = value.partition("|")
        reference = reference.split("#", 1)[0].split("^", 1)[0].strip()
        if Path(reference).suffix.lower() not in IMAGE_EXTENSIONS:
            return match.group(0)
        image = resolve_image(reference, source, vault_root)
        filename = copy_image(image, repo_root, slug, created)
        return f"![{alias.strip() or image.stem}](/images/{filename})"

    def import_markdown(match: re.Match[str]) -> str:
        alt = match.group(1)
        raw_reference = match.group(2).strip()
        reference = raw_reference[1:-1] if raw_reference.startswith("<") and raw_reference.endswith(">") else raw_reference
        if (Path(reference).suffix.lower() not in IMAGE_EXTENSIONS
                or urlparse(reference).scheme or reference.startswith("/")):
            return match.group(0)
        image = resolve_image(reference, source, vault_root)
        filename = copy_image(image, repo_root, slug, created)
        return f"![{alt}](/images/{filename})"

    try:
        text = OBSIDIAN_IMAGE.sub(import_obsidian, text)
        text = MARKDOWN_IMAGE.sub(import_markdown, text)
        target.write_text(text, encoding="utf-8")
        Path(manifest).write_text(
            "".join(f"{path.relative_to(repo_root)}\n" for path in created), encoding="utf-8"
        )
    except Exception:
        for path in created:
            path.unlink(missing_ok=True)
        raise

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"Error importing images: {error}", file=sys.stderr)
        raise SystemExit(1)