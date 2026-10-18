---
name: rg-rotate-godot
description: >-
  Guidelines and workflows for developing and testing 3D Godot games on the ANBERNIC RG Rotate handheld console,
  focusing on 720x720 1:1 display, D-pad tank/3rd-person controls without analog sticks, and Android deployment.
---

# RG Rotate Godot 3D Game Development Skill

This skill provides guidelines and development workflows for creating and maintaining 3D Godot 4 games targeting the **ANBERNIC RG Rotate** portable console.

---

## 1. Hardware Specifications & Constraints

- **Display**: 3.5-inch IPS, **720 × 720 pixels (1:1 Square aspect ratio)**.
- **Controls**:
  - D-Pad (Up, Down, Left, Right).
  - Face buttons (A, B, X, Y).
  - Shoulder buttons (L1/R1, L2/R2).
  - Start, Select.
  - **No analog thumbsticks!**
- **OS**: Android 12.
- **Chipset**: Unisoc Tiger T618 (Mali G52 GPU, 3GB RAM).

---

## 2. Input & 3D Control Best Practices

Because the device does **not** have analog thumbsticks, standard dual-stick camera controls will not work. Follow these control design rules:

### A. Movement & Tank/TPS Steering
- **Up (↑ / D-Pad Up)**: Move forward in the direction the character faces.
- **Down (↓ / D-Pad Down)**: Walk backwards at reduced speed (~50% of forward speed).
- **Left / Right (← → / D-Pad Left/Right)**: Rotate (turn) character yaw.
- **Turn Smoothing**: Use an angular speed around `2.8` rad/sec with subtle bank tilt on model's Z-axis for responsive feel.
- **180° Quick-Turn**: Bind a dedicated button (e.g., `Q` / `R1`) to immediately swivel 180 degrees. This drastically improves maneuverability in stick-less environments.

### B. Third-Person Camera Follow
- Use `SpringArm3D` positioned behind and above the character (e.g. spring length 3.6m, pitch angle -20° to -25°).
- Decouple camera mount using `top_level = true` and apply smooth damping (`lerp_angle` with speed ~5.0) to match the player's yaw.
- Never require manual camera rotation for basic navigation.

---

## 3. Project Configuration (`project.godot`)

```ini
[display]
window/size/viewport_width=720
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
```

---

## 4. Testing & Running Workflows

### Run with Godot Console on Windows:
```powershell
& "C:\Users\user\Downloads\Godot\Godot_v4.7.2-stable_win64_console.exe" --path .
```

### Validate without GUI (Headless):
```powershell
& "C:\Users\user\Downloads\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --quit
```

### Export to Android APK:
1. Ensure Android Build Templates and Android SDK/JDK are installed.
2. In Godot, go to `Project -> Export...`.
3. Add `Android` preset with `Architecture: arm64-v8a` enabled.
4. Export APK and transfer to RG Rotate storage or install via `adb install -r <app>.apk`.
