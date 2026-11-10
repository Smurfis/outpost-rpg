extends SceneTree
## Real Alpha enemy HUD integration: rarity presentation, actual HP,
## safe-area layout, no Android input interception and hide-on-death.
var failures: int = 0

func verify(condition: bool, description: String) -> void:
    if condition:
        print("PASS ENEMY TARGET: " + description)
    else:
        failures += 1
        push_error("FAIL ENEMY TARGET: " + description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.set_meta("outpost_new_adventure", true)
    var packed: PackedScene = load("res://scenes/main.tscn")
    verify(packed != null, "Gameplay scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    game.save_path = "user://enemy_target_hud_regression.json"
    root.add_child(game)
    await process_frame
    var hud = game.hud
    verify(hud != null, "Live HUD exists")
    if hud == null:
        quit(1)
        return
    var target_panel: Control = hud.enemy_target_hud
    verify(target_panel != null, "New enemy target container mounted")
    if target_panel == null:
        quit(1)
        return
    verify(not target_panel.visible, "Unselected targets do not occupy HUD")
    var frame: Panel = target_panel.get_node("EnemyPortraitFrame") as Panel
    var icon: TextureRect = target_panel.get_node("EnemyPortraitImage") as TextureRect
    var hp: ProgressBar = target_panel.get_node("EnemyHealthBar") as ProgressBar
    var hp_label: Label = target_panel.get_node("EnemyHealthText") as Label
    var rarity: Label = target_panel.get_node("EnemyRarity") as Label
    var title: Label = target_panel.get_node("EnemyName") as Label
    var beasts: Array[Node] = get_nodes_in_group("wild_boars")
    verify(not beasts.is_empty(), "Real boars exist for HUD integration")
    if beasts.is_empty():
        game.queue_free()
        quit(1)
        return
    var boar = beasts[0]
    boar.rarity_tier = "normal"
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    verify(target_panel.visible and title.text == "Wild boar", "Boar name and portrait appear")
    verify(icon.texture != null and icon.texture.resource_path.ends_with("enemy_boar_portrait.svg"), "Distinct voxel boar portrait, not player artwork")
    verify(hp.max_value == boar.max_hp and hp.value == boar.hp, "Boar meter uses true max/current HP")
    verify(rarity.text.is_empty(), "Normal boar does not claim rare or elite status")
    boar.hp = 19.0
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    verify(hp.value == 19.0 and hp_label.text == "19 / 32 HP", "Live damage value updates immediately")
    boar.rarity_tier = "rare"
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    var silver: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat
    verify(rarity.text == "RARE" and silver.border_color == Color("#c7d6e5"), "Rare enemy displays silver frame")
    boar.rarity_tier = "elite"
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    var gold: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat
    verify(rarity.text == "ELITE" and gold.border_color == Color("#efbe68"), "Elite enemy displays gold frame")
    boar.rarity_tier = "normal"
    boar.set_meta("enemy_rarity", "rare")
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    verify(rarity.text == "RARE", "Explicit enemy rarity metadata overrides normal default")
    boar.remove_meta("enemy_rarity")
    var screen_rect: Rect2 = target_panel.get_global_rect()
    verify(not screen_rect.intersects(hud.hero_portrait_frame.get_global_rect()), "Enemy frame does not cover player portrait")
    verify(not screen_rect.intersects(hud.quest_frame.get_global_rect()), "Enemy frame does not cover quest tracker")
    verify(not screen_rect.intersects(hud.minimap.get_global_rect()), "Enemy frame does not cover minimap")
    verify(not screen_rect.intersects(hud.smart_button.get_global_rect()), "Enemy frame does not cover combat controls")
    verify(not screen_rect.intersects(hud.zone_banner.get_global_rect()), "Enemy frame sits above zone banner")
    verify(target_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Enemy frame does not consume touch input")
    for child in target_panel.get_children():
        if child is Control:
            verify((child as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Portrait child ignores taps")
    boar.alive = false
    hud.update_enemy_target(boar, game.enemy_display_name(boar))
    verify(not target_panel.visible, "Dead enemy immediately clears portrait")
    boar.alive = true
    boar.visible = true
    boar.hp = boar.max_hp
    hud.update_enemy_target(boar, "Wild boar")
    verify(target_panel.visible, "Respawned enemy can be retargeted")
    hud.update_enemy_target(null)
    verify(not target_panel.visible, "Out-of-range enemy clears target")
    var unknown := Node3D.new()
    unknown.name = "UnknownEnemy"
    game.add_child(unknown)
    unknown.set_meta("enemy_rarity", "elite")
    hud.update_enemy_target(unknown, "Unknown enemy")
    verify(target_panel.visible and rarity.text == "ELITE", "Other enemies can use generic portrait and rarity metadata")
    verify(not hp.visible and not hp_label.visible, "Unknown health never shows fabricated HP")
    unknown.queue_free()
    game.queue_free()
    await process_frame
    print("ENEMY TARGET RESULT: %d failures" % failures)
    quit(0 if failures == 0 else 1)
