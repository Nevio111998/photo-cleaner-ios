#!/usr/bin/env python3
"""Static checks only. Does NOT replace Xcode compilation or XCTest."""
from pathlib import Path
import xml.etree.ElementTree as ET
from openstep_parser import OpenStepDecoder
from tree_sitter import Language, Parser
import tree_sitter_swift
ROOT = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
errors = []
files = list(ROOT.glob('PhotoCleaner/*.swift')) + list(ROOT.glob('PhotoCleanerTests/*.swift'))
for path in files:
    source = path.read_bytes()
    tree = parser.parse(source)
    def visit(node):
        if node.type == 'ERROR' or node.is_missing:
            errors.append(f'{path.name}:{node.start_point}: {source[node.start_byte:node.end_byte][:100]!r}')
        for child in node.children: visit(child)
    visit(tree.root_node)
project = OpenStepDecoder.ParseFromString((ROOT/'PhotoCleaner.xcodeproj/project.pbxproj').read_text())
objects = project['objects']
assert project['rootObject'] in objects
assert len([x for x in objects.values() if x.get('isa') == 'PBXNativeTarget']) == 2
for obj in objects.values():
    if obj.get('isa') == 'PBXFileReference' and obj.get('lastKnownFileType') == 'sourcecode.swift':
        assert any(p.name == obj['path'] for p in files), obj
ET.parse(ROOT/'PhotoCleaner.xcodeproj/xcshareddata/xcschemes/PhotoCleaner.xcscheme')
assert not errors, '\n'.join(errors)
print(f'PASS: Swift syntax parsed ({len(files)} files); Xcode project and scheme parsed.')
print('NOT RUN: Apple SDK type checking, iOS build, XCTest, device tests.')
