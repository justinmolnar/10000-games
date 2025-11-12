#!/usr/bin/env python3
"""
PixelLab Batch Sprite Generator - Pixflux API Version
Fully autonomous sprite generation using REST API (no MCP dependency)

Uses /generate-image-pixflux endpoint for simple, fast sprite generation
"""

import json
import time
import os
import sys
import requests
import base64
from pathlib import Path
from datetime import datetime, timezone

# PixelLab API Configuration
PIXELLAB_API_BASE = "https://api.pixellab.ai/v1"
API_KEY = "bce24ab1-13bd-4763-a6aa-5ddc8736c092"  # User's API key

def load_session_config(filepath):
    """Load and parse session configuration JSON"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            config = json.load(f)
        print(f"[OK] Loaded config: {filepath}")
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

    print("[OK] Config validation passed")
    return True

def create_output_folder(folder_path):
    """Create output folder if it doesn't exist"""
    try:
        Path(folder_path).mkdir(parents=True, exist_ok=True)
        print(f"[OK] Output folder ready: {folder_path}")
        return True
    except Exception as e:
        print(f"[ERROR] Could not create folder {folder_path}: {e}")
        return False

def generate_sprite_pixflux(sprite_id, prompt, params):
    """
    Generate sprite using PixelLab Pixflux API
    Returns: (success, image_base64, generation_time) tuple
    """
    print(f"  +- Generating sprite via Pixflux API...")
    print(f"  |  Prompt: {prompt}")

    # Build request payload
    payload = {
        "description": prompt,
        "image_size": {
            "width": params.get('width', 32),
            "height": params.get('height', 32)
        },
        "no_background": True,
        "outline": params.get('outline', 'single color outline'),
        "shading": params.get('shading', 'basic shading'),
        "detail": params.get('detail', 'medium detail'),
        "view": params.get('view', 'high top-down')
    }

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    start_time = time.time()

    try:
        response = requests.post(
            f"{PIXELLAB_API_BASE}/generate-image-pixflux",
            headers=headers,
            json=payload,
            timeout=60
        )
        response.raise_for_status()

        generation_time = time.time() - start_time
        data = response.json()

        if 'image' in data and 'base64' in data['image']:
            print(f"  +- Complete! ({int(generation_time)}s)")
            return True, data['image']['base64'], generation_time
        else:
            print(f"  +- [ERROR] No image in response")
            return False, None, generation_time

    except requests.exceptions.RequestException as e:
        generation_time = time.time() - start_time
        print(f"  +- [ERROR] API request failed: {e}")
        return False, None, generation_time

def save_sprite(image_base64, output_path):
    """
    Decode base64 image and save to file
    Returns: (success, file_size) tuple
    """
    print(f"  +- Saving sprite...")
    print(f"  |  Path: {output_path}")

    try:
        image_data = base64.b64decode(image_base64)

        with open(output_path, 'wb') as f:
            f.write(image_data)

        file_size = os.path.getsize(output_path)

        if file_size > 0:
            print(f"  +- Saved: {output_path} ({file_size} bytes)")
            return True, file_size
        else:
            print(f"  +- [ERROR] File is empty")
            return False, 0

    except Exception as e:
        print(f"  +- [ERROR] Failed to save: {e}")
        return False, 0

def generate_single_sprite(sprite_config, group_config):
    """
    Generate a single sprite: request → decode → save
    Returns: (success, metadata) tuple
    """
    sprite_id = sprite_config['id']
    prompt = sprite_config['prompt']
    output_folder = group_config['output_folder']

    # Merge default params with sprite-specific params
    params = group_config.get('default_params', {}).copy()
    if 'params' in sprite_config:
        params.update(sprite_config['params'])

    # Build output path
    output_path = os.path.join(output_folder, f"{sprite_id}.png")

    # Generate sprite
    success, image_base64, generation_time = generate_sprite_pixflux(sprite_id, prompt, params)

    if not success:
        return False, None

    # Save sprite
    save_success, file_size = save_sprite(image_base64, output_path)

    if save_success:
        metadata = {
            "id": sprite_id,
            "file_path": output_path,
            "prompt": prompt,
            "params": params,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "generation_time_seconds": int(generation_time),
            "size": f"{params.get('width', 32)}x{params.get('height', 32)}",
            "file_size_bytes": file_size,
            "status": "success",
            "review_flags": []
        }
        return True, metadata
    else:
        return False, None

def run_session(config_filepath):
    """Run complete generation session"""
    print("=" * 60)
    print("PixelLab Batch Sprite Generator - Pixflux API")
    print("=" * 60)
    print()

    # Load and validate config
    config = load_session_config(config_filepath)
    if not validate_config(config):
        sys.exit(1)

    session_name = config['session_name']
    print(f"Session: {session_name}")
    print()

    # Count total sprites
    total_sprites = sum(len(group['sprites']) for group in config['sprite_groups'])
    print(f"Total sprites to generate: {total_sprites}")
    print()

    # Process each sprite group
    current_sprite = 0
    session_start = time.time()
    session_metadata = {
        "session_name": session_name,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "total_sprites": total_sprites,
        "generated": [],
        "failed": []
    }

    for group in config['sprite_groups']:
        group_name = group['name']
        output_folder = group['output_folder']

        print(f"--- Sprite Group: {group_name} ---")
        print(f"Output folder: {output_folder}")
        print()

        # Create output folder
        if not create_output_folder(output_folder):
            print(f"[ERROR] Skipping group '{group_name}' due to folder creation failure")
            continue

        # Process each sprite in group
        for sprite in group['sprites']:
            current_sprite += 1
            sprite_id = sprite['id']

            print(f"[{current_sprite}/{total_sprites}] {sprite_id}")

            # Generate sprite
            success, metadata = generate_single_sprite(sprite, group)

            if success:
                session_metadata['generated'].append(metadata)
            else:
                session_metadata['failed'].append({
                    "id": sprite_id,
                    "prompt": sprite['prompt'],
                    "error": "Generation or save failed"
                })

            print()

            # Safety delay between sprites (avoid rate limiting)
            if current_sprite < total_sprites:
                print("  (Safety delay: 3s)")
                time.sleep(3)
                print()

    # Session complete
    session_metadata['completed_at'] = datetime.now(timezone.utc).isoformat()
    total_time = time.time() - session_start

    print("=" * 60)
    print("Session Complete")
    print("=" * 60)
    print(f"[OK] {len(session_metadata['generated'])} sprites generated successfully")
    print(f"[ERROR] {len(session_metadata['failed'])} sprites failed")
    print(f"Total time: {int(total_time // 60)}m {int(total_time % 60)}s")

    if session_metadata['failed']:
        print("\nFailed sprites:")
        for failed in session_metadata['failed']:
            print(f"  - {failed['id']}: {failed['error']}")

    # Save session metadata
    metadata_path = f"session_{session_name}_metadata.json"
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(session_metadata, f, indent=2)
    print(f"\n[OK] Session metadata saved: {metadata_path}")

    # Trigger review (Phase 4)
    print("\n" + "=" * 60)
    print("=== REVIEW READY ===")
    print("=" * 60)
    print(f"Session: {session_name}")
    print(f"Sprites generated: {len(session_metadata['generated'])}")
    print(f"Sprites failed: {len(session_metadata['failed'])}")
    print(f"Metadata file: {metadata_path}")
    print("\nTo review sprites, tell Claude Code:")
    print(f'  "review sprites from session {session_name}"')
    print("=" * 60)

    return session_metadata

def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python pixellab_batch_generator_pixflux.py <config_file.json>")
        print("\nExample:")
        print("  python pixellab_batch_generator_pixflux.py assets/data/sprite_generation_sessions/session_00_test.json")
        sys.exit(1)

    config_filepath = sys.argv[1]

    if not os.path.exists(config_filepath):
        print(f"[ERROR] Config file not found: {config_filepath}")
        sys.exit(1)

    run_session(config_filepath)

if __name__ == "__main__":
    main()
