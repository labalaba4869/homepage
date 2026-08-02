# 🗺️ MiniMap Addon (Godot 4)

A simple and flexible **minimap system** for Godot 4 using `SubViewport`.  
Supports live editor preview, customizable visuals, and easy integration into any 2D project.

---

## ✨ Features

- 📷 Real-time minimap using `SubViewport` + `Camera2D`
- 🧭 Tracks a target node (player, enemy, etc.)
- 🎯 Customizable player marker (texture + scale)
- 🖼️ Optional frame (`NinePatchRect` support)
- 📏 Adjustable minimap size & zoom
- 🎨 Custom border color
- 👁️ Toggle visibility of specific render layers
- 🛠️ Editor-friendly (`@tool` support with live updates)

---
## 🚀 Usage

### 1. Add the MiniMap Node

Add a `MiniMap` node to your scene:
frame_image use a NinePatchRect
---

## 🛠️ Editor Preview

This addon uses `@tool`, so it runs in the editor:

- Property changes update visually
- Layout can be adjusted without running the game
- Automatically redraws in editor mode

> ⚠️ Note: The actual world may not fully render in the editor due to Godot limitations. It works correctly at runtime.
