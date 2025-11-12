#!/usr/bin/env python3
"""
PixelLab Batch Sprite Generator
Automated sprite generation, polling, downloading, and cataloging system
"""

import json
import time
import os
import sys
import requests
from pathlib import Path
from datetime import datetime, timezone

# PixelLab MCP API Configuration
# Note: This script is designed to work with Claude Code MCP integration
# The actual API calls will be made through the MCP server, not directly
PIXELLAB_API_BASE = "https://api.pixellab.ai"

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

    # Validate each sprite group
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

        # Validate each sprite in group
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

def generate_sprite_mcp(sprite_id, prompt, params):
    """
    Generate sprite using PixelLab MCP
    This is a placeholder - actual implementation will use Claude Code MCP calls

    Returns: job_id or None on failure
    """
    print(f"  +- Generating sprite via MCP...")
    print(f"  |  Prompt: {prompt}")
    print(f"  |  Params: {params}")

    # NOTE: In actual usage, Claude Code will make the MCP call like:
    # mcp__pixellab__create_map_object(description=prompt, **params)
    # For now, return a mock job_id for testing

    print(f"  |  [WARNING] MCP CALL PLACEHOLDER - This will be replaced with actual MCP integration")
    return "mock-job-id-12345"

def poll_until_complete_mcp(job_id, poll_interval=5, timeout=300):
    """
    Poll PixelLab MCP until sprite generation completes

    Returns: (success, result_data) tuple
    - success: True if completed successfully, False if failed/timeout
    - result_data: Dict with download_url, metadata, etc.
    """
    print(f"  +- Polling for completion (job_id: {job_id})...")
    start_time = time.time()
    elapsed = 0

    while elapsed < timeout:
        # NOTE: In actual usage, Claude Code will make the MCP call like:
        # mcp__pixellab__get_map_object(object_id=job_id)

        print(f"  |  Polling... ({int(elapsed)}s)")

        # Mock response for testing
        time.sleep(poll_interval)
        elapsed = time.time() - start_time

        # Simulate completion after ~15 seconds
        if elapsed > 15:
            print(f"  +- Complete! ({int(elapsed)}s total)")
            return True, {
                "download_url": f"https://pixellab.ai/mock/download/{job_id}.png",
                "width": 32,
                "height": 32,
                "status": "completed"
            }

    print(f"  +- [ERROR] TIMEOUT after {timeout}s")
    return False, None

def download_sprite(download_url, output_path):
    """
    Download sprite PNG from URL and save to output path

    Returns: True on success, False on failure
    """
    print(f"  +- Downloading sprite...")
    print(f"  |  URL: {download_url}")
    print(f"  |  Path: {output_path}")

    max_retries = 3
    retry_delay = 5

    for attempt in range(max_retries):
        try:
            response = requests.get(download_url, timeout=30)
            response.raise_for_status()

            # Save to file
            with open(output_path, 'wb') as f:
                f.write(response.content)

            # Verify file was written
            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                print(f"  +- Downloaded: {output_path}")
                return True
            else:
                print(f"  |  [ERROR] File verification failed (attempt {attempt + 1}/{max_retries})")

        except requests.exceptions.RequestException as e:
            print(f"  |  [ERROR] Download failed (attempt {attempt + 1}/{max_retries}): {e}")

            if attempt < max_retries - 1:
                print(f"  |  Retrying in {retry_delay}s...")
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff

    print(f"  +- [ERROR] Download failed after {max_retries} attempts")
    return False

def generate_single_sprite(sprite_config, group_config, session_name):
    """
    Generate a single sprite: create → poll → download

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

    # Start generation
    generation_start = time.time()
    job_id = generate_sprite_mcp(sprite_id, prompt, params)

    if not job_id:
        return False, None

    # Poll until complete
    success, result_data = poll_until_complete_mcp(job_id)

    if not success:
        return False, None

    # Download sprite
    download_success = download_sprite(result_data['download_url'], output_path)
    generation_time = time.time() - generation_start

    if download_success:
        metadata = {
            "id": sprite_id,
            "pixellab_object_id": job_id,
            "file_path": output_path,
            "prompt": prompt,
            "params": params,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "generation_time_seconds": int(generation_time),
            "size": f"{params.get('width', 'unknown')}x{params.get('height', 'unknown')}",
            "status": "success",
            "review_flags": []
        }
        return True, metadata
    else:
        return False, None

def run_session(config_filepath):
    """Run complete generation session"""
    print("=" * 60)
    print("PixelLab Batch Sprite Generator")
    print("=" * 60)
    print()

    # Load and validate config
    config = load_session_config(config_filepath)
    if not validate_config(config):
        sys.exit(1)

    session_name = config['session_name']
    print(f"\nSession: {session_name}")
    print()

    # Count total sprites
    total_sprites = sum(len(group['sprites']) for group in config['sprite_groups'])
    print(f"Total sprites to generate: {total_sprites}")
    print()

    # Process each sprite group
    current_sprite = 0
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
            success, metadata = generate_single_sprite(sprite, group, session_name)

            if success:
                session_metadata['generated'].append(metadata)
            else:
                session_metadata['failed'].append({
                    "id": sprite_id,
                    "prompt": sprite['prompt'],
                    "error": "Generation or download failed"
                })

            print()

            # Safety delay between sprites (avoid rate limiting)
            if current_sprite < total_sprites:
                print("  (Safety delay: 2s)")
                time.sleep(2)
                print()

    # Session complete
    session_metadata['completed_at'] = datetime.now(timezone.utc).isoformat()

    print("=" * 60)
    print("Session Complete")
    print("=" * 60)
    print(f"[OK] {len(session_metadata['generated'])} sprites generated successfully")
    print(f"[ERROR] {len(session_metadata['failed'])} sprites failed")

    if session_metadata['failed']:
        print("\nFailed sprites:")
        for failed in session_metadata['failed']:
            print(f"  - {failed['id']}: {failed['error']}")

    # Save session metadata for manifest integration (Phase 3)
    metadata_path = f"session_{session_name}_metadata.json"
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(session_metadata, f, indent=2)
    print(f"\n[OK] Session metadata saved: {metadata_path}")

    return session_metadata

def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python pixellab_batch_generator.py <config_file.json>")
        print("\nExample:")
        print("  python pixellab_batch_generator.py assets/data/sprite_generation_sessions/session_verification.json")
        sys.exit(1)

    config_filepath = sys.argv[1]

    if not os.path.exists(config_filepath):
        print(f"[ERROR] Config file not found: {config_filepath}")
        sys.exit(1)

    run_session(config_filepath)

if __name__ == "__main__":
    main()
