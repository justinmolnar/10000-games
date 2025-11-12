#!/usr/bin/env python3
"""
Migrate game files to use VariantLoader pattern.
Converts:
    self.param = (runtimeCfg and runtimeCfg.x) or DEFAULT
    if self.variant and self.variant.param ~= nil then
        self.param = self.variant.param
    end
To:
    self.param = loader:get('param', DEFAULT)
"""

import re
import sys

def migrate_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    new_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Pattern: self.param = (runtimeCfg...) or DEFAULT
        # Followed by: if self.variant and self.variant.param ~= nil then
        # Followed by: self.param = self.variant.param
        # Followed by: end

        match = re.match(r'(\s+)self\.(\w+) = \(runtimeCfg.*?\) or (.+)', line)
        if match and i + 3 < len(lines):
            indent = match.group(1)
            param_name = match.group(2)
            default_value = match.group(3)

            # Check next 3 lines match the pattern
            next1 = lines[i + 1]
            next2 = lines[i + 2]
            next3 = lines[i + 3]

            # Try both patterns: with "~= nil" and without
            if_match = re.match(rf'{indent}if self\.variant and self\.variant\.{param_name}( ~= nil)? then', next1)
            assign_match = re.match(rf'{indent}    self\.{param_name} = self\.variant\.{param_name}', next2)
            end_match = re.match(rf'{indent}end', next3)

            if if_match and assign_match and end_match:
                # Replace 4 lines with 1 line
                new_line = f"{indent}self.{param_name} = loader:get('{param_name}', {default_value})"
                new_lines.append(new_line)
                i += 4  # Skip the next 3 lines
                continue

        new_lines.append(line)
        i += 1

    return '\n'.join(new_lines)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python migrate_to_variant_loader.py <file>")
        sys.exit(1)

    filepath = sys.argv[1]
    result = migrate_file(filepath)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f"Migrated {filepath}")
