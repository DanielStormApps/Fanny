#!/usr/bin/env python3
"""
validate_faq.py - Validate FAQ article JSON files against the schema shape and cross-locale rules.

Usage:
    python validate_faq.py [directory]

The directory holds one <locale>.lproj folder per locale, each with a faq-articles.json.
If no directory is provided, uses the current working directory.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

# --------------------------------------------------------------------------- #
#  Constants                                                                  #
# --------------------------------------------------------------------------- #

FILE_NAME: str = 'faq-articles.json'

SOURCE_LOCALE: str = 'en'

BLOCK_TYPES: Set[str] = {'paragraph', 'bold', 'numberedList', 'bulletList', 'navigationLink', 'image'}

# Mirrors FAQDestination in FAQArticle.swift.
DESTINATIONS: Set[str] = {
    'settingsGeneral',
    'settingsMenuBar',
    'settingsFloatingWindow',
    'settingsSensors',
    'settingsAppearance',
    'settingsPrivacy',
    'contact',
    'positive',
}

SYMBOL_PATTERN: re.Pattern = re.compile(r'^[a-z0-9]+(\.[a-z0-9]+)*$')

DASH_CHARACTERS: Tuple[str, str] = ('\u2014', '\u2013')

SECTION_FIELDS: Set[str] = {'id', 'title', 'articles'}
ARTICLE_REQUIRED_FIELDS: Set[str] = {'id', 'title', 'lastUpdated', 'content'}
ARTICLE_FIELDS: Set[str] = ARTICLE_REQUIRED_FIELDS | {'symbol'}

# --------------------------------------------------------------------------- #
#  Validation Results                                                         #
# --------------------------------------------------------------------------- #


class ValidationResult:
    """Holds validation errors and warnings."""

    def __init__(self) -> None:
        self.errors: List[str] = []
        self.warnings: List[str] = []

    def add_error(self, message: str) -> None:
        self.errors.append(message)

    def add_warning(self, message: str) -> None:
        self.warnings.append(message)

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def print_summary(self) -> None:
        if self.errors:
            print(f'\n--- ERRORS ({len(self.errors)}) ---')
            for error in self.errors:
                print(f'  x {error}')

        if self.warnings:
            print(f'\n--- WARNINGS ({len(self.warnings)}) ---')
            for warning in self.warnings:
                print(f'  ! {warning}')

        if self.is_valid and not self.warnings:
            print('\nAll validations passed!')
        elif self.is_valid:
            print(f'\nValid with {len(self.warnings)} warning(s)')
        else:
            print(f'\nValidation failed with {len(self.errors)} error(s)')


# --------------------------------------------------------------------------- #
#  Validation Functions                                                       #
# --------------------------------------------------------------------------- #


def is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and len(value) > 0


def validate_block(block: Any, prefix: str, locale: str, result: ValidationResult) -> None:
    """Validate one content block against the schema."""
    if not isinstance(block, dict):
        result.add_error(f'{prefix}: Must be an object')
        return

    block_type: Any = block.get('type')
    if block_type not in BLOCK_TYPES:
        result.add_error(f'{prefix}: Invalid block type "{block_type}"')
        return

    if block_type in ('paragraph', 'bold'):
        required: Set[str] = {'type', 'text'}
    elif block_type in ('numberedList', 'bulletList'):
        required = {'type', 'items'}
    elif block_type == 'navigationLink':
        required = {'type', 'text', 'destination'}
    else:
        required = {'type', 'name'}

    for field in required - set(block.keys()):
        result.add_error(f'{prefix}: Missing required field "{field}"')

    for field in set(block.keys()) - required:
        result.add_error(f'{prefix}: Extra field "{field}" for type "{block_type}"')

    if 'text' in required and 'text' in block:
        if not is_non_empty_string(block['text']):
            result.add_error(f'{prefix}: "text" must be a non-empty string')

    if 'items' in required and 'items' in block:
        items: Any = block['items']
        if not isinstance(items, list) or len(items) == 0:
            result.add_error(f'{prefix}: "items" must be a non-empty array')
        else:
            for index, item in enumerate(items):
                if not is_non_empty_string(item):
                    result.add_error(f'{prefix}: items[{index}] must be a non-empty string')

    if block_type == 'navigationLink' and 'destination' in block:
        if block['destination'] not in DESTINATIONS:
            result.add_error(f'{prefix}: Unsupported destination "{block["destination"]}"')

    if block_type == 'image' and 'name' in block:
        if not is_non_empty_string(block['name']):
            result.add_error(f'{prefix}: "name" must be a non-empty string')


def validate_article(article: Any, prefix: str, locale: str, result: ValidationResult) -> None:
    """Validate one article against the schema."""
    if not isinstance(article, dict):
        result.add_error(f'{prefix}: Must be an object')
        return

    for field in ARTICLE_REQUIRED_FIELDS - set(article.keys()):
        result.add_error(f'{prefix}: Missing required field "{field}"')

    for field in set(article.keys()) - ARTICLE_FIELDS:
        result.add_error(f'{prefix}: Extra field "{field}"')

    for field in ('id', 'title'):
        if field in article and not is_non_empty_string(article[field]):
            result.add_error(f'{prefix}: "{field}" must be a non-empty string')

    if 'lastUpdated' in article:
        try:
            date.fromisoformat(str(article['lastUpdated']))
        except ValueError:
            result.add_error(f'{prefix}: "lastUpdated" must be an ISO date (YYYY-MM-DD)')

    if 'symbol' in article:
        symbol: Any = article['symbol']
        if not is_non_empty_string(symbol) or not SYMBOL_PATTERN.match(symbol):
            result.add_error(f'{prefix}: Invalid SF Symbol name "{symbol}"')

    content: Any = article.get('content')
    if not isinstance(content, list) or len(content) == 0:
        result.add_error(f'{prefix}: "content" must be a non-empty array')
    else:
        for index, block in enumerate(content):
            validate_block(block, f'{prefix} content[{index}]', locale, result)


def validate_file(data: Any, locale: str, result: ValidationResult) -> bool:
    """Validate one locale file. Returns False if it has any error, so the structure comparison never reads a bad shape."""
    error_count: int = len(result.errors)
    return validate_file_shape(data, locale, result) and len(result.errors) == error_count


def validate_file_shape(data: Any, locale: str, result: ValidationResult) -> bool:
    """Validate one locale file against the schema. Returns False if the structure is unusable."""
    name: str = f'{locale}.lproj/{FILE_NAME}'

    if not isinstance(data, dict):
        result.add_error(f'{name}: Root must be an object')
        return False

    version: Any = data.get('schemaVersion')
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        result.add_error(f'{name}: "schemaVersion" must be an integer >= 1')

    sections: Any = data.get('sections')
    if not isinstance(sections, list) or len(sections) == 0:
        result.add_error(f'{name}: "sections" must be a non-empty array')
        return False

    seen_ids: Set[str] = set()

    for s_index, section in enumerate(sections):
        prefix: str = f'{name} sections[{s_index}]'

        if not isinstance(section, dict):
            result.add_error(f'{prefix}: Must be an object')
            return False

        for field in SECTION_FIELDS - set(section.keys()):
            result.add_error(f'{prefix}: Missing required field "{field}"')

        for field in set(section.keys()) - SECTION_FIELDS:
            result.add_error(f'{prefix}: Extra field "{field}"')

        for field in ('id', 'title'):
            if field in section and not is_non_empty_string(section[field]):
                result.add_error(f'{prefix}: "{field}" must be a non-empty string')

        articles: Any = section.get('articles')
        if not isinstance(articles, list) or len(articles) == 0:
            result.add_error(f'{prefix}: "articles" must be a non-empty array')
            return False

        for a_index, article in enumerate(articles):
            validate_article(article, f'{prefix} articles[{a_index}]', locale, result)

            if isinstance(article, dict) and isinstance(article.get('id'), str):
                if article['id'] in seen_ids:
                    result.add_error(f'{name}: Duplicate article id "{article["id"]}"')
                seen_ids.add(article['id'])

    return True


def check_dashes(data: Any, locale: str, result: ValidationResult) -> None:
    """Em and en dashes are not allowed in the English source. They are warned about in translations."""
    text: str = json.dumps(data, ensure_ascii=False)
    if any(dash in text for dash in DASH_CHARACTERS):
        message: str = f'{locale}.lproj/{FILE_NAME}: Contains an em or en dash'
        if locale == SOURCE_LOCALE:
            result.add_error(message)
        else:
            result.add_warning(message)


def structure(data: Dict[str, Any]) -> List[Tuple[Any, ...]]:
    """Flatten a file into a comparable shape: ids, symbols, and block structure, without any translated text."""
    shape: List[Tuple[Any, ...]] = []

    for section in data['sections']:
        shape.append(('section', section['id'], len(section['articles'])))

        for article in section['articles']:
            shape.append(('article', article['id'], article.get('symbol'), article['lastUpdated'], len(article['content'])))

            for block in article['content']:
                block_type: str = block['type']
                if block_type in ('numberedList', 'bulletList'):
                    shape.append((block_type, len(block['items'])))
                elif block_type == 'navigationLink':
                    shape.append((block_type, block['destination']))
                elif block_type == 'image':
                    shape.append((block_type, block['name']))
                else:
                    shape.append((block_type,))

    return shape


def validate_against_source(source: Dict[str, Any], other: Dict[str, Any], locale: str, result: ValidationResult) -> None:
    """Every locale keeps the English ids, symbols, destinations, and block structure."""
    source_shape: List[Tuple[Any, ...]] = structure(source)
    other_shape: List[Tuple[Any, ...]] = structure(other)

    if source_shape == other_shape:
        return

    for index in range(max(len(source_shape), len(other_shape))):
        expected: Any = source_shape[index] if index < len(source_shape) else None
        actual: Any = other_shape[index] if index < len(other_shape) else None
        if expected != actual:
            result.add_error(f'{locale}.lproj/{FILE_NAME}: Structure differs from {SOURCE_LOCALE} at entry {index}: expected {expected}, found {actual}')
            return


# --------------------------------------------------------------------------- #
#  Main Validation                                                            #
# --------------------------------------------------------------------------- #


def validate_directory(directory: Path) -> ValidationResult:
    """Run all validations on the locale folders in directory."""
    result: ValidationResult = ValidationResult()

    files: Dict[str, Path] = {}
    for folder in sorted(directory.glob('*.lproj')):
        path: Path = folder / FILE_NAME
        if path.is_file():
            files[folder.name[:-len('.lproj')]] = path
        else:
            result.add_error(f'{folder.name}: Missing {FILE_NAME}')

    if SOURCE_LOCALE not in files:
        result.add_error(f'No {SOURCE_LOCALE}.lproj/{FILE_NAME} found in {directory}')
        return result

    print(f'Found {len(files)} locale file(s): {", ".join(files.keys())}')

    loaded: Dict[str, Dict[str, Any]] = {}

    for locale, path in files.items():
        try:
            with path.open(encoding='utf-8') as handle:
                data: Any = json.load(handle)
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            result.add_error(f'{locale}.lproj/{FILE_NAME}: Invalid JSON - {error}')
            continue

        if validate_file(data, locale, result):
            loaded[locale] = data

        check_dashes(data, locale, result)

    source: Dict[str, Any] = loaded.get(SOURCE_LOCALE, {})

    if source:
        article_count: int = sum(len(section['articles']) for section in source['sections'])
        print(f'Articles in {SOURCE_LOCALE}: {article_count}')

        for locale, data in loaded.items():
            if locale != SOURCE_LOCALE:
                validate_against_source(source, data, locale, result)

    return result


def main() -> int:
    """Entry point."""
    directory: Path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()

    if not directory.is_dir():
        print(f'Error: {directory} is not a directory')
        return 1

    print(f'Validating FAQ files in: {directory}\n')

    result: ValidationResult = validate_directory(directory)
    result.print_summary()

    return 0 if result.is_valid else 1


if __name__ == '__main__':
    sys.exit(main())
