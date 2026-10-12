# Task 06: Tap-to-focus

**Status:** Not started · **Depends on:** 04 · **Track:** Flutter camera

## Goal

Tapping the preview requests focus (and exposure, when supported) at that point and shows a visual
indicator exactly where the user tapped.

## In scope

- Map the tap position to normalized sensor coordinates, accounting for preview scaling, cropping,
  and orientation.
- Call focus/exposure point APIs only when the camera reports support; otherwise show a brief
  "focus not supported" hint rather than a misleading indicator.
- Focus indicator from design `C2`: 80 dp amber ring with center dot at the tap point, scales
  1.2 → 1.0 in 150 ms, holds 1.5 s, fades in 200 ms; a new tap replaces it. Its label reads "FOCUS"
  unless focus is actually locked (the design's "FOCUS LOCKED" is not copied literally).
- Keep tap handling compatible with the pinch gesture from task 05.

## Out of scope

Manual focus distance sliders, focus lock modes beyond what the plan approves.

## Acceptance criteria

- The indicator appears at the tapped screen position.
- The focus request uses correctly mapped coordinates, including on a cropped preview.
- Unsupported focus is handled explicitly; no crash and no fake success.
- Pinch-to-zoom does not trigger a focus tap, and a tap does not change zoom.

## Verification

- Unit tests for the coordinate mapping (preview aspect vs. widget aspect, crop offsets, edges).
- Cubit test: supported device issues a focus request with mapped coordinates; unsupported device
  produces the hint state.
- Device: tap near and far objects on a physical phone and record visible refocus.

## Decisions for the plan

- Whether to also set the exposure point and how long the indicator stays.
- Whether to return to continuous autofocus after a timeout.

## References

Design frame `C2` and the deviations table, implementation reference (focus mapping note),
verification reference (Camera). Docs:
`CameraController.setFocusPoint`, `setExposurePoint`, `focusPointSupported`.
