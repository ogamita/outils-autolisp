#!/usr/bin/env python3
"""Build an AutoLISP reference alist from the Autodesk online reference."""

from __future__ import annotations

import argparse
import concurrent.futures
import html
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT_GUID = "GUID-4CEE5072-8817-4920-8A2D-7060F5E16547"
BASE_URL = "https://help.autodesk.com/cloudhelp/2023/ENU/AutoCAD-AutoLISP-Reference/files"
ROOT_URL = f"{BASE_URL}/{ROOT_GUID}.htm"
USER_AGENT = "Codex AutoLISP Ref Builder/1.0"
SECTION_SUFFIX = " Functions Reference (AutoLISP)"
CACHE_DIR = Path("/tmp/autolisp-ref-cache")
SCRIPT_PATH = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT_PATH.parents[2]
DEFAULT_OUTPUT = PROJECT_ROOT / "autolisp-doc" / "src" / "autolisp-ref.lsp"
SOURCE_LABEL_RE = re.compile(r"^(?P<name>.+?) \((?P<source>AutoLISP(?:/[^)]+)?)\)$")


def fetch(url: str, cache_dir: Path) -> str:
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / url.rsplit("/", 1)[-1]
    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8")

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read().decode("utf-8")
            cache_file.write_text(data, encoding="utf-8")
            return data
        except urllib.error.URLError as exc:
            last_error = exc
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError(f"failed to fetch {url}: {last_error}") from last_error


def parse_xml(text: str) -> ET.Element:
    text = text.lstrip("\ufeff")
    text = re.sub(r"<!DOCTYPE[^>]*>", "", text, count=1, flags=re.IGNORECASE)
    return ET.fromstring(text)


def collapse_ws(text: str) -> str:
    text = html.unescape(text).replace("\xa0", " ")
    return re.sub(r"\s+", " ", text).strip()


def pre_text(element: ET.Element) -> str:
    text = "".join(element.itertext())
    text = html.unescape(text).replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in text.split("\n")]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def text_of(element: ET.Element) -> str:
    return collapse_ws("".join(element.itertext()))


def find_body(root: ET.Element) -> ET.Element:
    body = root.find(".//div[@class='body referencebody-adsk']")
    if body is None:
        body = root.find(".//div[@class='body conbody']")
    if body is None:
        raise RuntimeError("unable to locate page body")
    return body


def collect_links(container: ET.Element) -> list[tuple[str, str, str]]:
    links = []
    for anchor in container.findall(".//a[@class='xref']"):
        href = anchor.attrib.get("href", "")
        if not href.endswith(".htm"):
            continue
        name = collapse_ws("".join(anchor.itertext()))
        desc = collapse_ws(anchor.attrib.get("title", ""))
        links.append((href, name, desc))
    return links


def body_sections(body: ET.Element) -> list[ET.Element]:
    return [child for child in body if child.tag == "div" and child.attrib.get("class") == "section"]


def section_title(section: ET.Element) -> str:
    title = section.find("./h2[@class='title sectiontitle']")
    return text_of(title) if title is not None else ""


def parse_root_links(root: ET.Element) -> tuple[list[tuple[str, str, str]], list[tuple[str, str]]]:
    body = find_body(root)
    alpha_links: list[tuple[str, str, str]] = []
    feature_links: list[tuple[str, str]] = []
    for section in body_sections(body):
        title = section_title(section)
        if title == "Alphabetic List":
            alpha_links = collect_links(section)
        elif title == "Feature List":
            feature_links = [
                (href, name)
                for href, name, _desc in collect_links(section)
            ]
    return alpha_links, feature_links


def normalize_feature_name(title: str) -> str:
    if title.endswith(SECTION_SUFFIX):
        return title[: -len(SECTION_SUFFIX)]
    return title.replace(" (AutoLISP)", "")


def parse_index_page(root: ET.Element) -> list[tuple[str, str, str]]:
    body = find_body(root)
    return collect_links(body)


def parse_feature_page(root: ET.Element) -> tuple[str, list[tuple[str, str]]]:
    title = text_of(root.find(".//h1"))
    feature_name = normalize_feature_name(title)
    body = find_body(root)
    items: list[tuple[str, str]] = []
    for anchor in body.findall(".//a[@class='xref']"):
        href = anchor.attrib.get("href", "")
        if not href.endswith(".htm"):
            continue
        text = collapse_ws("".join(anchor.itertext()))
        match = re.match(r"^\(([^ ]+)", text)
        if match:
            func_name = match.group(1)
        else:
            func_name = text
        items.append((href, func_name))
    return feature_name, items


def labeled_dl_text(section: ET.Element) -> list[tuple[str, str]]:
    pairs = []
    for dl in section.findall(".//dl"):
        children = list(dl)
        index = 0
        while index < len(children):
            child = children[index]
            if child.tag == "dt":
                label = text_of(child)
                value_parts = []
                index += 1
                while index < len(children) and children[index].tag != "dt":
                    value = children[index]
                    if value.tag == "dd":
                        text = section_fragment_text(value)
                        if text:
                            value_parts.append(text)
                    index += 1
                pairs.append((label, "\n".join(part for part in value_parts if part)))
                continue
            index += 1
    return pairs


def section_fragment_text(element: ET.Element) -> str:
    pieces: list[str] = []
    for child in list(element):
        if child.tag == "p":
            text = text_of(child)
            if text:
                pieces.append(text)
        elif child.tag == "pre":
            code = pre_text(child)
            if code:
                pieces.append(code)
        elif child.tag == "ul":
            items = list_text(child)
            if items:
                pieces.extend(items)
        elif child.tag == "div" and child.attrib.get("class", "").startswith("note"):
            note = text_of(child)
            if note:
                pieces.append(note)
        elif child.tag == "div" and child.attrib.get("class") == "section":
            nested_title = section_title(child)
            nested_text = generic_section_text(child)
            if nested_text:
                if nested_title:
                    pieces.append(nested_title)
                pieces.append(nested_text)
    if not pieces:
        text = text_of(element)
        return text
    return "\n".join(pieces).strip()


def list_text(element: ET.Element, bullet: str = "- ") -> list[str]:
    lines: list[str] = []
    for child in list(element):
        if child.tag == "p":
            text = text_of(child)
            if text:
                lines.append(text)
        elif child.tag == "li":
            li_text = li_to_text(child)
            if li_text:
                for line in li_text.split("\n"):
                    prefix = bullet if not line.startswith(bullet) else ""
                    lines.append(f"{prefix}{line}" if line else line)
    return lines


def li_to_text(element: ET.Element) -> str:
    parts: list[str] = []
    head = collapse_ws(element.text or "")
    if head:
        parts.append(head)
    for child in list(element):
        if child.tag == "p":
            text = text_of(child)
            if text:
                parts.append(text)
        elif child.tag == "pre":
            code = pre_text(child)
            if code:
                parts.append(code)
        elif child.tag == "ul":
            nested = list_text(child, bullet="  - ")
            if nested:
                parts.extend(nested)
        else:
            text = text_of(child)
            if text:
                parts.append(text)
        tail = collapse_ws(child.tail or "")
        if tail:
            parts.append(tail)
    if not parts:
        return text_of(element)
    return "\n".join(parts).strip()


def generic_section_text(section: ET.Element) -> str:
    pieces: list[str] = []
    for child in list(section):
        if child.tag == "h2":
            continue
        if child.tag == "p":
            text = text_of(child)
            if text:
                pieces.append(text)
        elif child.tag == "pre":
            code = pre_text(child)
            if code:
                pieces.append(code)
        elif child.tag == "ul":
            items = list_text(child)
            if items:
                pieces.extend(items)
        elif child.tag == "dl":
            for label, value in labeled_dl_text(section):
                if value:
                    pieces.append(f"{label}\n{value}")
                else:
                    pieces.append(label)
            break
        elif child.tag == "div" and child.attrib.get("class") == "section":
            nested_title = section_title(child)
            nested_text = generic_section_text(child)
            if nested_text:
                if nested_title:
                    pieces.append(nested_title)
                pieces.append(nested_text)
        elif child.tag == "div" and child.attrib.get("class", "").startswith("note"):
            note = text_of(child)
            if note:
                pieces.append(note)
    return "\n".join(piece for piece in pieces if piece).strip()


def parse_arguments(signature_section: ET.Element) -> list[tuple[str, str]]:
    arguments = []
    for label, value in labeled_dl_text(signature_section):
        if label:
            arguments.append((label, value))
    return arguments


def parse_history(section: ET.Element) -> str:
    groups: list[str] = []
    current_heading = None
    for child in list(section):
        if child.tag == "h2":
            continue
        if child.tag == "ul":
            items = list_text(child)
            if items:
                if current_heading:
                    groups.append(current_heading)
                groups.extend(items)
                current_heading = None
        elif child.tag == "p":
            text = text_of(child)
            if text:
                current_heading = text
        elif child.tag == "div" and child.attrib.get("class", "").startswith("note"):
            note = text_of(child)
            if note:
                groups.append(note)
    return "\n".join(groups).strip()


def parse_examples(section: ET.Element) -> str:
    blocks: list[str] = []
    for child in list(section):
        if child.tag == "h2":
            continue
        if child.tag == "pre":
            code = pre_text(child)
            if code:
                blocks.append(code)
        elif child.tag == "p":
            text = text_of(child)
            if text:
                blocks.append(text)
        elif child.tag == "div" and child.attrib.get("class") == "section":
            label = None
            for dt, value in labeled_dl_text(child):
                label = dt
                if label:
                    blocks.append(label)
                if value:
                    blocks.append(value)
            if not list(child.findall(".//dl")):
                nested = generic_section_text(child)
                if nested:
                    blocks.append(nested)
    return "\n\n".join(block for block in blocks if block).strip()


def parse_function_page(root: ET.Element, url: str) -> dict[str, object]:
    body = find_body(root)
    h1 = root.find(".//h1")
    title = text_of(h1) if h1 is not None else ""
    summary = text_of(body.find("./p[@class='shortdesc']")) if body.find("./p[@class='shortdesc']") is not None else ""
    source_match = SOURCE_LABEL_RE.match(title)
    if source_match:
        raw_name = source_match.group("name").strip()
        source_kind = source_match.group("source").strip()
    else:
        raw_name = title.strip()
        source_kind = None

    metadata = {
        "name": raw_name,
        "title": title,
        "summary": summary,
        "url": url,
        "guid": url.rsplit("/", 1)[-1].removesuffix(".htm"),
        "source-kind": source_kind,
        "is-autolisp-function": source_kind is not None,
    }

    supported_platforms = None
    for paragraph in body.findall("./p"):
        text = text_of(paragraph)
        if text.startswith("Supported Platforms:"):
            supported_platforms = text.removeprefix("Supported Platforms:").strip()
            break
    metadata["supported-platforms"] = supported_platforms

    sections = {section_title(section): section for section in body_sections(body)}

    signature_section = sections.get("Signature")
    if signature_section is not None:
        signatures = [
            pre_text(pre)
            for pre in signature_section.findall(".//pre")
            if pre_text(pre)
        ]
        metadata["signature"] = "\n\n".join(signatures) if signatures else None
        metadata["arguments"] = parse_arguments(signature_section)
        if signatures:
            match = re.match(r"^\(([^ \t\n\)]+)", signatures[0])
            if match:
                metadata["name"] = match.group(1)
    else:
        metadata["signature"] = None
        metadata["arguments"] = []

    return_section = sections.get("Return Values")
    metadata["return-values"] = generic_section_text(return_section) if return_section is not None else None

    release_section = sections.get("Release Information")
    metadata["release-information"] = generic_section_text(release_section) if release_section is not None else None

    history_section = sections.get("History")
    metadata["history"] = parse_history(history_section) if history_section is not None else None

    examples_section = sections.get("Examples")
    metadata["examples"] = parse_examples(examples_section) if examples_section is not None else None

    return metadata


def lisp_string(text: str) -> str:
    escaped = (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )
    return f'"{escaped}"'


def emit_string_or_nil(value: object) -> str:
    if not value:
        return "nil"
    return lisp_string(str(value))


def emit_string_list(items: list[str]) -> str:
    if not items:
        return "nil"
    return "(" + " ".join(lisp_string(item) for item in items) + ")"


def emit_arguments(arguments: list[tuple[str, str]]) -> str:
    if not arguments:
        return "nil"
    entries = []
    for name, desc in arguments:
        entries.append(f"({lisp_string(name)} . {emit_string_or_nil(desc)})")
    return "(" + "\n                     ".join(entries) + ")"


def emit_entry(name: str, data: dict[str, object]) -> str:
    feature_groups = sorted(set(data.get("feature-groups", [])))
    alphabetic_group = data.get("alphabetic-group")
    lines = [
        f"({lisp_string(name)} .",
        "    ((name . " + emit_string_or_nil(data.get("name")) + ")",
        "     (title . " + emit_string_or_nil(data.get("title")) + ")",
        "     (summary . " + emit_string_or_nil(data.get("summary")) + ")",
        "     (source-kind . " + emit_string_or_nil(data.get("source-kind")) + ")",
        "     (alphabetic-group . " + emit_string_or_nil(alphabetic_group) + ")",
        "     (feature-groups . " + emit_string_list(feature_groups) + ")",
        "     (supported-platforms . " + emit_string_or_nil(data.get("supported-platforms")) + ")",
        "     (signature . " + emit_string_or_nil(data.get("signature")) + ")",
        "     (arguments . " + emit_arguments(data.get("arguments", [])) + ")",
        "     (return-values . " + emit_string_or_nil(data.get("return-values")) + ")",
        "     (release-information . " + emit_string_or_nil(data.get("release-information")) + ")",
        "     (history . " + emit_string_or_nil(data.get("history")) + ")",
        "     (examples . " + emit_string_or_nil(data.get("examples")) + ")",
        "     (url . " + emit_string_or_nil(data.get("url")) + ")",
        "     (guid . " + emit_string_or_nil(data.get("guid")) + ")))",
    ]
    return "\n".join(lines)


def build_reference(cache_dir: Path) -> dict[str, dict[str, object]]:
    root = parse_xml(fetch(ROOT_URL, cache_dir))
    alpha_links, feature_links = parse_root_links(root)

    index_pages = []
    for href, name, _desc in alpha_links:
        if len(name) == 1 and name.isalpha():
            alpha_group = name.upper()
        else:
            alpha_group = name
        index_pages.append((href, alpha_group))

    function_pages: dict[str, dict[str, object]] = {}
    for href, alpha_group in index_pages:
        url = f"{BASE_URL}/{href}"
        page = parse_xml(fetch(url, cache_dir))
        for func_href, func_name, func_desc in parse_index_page(page):
            func_url = f"{BASE_URL}/{func_href}"
            entry = function_pages.setdefault(
                func_url,
                {
                    "name": func_name,
                    "summary": func_desc or None,
                    "alphabetic-group": alpha_group,
                    "feature-groups": [],
                },
            )
            if not entry.get("name"):
                entry["name"] = func_name
            if func_desc and not entry.get("summary"):
                entry["summary"] = func_desc
            if not entry.get("alphabetic-group"):
                entry["alphabetic-group"] = alpha_group

    for href, _label in feature_links:
        url = f"{BASE_URL}/{href}"
        page = parse_xml(fetch(url, cache_dir))
        feature_name, functions = parse_feature_page(page)
        for func_href, func_name in functions:
            func_url = f"{BASE_URL}/{func_href}"
            entry = function_pages.setdefault(
                func_url,
                {
                    "name": func_name,
                    "summary": None,
                    "alphabetic-group": None,
                    "feature-groups": [],
                },
            )
            groups = entry.setdefault("feature-groups", [])
            if feature_name not in groups:
                groups.append(feature_name)

    def load_function(item: tuple[str, dict[str, object]]) -> tuple[str, dict[str, object]]:
        url, seed = item
        page = parse_xml(fetch(url, cache_dir))
        data = parse_function_page(page, url)
        if not data.get("is-autolisp-function"):
            return "", {}
        data["feature-groups"] = seed.get("feature-groups", [])
        data["alphabetic-group"] = seed.get("alphabetic-group")
        if not data.get("summary"):
            data["summary"] = seed.get("summary")
        if not data.get("name"):
            data["name"] = seed.get("name")
        return data["name"], data

    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as executor:
        items = executor.map(load_function, function_pages.items())
        resolved = {name: data for name, data in items if name}

    return resolved


def write_lisp(reference: dict[str, dict[str, object]], output_path: Path) -> None:
    header = [
        ";;; autolisp-ref.lsp --- Generated AutoLISP reference extracted from Autodesk Help",
        ";;;",
        ";;; Source: https://help.autodesk.com/view/OARX/2023/ENU/?guid=GUID-4CEE5072-8817-4920-8A2D-7060F5E16547",
        ";;; Generated by autolisp-doc/scripts/build_autolisp_ref.py",
        "",
        "(setq *autolisp-reference*",
        "  '(",
    ]
    body = []
    for name in sorted(reference, key=lambda item: item.lower()):
        body.append("    " + emit_entry(name, reference[name]).replace("\n", "\n    "))
    footer = [
        "  ))",
        "",
        "(princ)",
        "",
        ";;; autolisp-ref.lsp ends here",
    ]
    output_path.write_text("\n".join(header + body + footer) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help="Path of the generated AutoLISP file.",
    )
    parser.add_argument(
        "--cache-dir",
        default=str(CACHE_DIR),
        help="Directory used to cache downloaded Autodesk pages.",
    )
    args = parser.parse_args(argv)

    reference = build_reference(Path(args.cache_dir))
    write_lisp(reference, Path(args.output))
    print(f"generated {args.output} with {len(reference)} functions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
