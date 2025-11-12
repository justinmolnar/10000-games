#!/usr/bin/env python3
"""
Migrate dodge_game.lua to use VariantLoader pattern.
Converts:
    local param = (runtimeCfg...) or DEFAULT
    if self.variant and self.variant.param_name then
        param = self.variant.param_name
    end
To:
    local param = loader:get('param_name', DEFAULT)
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

        # Pattern 1: local var = (runtimeCfg...) or DEFAULT
        # Followed by: if self.variant and self.variant.param_name then
        # Followed by: var = self.variant.param_name
        # Followed by: end

        match = re.match(r'(\s+)local (\w+) = \(runtimeCfg.*?\) or (.+)', line)
        if match and i + 3 < len(lines):
            indent = match.group(1)
            var_name = match.group(2)
            default_value = match.group(3)

            # Check next 3 lines match the pattern
            next1 = lines[i + 1]
            next2 = lines[i + 2]
            next3 = lines[i + 3]

            # Try to find the variant parameter name in the if check
            if_match = re.match(rf'{indent}if self\.variant and self\.variant\.(\w+)', next1)
            if if_match:
                param_name = if_match.group(1)
                assign_match = re.match(rf'{indent}    {var_name} = self\.variant\.{param_name}', next2)
                end_match = re.match(rf'{indent}end', next3)

                if assign_match and end_match:
                    # Replace 4 lines with 1 line
                    new_line = f"{indent}local {var_name} = loader:get('{param_name}', {default_value})"
                    new_lines.append(new_line)
                    i += 4  # Skip the next 3 lines
                    continue

        # Pattern 2: local var = DEFAULT (no runtime config fallback)
        # Followed by: if self.variant and self.variant.param_name ~= nil then
        # Followed by: var = self.variant.param_name
        # Followed by: end

        match2 = re.match(r'(\s+)local (\w+) = (.+?)$', line)
        if match2 and i + 3 < len(lines):
            # Make sure it's not a function call or complex expression
            default_val = match2.group(3)
            # Strip inline comments
            if '--' in default_val:
                default_val = default_val.split('--')[0].strip()
            if '(' not in default_val or default_val.startswith('"'):
                indent = match2.group(1)
                var_name = match2.group(2)
                default_value = default_val

                # Check next 3 lines match the pattern
                next1 = lines[i + 1]
                next2 = lines[i + 2]
                next3 = lines[i + 3]

                # Try to find the variant parameter name in the if check
                if_match = re.match(rf'{indent}if self\.variant and self\.variant\.(\w+)', next1)
                if if_match:
                    param_name = if_match.group(1)
                    assign_match = re.match(rf'{indent}    {var_name} = self\.variant\.{param_name}', next2)
                    end_match = re.match(rf'{indent}end', next3)

                    if assign_match and end_match:
                        # Replace 4 lines with 1 line
                        new_line = f"{indent}local {var_name} = loader:get('{param_name}', {default_value})"
                        new_lines.append(new_line)
                        i += 4  # Skip the next 3 lines
                        continue

        new_lines.append(line)
        i += 1

    return '\n'.join(new_lines)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python migrate_dodge_to_variant_loader.py <file>")
        sys.exit(1)

    filepath = sys.argv[1]
    result = migrate_file(filepath)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(result)

    print(f"Migrated {filepath}")
