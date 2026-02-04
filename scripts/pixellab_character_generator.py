#!/usr/bin/env python3
"""
PixelLab Character Generator - Multi-Directional Sprites
Uses /create-character-with-8-directions for consistent multi-angle characters
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
API_KEY = "bce24ab1-13bd-4763-a6aa-5ddc8736c092"

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
    required_fields = ['session_name', 'sprite_groups']

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
        if 'characters' not in group or not isinstance(group['characters'], list):
            print(f"[ERROR] Sprite group '{group['name']}' missing 'characters' array")
            return False

        for char_idx, char in enumerate(group['characters']):
            if 'id' not in char:
                print(f"[ERROR] Character {char_idx} in group '{group['name']}' missing 'id'")
                return False
            if 'prompt' not in char:
                print(f"[ERROR] Character '{char['id']}' missing 'prompt'")
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

def create_character_8dir(char_id, prompt, params):
    """
    Create character with 8 directions via PixelLab API
    Returns: (success, character_id, job_id) tuple
    """
    print(f"  +- Creating 8-direction character...")
    print(f"  |  Prompt: {prompt}")

    # Build request payload
    payload = {
        "description": prompt,
        "image_size": {
            "width": params.get('width', 64),
            "height": params.get('height', 64)
        },
        "no_background": True,
        "outline": params.get('outline', 'single color outline'),
        "shading": params.get('shading', 'basic shading'),
        "detail": params.get('detail', 'medium detail')
    }

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        response = requests.post(
            f"{PIXELLAB_API_BASE}/create-character-with-8-directions",
            headers=headers,
            json=payload,
            timeout=60
        )
        response.raise_for_status()

        data = response.json()
        character_id = data.get('character_id')
        job_id = data.get('background_job_id')

        if character_id and job_id:
            print(f"  +- Job started: {job_id}")
            return True, character_id, job_id
        else:
            print(f"  +- [ERROR] Missing character_id or job_id in response")
            print(f"  |  Response: {data}")
            return False, None, None

    except requests.exceptions.RequestException as e:
        print(f"  +- [ERROR] API request failed: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"  |  Response: {e.response.text}")
        return False, None, None

def poll_job_completion(job_id, poll_interval=5, timeout=300):
    """
    Poll background job until completion
    Returns: (success, result_data) tuple
    """
    print(f"  +- Polling job {job_id}...")
    start_time = time.time()
    elapsed = 0

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    while elapsed < timeout:
        try:
            response = requests.get(
                f"{PIXELLAB_API_BASE}/background-jobs/{job_id}",
                headers=headers,
                timeout=30
            )
            response.raise_for_status()

            data = response.json()
            status = data.get('status')

            print(f"  |  Status: {status} ({int(elapsed)}s)")

            if status == 'completed':
                print(f"  +- Complete! ({int(elapsed)}s total)")
                return True, data
            elif status == 'failed':
                print(f"  +- [ERROR] Job failed: {data.get('error', 'Unknown error')}")
                return False, None

        except requests.exceptions.RequestException as e:
            print(f"  |  [WARN] Poll request failed: {e}")

        time.sleep(poll_interval)
        elapsed = time.time() - start_time

    print(f"  +- [ERROR] TIMEOUT after {timeout}s")
    return False, None

def get_character_images(character_id):
    """
    Get character images after job completion
    Returns: (success, images_data) tuple
    """
    print(f"  +- Fetching character images...")

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        response = requests.get(
            f"{PIXELLAB_API_BASE}/characters/{character_id}",
            headers=headers,
            timeout=30
        )
        response.raise_for_status()

        data = response.json()
        return True, data

    except requests.exceptions.RequestException as e:
        print(f"  +- [ERROR] Failed to get character: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"  |  Response: {e.response.text}")
        return False, None

def save_character_images(images_data, output_folder, char_id):
    """
    Save character direction images to files
    Returns: (success, file_paths) tuple
    """
    print(f"  +- Saving images...")

    file_paths = []
    directions = ['front', 'front_left', 'left', 'back_left', 'back', 'back_right', 'right', 'front_right']

    # Check for images in response
    images = images_data.get('images', {})
    if not images:
        # Try alternate structure
        images = images_data.get('directions', {})

    if not images:
        print(f"  +- [ERROR] No images found in response")
        print(f"  |  Response keys: {images_data.keys()}")
        return False, []

    for direction in directions:
        if direction in images:
            img_data = images[direction]

            # Handle base64 or URL
            if isinstance(img_data, dict) and 'base64' in img_data:
                image_bytes = base64.b64decode(img_data['base64'])
            elif isinstance(img_data, str) and img_data.startswith('data:'):
                # data:image/png;base64,xxxxx format
                base64_str = img_data.split(',')[1]
                image_bytes = base64.b64decode(base64_str)
            elif isinstance(img_data, str):
                # Assume it's a URL
                try:
                    resp = requests.get(img_data, timeout=30)
                    resp.raise_for_status()
                    image_bytes = resp.content
                except Exception as e:
                    print(f"  |  [WARN] Failed to download {direction}: {e}")
                    continue
            else:
                print(f"  |  [WARN] Unknown image format for {direction}")
                continue

            output_path = os.path.join(output_folder, f"{char_id}_{direction}.png")
            with open(output_path, 'wb') as f:
                f.write(image_bytes)

            file_paths.append(output_path)
            print(f"  |  Saved: {output_path}")

    if file_paths:
        print(f"  +- Saved {len(file_paths)} direction images")
        return True, file_paths
    else:
        return False, []

def generate_single_character(char_config, group_config):
    """
    Generate a single character with 8 directions
    Returns: (success, metadata) tuple
    """
    char_id = char_config['id']
    prompt = char_config['prompt']
    output_folder = group_config['output_folder']

    # Merge default params with character-specific params
    params = group_config.get('default_params', {}).copy()
    if 'params' in char_config:
        params.update(char_config['params'])

    generation_start = time.time()

    # Step 1: Create character
    success, character_id, job_id = create_character_8dir(char_id, prompt, params)
    if not success:
        return False, None

    # Step 2: Poll for completion
    success, job_data = poll_job_completion(job_id)
    if not success:
        return False, None

    # Step 3: Get character images
    success, images_data = get_character_images(character_id)
    if not success:
        return False, None

    # Step 4: Save images
    success, file_paths = save_character_images(images_data, output_folder, char_id)

    generation_time = time.time() - generation_start

    if success:
        metadata = {
            "id": char_id,
            "pixellab_character_id": character_id,
            "file_paths": file_paths,
            "prompt": prompt,
            "params": params,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "generation_time_seconds": int(generation_time),
            "directions": 8,
            "status": "success"
        }
        return True, metadata
    else:
        return False, None

def run_session(config_filepath):
    """Run complete generation session"""
    print("=" * 60)
    print("PixelLab Character Generator - 8 Directions")
    print("=" * 60)
    print()

    # Load and validate config
    config = load_session_config(config_filepath)
    if not validate_config(config):
        sys.exit(1)

    session_name = config['session_name']
    print(f"Session: {session_name}")
    print()

    # Count total characters
    total_chars = sum(len(group['characters']) for group in config['sprite_groups'])
    print(f"Total characters to generate: {total_chars}")
    print()

    # Process each sprite group
    current_char = 0
    session_start = time.time()
    session_metadata = {
        "session_name": session_name,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "total_characters": total_chars,
        "generated": [],
        "failed": []
    }

    for group in config['sprite_groups']:
        group_name = group['name']
        output_folder = group['output_folder']

        print(f"--- Character Group: {group_name} ---")
        print(f"Output folder: {output_folder}")
        print()

        # Create output folder
        if not create_output_folder(output_folder):
            print(f"[ERROR] Skipping group '{group_name}' due to folder creation failure")
            continue

        # Process each character in group
        for char in group['characters']:
            current_char += 1
            char_id = char['id']

            print(f"[{current_char}/{total_chars}] {char_id}")

            # Generate character
            success, metadata = generate_single_character(char, group)

            if success:
                session_metadata['generated'].append(metadata)
            else:
                session_metadata['failed'].append({
                    "id": char_id,
                    "prompt": char['prompt'],
                    "error": "Generation failed"
                })

            print()

            # Safety delay between characters
            if current_char < total_chars:
                print("  (Safety delay: 3s)")
                time.sleep(3)
                print()

    # Session complete
    session_metadata['completed_at'] = datetime.now(timezone.utc).isoformat()
    total_time = time.time() - session_start

    print("=" * 60)
    print("Session Complete")
    print("=" * 60)
    print(f"[OK] {len(session_metadata['generated'])} characters generated successfully")
    print(f"[ERROR] {len(session_metadata['failed'])} characters failed")
    print(f"Total time: {int(total_time // 60)}m {int(total_time % 60)}s")

    if session_metadata['failed']:
        print("\nFailed characters:")
        for failed in session_metadata['failed']:
            print(f"  - {failed['id']}: {failed['error']}")

    # Save session metadata
    metadata_path = f"session_{session_name}_metadata.json"
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(session_metadata, f, indent=2)
    print(f"\n[OK] Session metadata saved: {metadata_path}")

    return session_metadata

def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python pixellab_character_generator.py <config_file.json>")
        print("\nThis script generates characters with 8 directional facings.")
        print("\nConfig format:")
        print('''
{
  "session_name": "my_characters",
  "sprite_groups": [
    {
      "name": "enemies",
      "output_folder": "assets/sprites/enemies",
      "default_params": {
        "width": 64,
        "height": 64,
        "detail": "medium detail",
        "shading": "basic shading",
        "outline": "single color outline"
      },
      "characters": [
        {"id": "guard_01", "prompt": "enemy soldier in brown uniform"},
        {"id": "guard_02", "prompt": "enemy soldier in blue uniform"}
      ]
    }
  ]
}
''')
        sys.exit(1)

    config_filepath = sys.argv[1]

    if not os.path.exists(config_filepath):
        print(f"[ERROR] Config file not found: {config_filepath}")
        sys.exit(1)

    run_session(config_filepath)

if __name__ == "__main__":
    main()
