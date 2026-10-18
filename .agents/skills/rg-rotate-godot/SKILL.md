---
name: rg-rotate-godot
description: >-
  Guidelines and workflows for developing and testing 3D Godot games on the ANBERNIC RG Rotate handheld console,
  focusing on 720x720 1:1 display, D-pad tank/3rd-person controls without analog sticks, 60 FPS rendering tuning, and Android deployment.
---

# RG Rotate Godot 3D Game Development Skill

This skill provides comprehensive hardware specifications, performance tuning benchmarks, input mapping standards, and deployment workflows for developing 3D Godot 4 games on the **ANBERNIC RG Rotate** portable console.

---

## 📌 Development Continuity & Roadmap Tracking
- Whenever working on this repository, **ALWAYS inspect `ROADMAP.md` first** to see the current progress and unfinished tasks.
- As each sub-task is completed, immediately update the markdown checkboxes (`- [x]`) in `ROADMAP.md`.
- If a session is interrupted or context is refreshed, resume strictly from the first unchecked item in `ROADMAP.md`.

---

## 1. Hardware Specifications & Constraints

- **Display**: 3.5-inch IPS, **720 × 720 pixels (1:1 Square aspect ratio)**.
- **Controls**:
  - D-Pad (Up, Down, Left, Right)
  - Face buttons (A, B, X, Y)
  - Shoulder buttons (L1/LB, R1/RB, L2, R2)
  - System buttons: Start, Select
  - **No analog thumbsticks!**
- **OS**: Android 12 (UNISOC ums512_1h10)
- **Chipset**: Unisoc Tiger T618 (2x Cortex-A75 @ 2.0GHz + 6x Cortex-A55 @ 2.0GHz)
- **GPU**: Mali-G52 MP2 (OpenGL ES 3.2, Vulkan 1.1)
- **RAM**: 3GB LPDDR4x

---

## 2. Rendering & Performance Tuning (60 FPS Guide)

The Unisoc T618 / Mali-G52 GPU requires specific Godot 4 rendering settings to maintain a solid 60 FPS in 3D scenes:

### A. Rendering Method: Use `gl_compatibility`
```ini
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
```
- **`mobile` (Vulkan Mobile)**: Drops to **~40 FPS** on Mali-G52 due to Vulkan driver overhead and pipeline compilation pauses on Android 12.
- **`gl_compatibility` (OpenGL ES 3.0)**: Delivers a rock-solid **60–61 FPS** on the device with significantly lower thermals and instant shader startup.

### B. WorldEnvironment & Post-Processing Rules
- **Glow / Bloom**: Always set `glow_enabled = false` for mobile. Glow alone costs 15–20 FPS on Mali-G52.
- **Tonemap Mode**: Set `tonemap_mode = 2` (Filmic). It runs at full 60 FPS while providing rich color depth and highlights.
- **Directional Shadows**:
  - `shadow_enabled = true` is performant with `shadow_bias = 0.04`.
  - Cap `directional_shadow_max_distance = 60.0` to avoid unnecessary shadow rendering passes.

---

## 3. Joypad Button Mapping in Godot 4

ANBERNIC RG Rotate hardware inputs map to standard Godot 4 Joypad indices as follows:

| Hardware Button | Godot 4 Joypad Constant | Joypad Button Index |
|---|---|---|
| **A** | `JOY_BUTTON_A` | `0` |
| **B** | `JOY_BUTTON_B` | `1` |
| **X** | `JOY_BUTTON_X` | `2` |
| **Y** | `JOY_BUTTON_Y` | `3` |
| **Select** | `JOY_BUTTON_BACK` | `4` |
| **Start** | `JOY_BUTTON_START` | **`6`** *(Warning: 6, NOT 7!)* |
| **L1 (LB)** | `JOY_BUTTON_LEFT_SHOULDER` | **`9`** |
| **R1 (RB)** | `JOY_BUTTON_RIGHT_SHOULDER` | **`10`** |
| **D-Pad Up** | `JOY_BUTTON_DPAD_UP` | `11` |
| **D-Pad Down** | `JOY_BUTTON_DPAD_DOWN` | `12` |
| **D-Pad Left** | `JOY_BUTTON_DPAD_LEFT` | `13` |
| **D-Pad Right** | `JOY_BUTTON_DPAD_RIGHT` | `14` |

> [!CAUTION]
> **Joypad Button Bleeding**: Never query `Input.is_action_pressed()` for individual button UI visualizers if actions share buttons. Always query `Input.is_joy_button_pressed(0, JOY_BUTTON_*)` directly to avoid input cross-bleed.

---

## 4. Control Design Standards (Stick-less Handheld)

### Recommended Layout
- **D-Pad Up (▲)**: Move forward / Flight dive (nose down)
- **D-Pad Down (▼)**: Move backward / Flight climb (nose up)
- **D-Pad Left/Right (◀ ▶)**: Turn yaw / Flight bank roll
- **A Button**: **Interact / Mount (調べる・起動・搭乗)**
- **B Button**: **Jump / Flight brake (ジャンプ・減速)**
- **Y Button**: **Sprint / Flight boost (ダッシュ・加速)**
  - Preserves the classic Nintendo "Y-Run + B-Jump" thumb-rocking ergonomics.
- **RB Button**: **Shoot / Cannons (射撃・ツインキャノン)**
- **LB Button**: **180° Quick-Turn (瞬時に後ろを振り向く)**
  - Vital on stick-less devices for maneuvering in tight areas.
- **Start Button**: **Settings Modal / Pause (設定・ポーズ)**

### Modal & Pause Input Suppression Pattern
When unpausing or closing menus with B/Start, suppress movement/jump inputs for 0.25–0.35s to prevent accidental jumping:
```gdscript
var input_suppress_timer: float = 0.0

func suppress_input(duration: float = 0.3) -> void:
    input_suppress_timer = duration
    velocity.x = 0.0
    velocity.z = 0.0
```

### Mount / Vehicle Debounce Pattern
When boarding or dismounting vehicles via the A button, apply a 0.35s debounce cooldown (`board_cooldown`) so the same frame's `is_action_just_pressed("interact")` does not instantly trigger dismount.

---

## 5. Third-Person Camera Follow (Stick-less)

- Use a decoupled camera mount (`camera_mount.top_level = true`).
- Position: Smoothly interpolate mount position (`global_position.lerp(target_pos, delta * speed)`).
- Yaw: Smoothly interpolate mount rotation (`lerp_angle(current_yaw, target_yaw, delta * rot_speed)`).
- Camera FOV: ~`68°` to `72°` on 720×720 1:1 screen gives optimal vertical and horizontal visibility.

---

## 6. Asset & File Hygiene

- **`.gdignore` in Documentation Folders**:
  Always place an empty `.gdignore` file in non-game asset folders (such as `docs/`, `design/`, or screenshot folders). This prevents Godot from unnecessarily scanning and generating `.import` files for documentation media.

---

## 7. Build, Export & ADB Workflows

### Project Validation (Headless):
```powershell
& "C:\Users\user\Downloads\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit
```

### Headless Android Export:
```powershell
& "C:\Users\user\Downloads\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --export-debug "Android" ./build/rg_rotate_3d_test.apk
```

### Install and Launch on RG Rotate:
```powershell
adb install -r ./build/rg_rotate_3d_test.apk
adb shell monkey -p com.anbernic.rgrotate.test3d -c android.intent.category.LAUNCHER 1
```

### Remote Screen Capture:
```powershell
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png ./docs/images/screenshot.png
```

### Check Logs & Runtime Errors:
```powershell
adb logcat -d -s godot:*
```

---

## 8. Verified Game Architecture Modules & Benchmark Documentation

Detailed reference implementations and benchmarks are documented in `.wiki/`:
- **Mode 1: Basic 3D Sandbox (`Mode-1-Basic-Sandbox.md`)**: Moving platform, lift, physics tower, airplane mount & 3D flight physics.
- **Mode 2: Musou Horde (`Mode-2-Musou-Horde.md`)**: MultiMesh 1 Draw Call, 100+ soldiers crowd AI (2D separation), sweeping knockback slash.
- **Mode 3: Space Dogfight (`Mode-3-Space-Dogfight.md`)**: Zero-g 3D flight, asteroid belts, auto lock-on HUD, homing torpedoes, enemy squadron AI.
- **Mode 4: Open World & Terrain LOD (`Mode-4-Open-World-Terrain.md`)**: 5×5 chunk procedural streaming, 2-level distance LOD (75% triangle saving), fog fade, 4-wheel suspension buggy.
- **Mode 5: Dungeon & Boss Battle (`Mode-5-Dungeon-Boss-Battle.md`)**: Stone arena, lighting stress test (2 vs 6 dynamic lights), Z-targeting lock-on, dodge roll with i-frames, telegraphed boss AI with expanding shockwave rings.
- **Shared Frameworks (`Game-Framework-Architecture.md`)**: `Interactable`, `CommonPauseMenu`, procedural sound synthesizer (`SoundManager`).

