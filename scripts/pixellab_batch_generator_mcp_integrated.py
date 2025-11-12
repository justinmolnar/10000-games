#!/usr/bin/env python3
"""
PixelLab Batch Sprite Generator - MCP Integrated Version
This script is executed BY Claude Code, which makes the actual MCP calls
"""

import json
import sys
import os

def load_session_config(filepath):
    """Load and parse session configuration JSON"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            config = json.load(f)
        return config
    except FileNotFoundError:
        print(f"[ERROR] Config file not found: {filepath}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON in config file: {e}")
        sys.exit(1)

def validate_config(config):
    """Validate session config structure"""
    required_fields = ['session_name', 'sprite_type', 'sprite_groups']

    for field in required_fields:
        if field not in config:
            print(f"[ERROR] Missing required field '{field}' in config")
            return False

    if not isinstance(config['sprite_groups'], list) or len(config['sprite_groups']) == 0:
        print(f"[ERROR] 'sprite_groups' must be a non-empty array")
        return False

    for idx, group in enumerate(config['sprite_groups']):
        if 'name' not in group:
            print(f"[ERROR] Sprite group {idx} missing 'name'")
            return False
        if 'output_folder' not in group:
            print(f"[ERROR] Sprite group '{group['name']}' missing 'output_folder'")
            return False
        if 'sprites' not in group or not isinstance(group['sprites'], list):
            print(f"[ERROR] Sprite group '{group['name']}' missing 'sprites' array")
            return False

        for sprite_idx, sprite in enumerate(group['sprites']):
            if 'id' not in sprite:
                print(f"[ERROR] Sprite {sprite_idx} in group '{group['name']}' missing 'id'")
                return False
            if 'prompt' not in sprite:
                print(f"[ERROR] Sprite '{sprite['id']}' missing 'prompt'")
                return False

    return True

def generate_mcp_commands(config):
    """
    Generate MCP commands for Claude Code to execute
    Returns a list of generation tasks
    """
    tasks = []

    for group in config['sprite_groups']:
        group_name = group['name']
        output_folder = group['output_folder']
        default_params = group.get('default_params', {})

        for sprite in group['sprites']:
            sprite_id = sprite['id']
            prompt = sprite['prompt']

            # Merge default params with sprite-specific params
            params = default_params.copy()
            if 'params' in sprite:
                params.update(sprite['params'])

            # Build output path
            output_path = os.path.join(output_folder, f"{sprite_id}.png")

            task = {
                "sprite_id": sprite_id,
                "group_name": group_name,
                "output_folder": output_folder,
                "output_path": output_path,
                "prompt": prompt,
                "params": params,
                "notes": sprite.get('notes', '')
            }
            tasks.append(task)

    return tasks

def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python pixellab_batch_generator_mcp_integrated.py <config_file.json>")
        sys.exit(1)

    config_filepath = sys.argv[1]

    if not os.path.exists(config_filepath):
        print(f"[ERROR] Config file not found: {config_filepath}")
        sys.exit(1)

    # Load and validate config
    config = load_session_config(config_filepath)
    if not validate_config(config):
        sys.exit(1)

    # Generate task list
    tasks = generate_mcp_commands(config)

    # Output as JSON for Claude Code to process
    output = {
        "session_name": config['session_name'],
        "total_sprites": len(tasks),
        "tasks": tasks
    }

    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
