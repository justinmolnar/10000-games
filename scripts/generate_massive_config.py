import json
import os

themes = {
    "space": ["player_ship", "asteroid_small", "asteroid_large", "comet", "satellite", "space_debris", "alien_probe", "star_fragment"],
    "school": ["student (player)", "pencil", "eraser", "crumpled_paper", "ruler", "glue_stick", "paper_airplane", "textbook", "chalk"],
    "ice_rink": ["skater (player)", "hockey_player", "puck", "zamboni", "ice_chunk", "hockey_stick", "cone"],
    "computer_inside": ["cursor (player)", "capacitor", "spark", "loose_screw", "resistor", "solder_blob", "dust_bunny", "static_charge", "ram_stick"],
    "ocean": ["fish (player)", "jellyfish", "shark_fin", "sea_urchin", "fishing_hook", "anchor", "bubble_cluster", "seaweed_clump"],
    "highway": ["motorcycle (player)", "car_red", "car_blue", "truck", "pothole", "tire", "traffic_cone", "oil_slick"],
    "kitchen": ["mouse (player)", "knife", "fork", "flying_pan", "hot_pot", "tomato", "egg", "rolling_pin", "flame_burst"],
    "picnic": ["ant (player)", "shoe", "falling_sandwich", "grape", "soda_drop", "fork_stab", "napkin", "watermelon_seed"],
    "graveyard": ["ghost_player", "tombstone", "skeleton_hand", "bat", "crow", "floating_skull", "wisp", "dead_branch"],
    "construction": ["hardhat_worker (player)", "falling_beam", "brick", "wrench", "rivet", "cement_glob", "crane_hook", "barrel"],
    "jungle": ["explorer (player)", "snake", "coconut", "monkey", "parrot", "vine_swing", "spider", "dart"],
    "disco": ["dancer (player)", "disco_ball_shard", "platform_shoe", "spinning_dancer", "spotlight", "vinyl_record", "speaker_blast"],
    "medieval": ["peasant (player)", "arrow", "catapult_rock", "sword", "shield", "flaming_arrow", "lance", "cannonball"],
    "bloodstream": ["virus (player)", "white_blood_cell", "platelet", "antibody", "red_blood_cell", "bacteria", "cell_fragment"],
    "garden": ["ladybug (player)", "bee", "lawnmower_blade", "sprinkler_drop", "garden_gnome", "thorn", "rock", "worm"],
    "sewer": ["rat (player)", "sludge_drop", "cockroach", "pipe_drip", "trash_float", "toxic_bubble", "grate_piece"],
    "tornado": ["storm_chaser (player)", "cow", "car_door", "fence_post", "roof_shingle", "mailbox", "tree_branch", "shopping_cart"],
    "microscope": ["cell (player)", "bacteria_rod", "bacteria_sphere", "amoeba", "paramecium", "virus_particle", "cell_debris"],
    "candy_factory": ["gummy_bear (player)", "jawbreaker", "gumball", "candy_cane_shard", "lollipop", "chocolate_chunk", "sprinkle_cluster", "licorice_whip"],
    "haunted_house": ["kid (player)", "floating_chair", "bat_swarm", "ghost", "painting_eyes", "chandelier", "spider_web", "candelabra"],
    "aquarium": ["small_fish (player)", "big_fish", "pufferfish", "crab", "starfish", "bubble", "hook", "seashell"],
    "pizza": ["dough_ball (player)", "pepperoni", "olive", "mushroom_slice", "anchovy", "pepper_ring", "cheese_glob", "sauce_splat"],
    "laundromat": ["sock (player)", "flying_shirt", "detergent_cap", "lint_ball", "coat_hanger", "button", "zipper", "dryer_sheet"],
    "circus": ["clown (player)", "juggling_ball", "flaming_hoop", "cannon_ball", "pie", "balloon_animal", "trapeze_bar", "peanut"],
    "desert": ["lizard (player)", "tumbleweed", "scorpion", "cactus_chunk", "vulture", "sand_devil", "rattlesnake", "sun_beam"],
    "supermarket": ["shopper (player)", "shopping_cart", "can_tower", "banana_peel", "price_tag", "sample_tray", "mop_bucket", "falling_sign"],
    "volcano": ["rock_surfer (player)", "lava_bomb", "ember", "ash_cloud", "obsidian_shard", "magma_glob", "steam_vent", "sulfur_crystal"],
    "winter": ["penguin (player)", "snowball", "icicle", "snow_pile", "sled", "pine_cone", "ice_chunk", "snowflake_large"],
    "attic": ["mouse (player)", "mothball", "spider", "falling_box", "cobweb", "old_doll", "broken_ornament", "dust_cloud"],
    "beach": ["sandcastle (player)", "crab", "frisbee", "seagull", "beach_ball", "shell", "wave_splash", "sunscreen_bottle"],
    "office": ["office_worker (player)", "stapler", "coffee_mug", "paperclip", "binder", "rubber_band", "tape_dispenser", "memo_paper"],
    "toy_box": ["action_figure (player)", "marble", "jack", "bouncy_ball", "lego_brick", "spinning_top", "toy_car", "dice"],
    "subway": ["commuter (player)", "briefcase", "newspaper", "coffee_cup", "umbrella", "backpack", "rat", "turnstile_arm"],
    "farm": ["pig (player)", "chicken", "hay_bale", "pitchfork", "egg", "corn_cob", "horseshoe", "tractor_wheel"],
    "bakery": ["baker (player)", "rolling_donut", "baguette", "flour_cloud", "cupcake", "pretzel", "croissant", "whisk"],
    "pond": ["frog (player)", "lily_pad", "dragonfly", "fish_jump", "turtle", "cattail", "water_ripple", "tadpole"],
    "junkyard": ["junkyard_dog (player)", "hubcap", "spring", "tire", "car_door", "magnet", "rust_chunk", "pipe"],
    "bowling": ["bowling_pin (player)", "bowling_ball", "shoe", "lane_arrow", "gutter_guard", "score_card", "nachos"],
    "playground": ["kid (player)", "kickball", "jump_rope", "swing_chain", "dodgeball", "tetherball", "pebble", "whistle"],
    "nostril": ["booger (player)", "nose_hair", "finger", "dust_particle", "pollen", "sneeze_droplet", "tissue_fiber"],
    "toilet": ["rubber_duck (player)", "splash", "plunger", "toilet_paper_roll", "bubble", "drain_swirl", "soap_bar"],
    "fridge": ["fresh_apple (player)", "moldy_cheese", "expired_milk", "mystery_tupperware", "old_lettuce", "sauce_drip", "ice_crystal", "leftover_blob"],
    "inside_shoe": ["toe (player)", "pebble", "fungus_spore", "sock_lint", "shoelace_end", "insole_crack", "odor_cloud"],
    "spam_inbox": ["cursor (player)", "popup_ad", "nigerian_prince", "virus_attachment", "chain_letter", "flashing_banner", "free_money", "hot_singles"],
    "couch_cushion": ["coin (player)", "remote_button", "crumb", "pen_cap", "hair_tie", "chip", "dust_bunny", "mystery_sticky"],
    "lava_lamp": ["small_blob (player)", "wax_blob_large", "wax_blob_medium", "rising_bubble", "heat_wave", "wax_strand"],
    "petri_dish": ["microbe (player)", "dividing_amoeba", "colony_cluster", "spore", "flagellum", "cell_wall_fragment"],
    "dream": ["floating_person (player)", "falling_tooth", "giant_eye", "melting_clock", "door_nowhere", "shadow_figure", "staircase_infinite", "fish_sky"],
    "dryer": ["sock (player)", "static_spark", "button", "lint_ball", "zipper", "coin", "dryer_sheet", "hair_tie"],
    "y2k_bunker": ["survivalist (player)", "canned_beans", "countdown_number", "flashlight", "radio", "gas_mask", "water_jug", "conspiracy_paper"],
    "fondue": ["bread_cube (player)", "cheese_drip", "skewer", "cherry_tomato", "broccoli", "meat_chunk", "chocolate_drip", "fondue_splash"],
    "keyboard": ["keycap (player)", "crumb", "dust_particle", "hair", "staple", "paper_clip", "eraser_shaving", "coffee_drip"],
    "first_date": ["heart (player)", "awkward_silence (text bubble)", "spilled_drink", "check_bill", "wilting_flower", "phone_buzz", "breadstick"],
    "sneeze": ["healthy_cell (player)", "germ", "droplet", "pollen", "dust_mite", "mucus_glob", "tissue_shred"],
    "printer": ["paper_sheet (player)", "ink_cartridge", "paper_jam", "error_message", "toner_dust", "roller", "staple"],
    "vending_machine": ["snack_bag (player)", "falling_can", "coin", "stuck_candy", "spring", "glass_crack", "price_tag"],
    "ballpit": ["ball_red (player)", "ball_blue", "ball_green", "ball_yellow", "lost_shoe", "bandaid", "mystery_wet"],
    "vacuum": ["dust_bunny (player)", "lego_brick", "hair_tangle", "coin", "cheerio", "pet_hair", "paper_scrap"],
    "blender": ["strawberry (player)", "ice_cube", "banana_chunk", "blade_whoosh", "milk_splash", "blueberry", "protein_glob"],
    "conspiracy_wall": ["pushpin (player)", "red_string", "newspaper_clip", "photo", "sticky_note", "thumbtack", "coffee_ring", "question_mark"],
    "microwave": ["leftover (player)", "sparking_fork", "rotating_plate_edge", "hot_pocket_explosion", "popcorn_kernel", "splatter", "timer_beep"],
    "snow_globe": ["tiny_person (player)", "glitter", "fake_snow", "tiny_house", "tiny_tree", "base_crack", "water_bubble"],
    "powerpoint": ["cursor (player)", "bullet_point", "clip_art", "word_art", "pie_chart", "transition_wipe", "comic_sans_text", "stock_photo"],
    "backrooms": ["wanderer (player)", "fluorescent_flicker", "damp_carpet_stain", "entity_shadow", "exit_sign_false", "wallpaper_peel", "ceiling_tile", "buzzing_light"],
}

session = {
    "session_name": "massive_shared_collection",
    "description": "A massive collection of shared sprites across 64 themes.",
    "sprite_type": "pixflux",
    "sprite_groups": []
}

for theme_name, sprite_list in themes.items():
    group = {
        "name": theme_name,
        "output_folder": f"assets/sprites/shared/{theme_name}",
        "default_params": {
            "width": 32,
            "height": 32,
            "view": "side",
            "detail": "medium detail",
            "shading": "basic shading",
            "outline": "single color outline"
        },
        "sprites": []
    }
    
    # Adjust view for certain themes
    if theme_name in ["space", "ocean", "pond", "microscope", "petri_dish", "bloodstream"]:
        group["default_params"]["view"] = "high top-down"
    elif theme_name in ["highway", "kitchen", "picnic", "garden", "sewer", "supermarket", "playground", "beach", "farm", "office"]:
        group["default_params"]["view"] = "low top-down"

    for sprite_raw in sprite_list:
        sprite_id = sprite_raw.split(" (")[0].replace(" ", "_").replace("(", "").replace(")", "").replace("/", "_")
        prompt = sprite_raw.replace("_", " ")
        if "(player)" in sprite_raw:
            prompt = f"player character {prompt.replace('(player)', '').strip()}"
        
        # Add context based on theme
        prompt = f"{prompt}, {theme_name} theme, pixel art, 32x32"
        
        group["sprites"].append({
            "id": sprite_id,
            "prompt": prompt
        })
    
    session["sprite_groups"].append(group)

with open("assets/data/sprite_generation_sessions/massive_shared_collection.json", "w") as f:
    json.dump(session, f, indent=2)

print("Generated massive_shared_collection.json")
