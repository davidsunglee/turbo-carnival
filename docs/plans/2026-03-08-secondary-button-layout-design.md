# Secondary Weapon Button Layout Redesign

## Problem

On iPhone 17 in portrait mode (~393pt wide), the 3 secondary weapon buttons overlap each other. The current arc layout uses radius 77pt with 0.4-radian spacing between 50pt buttons, yielding ~31pt center-to-center distance — each button overlaps its neighbor by ~19pt.

## Design

**Button sizing:**
- Secondary buttons: 44pt diameter circles (cornerRadius 22) — down from 50pt
- Primary fire: unchanged at 80x80

**Arc geometry:**
- Arc radius: 100pt (fire button center to each secondary center)
- Angular spacing: 0.55 radians between buttons
- Angles from vertical, sweeping left: `[-0.50, -1.05, -1.60]`
- Center-to-center distance: ~55pt (44pt + 11pt gap)

**Button order (reversed from current):**
- Rightmost (angle -0.50): "3" — Overcharge
- Middle (angle -1.05): "2" — EMP Sweep
- Leftmost (angle -1.60): "1" — Grav-Bomb

On a 393pt-wide screen, the leftmost button center lands at ~x=188, staying within the right half.

## Files Changed

- `Project2043-iOS/MetalView.swift` — update `layoutSubviews()` arc parameters + `setupControlOverlays()` corner radius
