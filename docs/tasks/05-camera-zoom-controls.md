# Task 05: Camera zoom, lens, and flash controls

**Depends on:** 04 · **Track:** Flutter camera

## Goal

Implement pinch-to-zoom, the vertical zoom slider, and rounded zoom/lens buttons (0.5x, 1x, 2x, …)
that reflect what the device actually supports, plus the reference's flash control.

## In scope

- Single zoom value in `CameraCubit` state, clamped to the active camera's min/max. Pinch, slider,
  and buttons all read and write it, so they always agree.
- Pinch gesture relative to the zoom at gesture start.
- Vertical slider on the right edge (design `C1`), labeled with the device's real min and max zoom
  (the design's "8×" is sample data).
- Rounded 48 dp pill buttons in a scrim group, generated from capabilities found in the task 04
  spike: show 0.5x only when an ultra-wide lens or zoom < 1.0 exists (`C4`). The selected button
  is white-filled; no button is selected between presets.
- Zoom readout while pinching that fades 500 ms after release (`C3`).
- Lens switching (if 0.5x is a separate camera) without overlapping operations, preserving a
  sensible zoom afterwards.
- Flash toggle (top bar) using the modes the camera supports. When unsupported, the icon stays at
  38% and a tap shows the "Flash isn't available" toast (`C5`).

## Out of scope

Tap-to-focus (06), capture (07), front camera unless approved in the plan.

## Acceptance criteria

- Pinch, slider, and buttons stay consistent and never exceed supported bounds.
- Buttons shown match the device's capabilities; labels are not fabricated optical values.
- Rapid button taps or lens switches do not crash, lock the camera, or leave mismatched UI.
- Flash state shown matches the mode applied; unsupported flash is not offered.
- Zoom and lens survive background/return or reset predictably as defined in the plan.

## Verification

- Cubit tests with a fake camera service exposing different capability sets (no ultra-wide,
  ultra-wide as lens, zoom < 1.0): clamping, button set, consistency between inputs, rejection of
  overlapping lens switches, flash availability.
- Device: physical phone; confirm visible field-of-view change for each button and record it.

## Decisions for the plan

- Button set and mapping (lens switch vs. zoom ratio), based on spike findings.
- Flash modes (off/auto/on/torch) to expose.
- Whether the design's flip button (`C1`) switches to the front camera (the brief only requires
  back cameras) or is omitted. The settings icon belongs to the simulation sheet (task 08).

## References

Product reference (Task 2 zoom rule), design frames `C1`, `C3-C5` and flow notes, implementation
reference (zoom clamping, overlapping operations). Docs: `CameraController.setZoomLevel`, `getMinZoomLevel`/`getMaxZoomLevel`,
`setFlashMode`; Flutter `ScaleGestureRecognizer`.
