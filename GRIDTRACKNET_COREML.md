# GridTrackNet → Core ML (Usage Notes)

Concise guide for converting the repo’s GridTrackNet model to a Core ML package and using it from the tennis-trainer iOS app.

## Source & Output
- Source model: `GridTrackNet/GridTrackNet.py` (Keras, channels-first), weights: `GridTrackNet/model_weights.h5`.
- Converter script: `tennis-trainer/convert_gridtracknet.py`.
- Core ML output: `tennis-trainer/Tennis Trainer/Models/GridTrackNet5.mlpackage`.
- Core ML type: `mlprogram`, precision `fp16`, minimum target iOS 16, compute units = ALL.

## Conversion (Reproducible)
1. Create a fresh venv (Python 3.11 recommended on Intel macOS).
2. Install pinned deps:
   - `pip install -r requirements-convert.txt`
3. Run converter from the `tennis-trainer` folder:
   - `cd tennis-trainer && python3 convert_gridtracknet.py`
4. Result is saved under tennis-trainer as noted above.

Notes
- Pins satisfy TF 2.13.x + coremltools 7.2 (protobuf/typing-extensions constraints).
- Expect a warning that TF 2.13.1 isn’t the latest tested by coremltools; conversion is validated here.

## Core ML Model I/O
Inputs (five images):
- Names: `f1`, `f2`, `f3`, `f4`, `f5`.
- Type: RGB images, size must be 768×432 (W×H); you must resize on iOS. Scale 1/255 is applied in‑model.
- Recommended: pass BGRA `CVPixelBuffer`s directly; Core ML converts BGRA→RGB internally.

Outputs (three tensors):
- `conf`: confidence grids, shape `[1, 5, 48, 27]` (Float16 in the bundled-model smoke test).
- `x_off`: X offsets (grid units), same shape and dtype.
- `y_off`: Y offsets (grid units), same shape and dtype.
- The leading dimension is batch size 1. The logical axes are temporal, width, height. The decoder validates each head independently and also accepts the tested unbatched and height/width storage variants; never assume shared strides.

Geometry
- Input spatial size inside the model: 768 (W) × 432 (H).
- Grid size: 48 × 27, so cell size = 16 px (both axes).

Pixel mapping (per frame index `t`):
- Find the winning `(row, col)` using each tensor’s declared axes and strides. For the bundled width-first layout, storage indices are `[0, t, col, row]`.
- `x_px = (col + x_offset) * 16`, `y_px_from_top = (row + y_offset) * 16`.
- Confidence threshold is `0.5`. Non-finite values or malformed storage reject the result.
- Use the originating frame’s mapping to reverse fit/fill preprocessing and convert to normalized source coordinates with a bottom-left origin. Points outside the source image, including portrait padding, are rejected.

Resizing
- Camera frames like 1920×1080 must be resized to 768×432 before prediction (same 16:9 aspect).
- The app orientation-normalizes each admitted image, then uses aspect-fit for portrait sources and aspect-fill for nonportrait sources. Preserve this distinction.
- Prepared pixels are app-owned; the five-frame snapshot retains their matching geometry, time, identity, and pose. Decoded coordinates map back to the oriented source frame.

## Swift Usage

The application uses `GridTrackNetDetector` to load the model, construct the five-image provider from an owned `AnalysisFrame.Window`, and decode against that same window. Keep raw tensor indexing in the tested decoder rather than copying pointer examples into callers.

Inside the app target, decoding the three model outputs uses:

```swift
// window is the exact owned snapshot supplied to this prediction.
let outputs = GridTrackNetDetector.RawOutputs(
  conf: conf,
  xOff: xOff,
  yOff: yOff
)
guard let samples = GridTrackNetDecoder.decode(outputs: outputs, window: window) else {
  // Malformed output: publish no detection.
  return
}
```

`GridTrackNetDecoder` checks FP16 dtype, supported shape, positive non-overlapping strides, overflow-safe storage span, and finite values using scoped byte access. It reads each head using that head’s own strides. `GridTrackNetDecoderTests` contains synthetic fixtures and a separate bundled-model smoke test.

Why Core ML directly (not Vision)
- Vision’s `VNCoreMLRequest` is optimized for single-image models; multi-input (5 frames) is simpler via `MLModel.prediction` with a keyed dictionary.

## Usage Pattern (recommended)
- Maintain five admitted frames in oldest-to-newest order. Busy analysis drops arriving frames before expensive work; actual temporal spacing can therefore be irregular and must remain visible in media timestamps.
- Predict once the owned window is full; overlapping windows reuse the four retained prepared frames.
- The decoder emits all five samples for cue evaluation. The displayed ball uses `t=4`; the cue detector consumes each source identity once and evaluates the middle of its three-entry history. There is no fixed analyzed-FPS or physical-audio-latency guarantee.
- See `docs/references/toss-cue-validation.md` for source/model provenance, regression evidence, and pending empirical checks.

## Gotchas / Tips
- Do not re-normalize inputs in Swift (model already applies 1/255 scale).
- Keep frame orientation and its stored mapping associated. Portrait fit padding and nonportrait fill cropping are intentional current behavior.
- Temporal alignment matters: the 5 frames should be contiguous and similarly spaced; avoid per-frame recentered crops.
- Grid is width=48, height=27 (cell size 16 px). Do not swap axes when decoding.
- Outputs are Float16; use the validated decoder’s scoped byte access and each tensor’s own strides.
- Performance: FP16 + `computeUnits = .all` enables Neural Engine/GPU where available. Using a sliding window (reuse 4 frames) reduces memory copies.

## Maintenance
- To update weights, replace `GridTrackNet/model_weights.h5` and re-run `convert_gridtracknet.py`.
- To change I/O names or shapes, edit the converter (stacking, output split) and re-convert.
- Minimum Core ML target is iOS 16; tennis-trainer currently targets iOS 18.5, so it’s supported.

---
Questions or tweaks (e.g., return coordinates directly from the model) can be accommodated by extending the converter wrapper.
