#!/usr/bin/env python3
"""
Convert GridTrackNet to Core ML (.mlpackage) with:
- Five RGB image inputs: f1..f5, auto-resized to 432x768, scale=1/255
- Three outputs: conf, x_off, y_off each shaped (5, 48, 27)
Saves to: tennis-trainer/Tennis Trainer/Models/GridTrackNet5.mlpackage

Run:
  python3 convert_gridtracknet.py

Requires:
  pip install 'tensorflow>=2.10,<2.16' 'keras==2.11.*' 'coremltools>=7.0'
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import tensorflow as tf  # noqa: F401 (used within Lambda)
import keras
from keras.layers import Input, Lambda, Concatenate, Permute, Reshape
from keras.models import Model

import coremltools as ct


# Geometry
H, W, F = 432, 768, 5


def build_wrapped_model(repo_root: Path):
    """Builds a Keras wrapper around the repo's channels-first core model.

    Wrapper accepts five NHWC RGB images, scales handled by Core ML, stacks to
    NCHW (15xH xW), runs the core model, and splits 15 channels into three
    heads (conf/x_off/y_off) of shape (5, 48, 27).
    """
    # Import the core builder function from the submodule file.
    # Ensure the parent directory (containing GridTrackNet/) is on sys.path.
    parent_dir = str(repo_root)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    from GridTrackNet.GridTrackNet import GridTrackNet as BuildCore

    # Core model: channels_first input (15, H, W) -> (15, 48, 27)
    core = BuildCore(F, H, W)

    # Five NHWC image inputs (Core ML supplies 1/255-normalized RGB floats)
    f_in = [Input(shape=(H, W, 3), name=f"f{i+1}") for i in range(F)]

    # NHWC -> NCHW per image, then concat along channels to [N, 15, H, W]
    def to_nchw(t):
        return tf.transpose(t, [0, 3, 1, 2])

    nchw = [Lambda(to_nchw, name=f"to_nchw_{i+1}")(t) for i, t in enumerate(f_in)]
    x = Concatenate(axis=1, name="stack_5xRGB")(nchw)

    # Run core and split 15 channels -> (5 frames) x (3 heads)
    y = core(x)  # [N, 15, 48, 27] (C,H,W)
    y = Permute((2, 3, 1), name="to_HW_C")(y)  # [N, 48, 27, 15]
    y = Reshape((48, 27, 5, 3), name="to_HW_F3")(y)  # [N, 48, 27, 5, 3]
    y = Permute((3, 1, 2, 4), name="to_F_HW_C")(y)  # [N, 5, 48, 27, 3]

    conf = Lambda(lambda t: t[..., 0], name="conf")(y)  # [N, 5, 48, 27]
    x_off = Lambda(lambda t: t[..., 1], name="x_off")(y)  # [N, 5, 48, 27]
    y_off = Lambda(lambda t: t[..., 2], name="y_off")(y)  # [N, 5, 48, 27]

    return Model(inputs=f_in, outputs=[conf, x_off, y_off], name="GridTrackNet5Wrapper"), core


def main():
    script_dir = Path(__file__).resolve().parent
    # Assumption: GridTrackNet/ lives one level up from tennis-trainer/
    repo_root = script_dir.parent
    weights_path = repo_root / "GridTrackNet" / "model_weights.h5"
    save_path = script_dir / "Tennis Trainer" / "Models" / "GridTrackNet5.mlpackage"

    if not weights_path.exists():
        raise FileNotFoundError(f"Missing weights file: {weights_path}")

    wrapper, core = build_wrapped_model(repo_root)

    # Load weights into the core submodel
    core.load_weights(str(weights_path))

    # Define Core ML image inputs (NHWC, RGB), model will be converted to NCHW internally
    inputs_spec = [
        ct.ImageType(name=f"f{i+1}", shape=(1, H, W, 3), scale=1 / 255.0)
        for i in range(F)
    ]

    mlmodel = ct.convert(
        wrapper,
        source="tensorflow",
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS16,
        compute_units=ct.ComputeUnit.ALL,
        inputs=inputs_spec,
        compute_precision=ct.precision.FLOAT16,
    )

    # Verify/rename output names to: conf, x_off, y_off
    desired_out_names = ["conf", "x_off", "y_off"]
    spec = mlmodel.get_spec()
    out_names = [o.name for o in spec.description.output]
    if len(out_names) != 3:
        raise RuntimeError(
            f"Unexpected number of outputs from converter: {out_names}"
        )
    if out_names != desired_out_names:
        # Attempt rename on MLModel object (weights-aware)
        try:
            from coremltools.models.utils import rename_feature  # type: ignore
            for old, new in zip(out_names, desired_out_names):
                if old != new:
                    rename_feature(mlmodel, old, new)
            # refresh names
            spec = mlmodel.get_spec()
            out_names = [o.name for o in spec.description.output]
        except Exception as e:
            print("Warn: rename_feature(mlmodel, ...) failed:", e)

    if out_names != desired_out_names:
        # Fallback: rename on spec then rebuild MLModel with weights_dir
        try:
            from coremltools.models.utils import rename_feature  # type: ignore
            spec = mlmodel.get_spec()
            for old, new in zip(out_names, desired_out_names):
                if old != new:
                    rename_feature(spec, old, new)
            weights_dir = getattr(mlmodel, "_weights_dir", None)
            if weights_dir is None:
                raise RuntimeError("Could not locate weights_dir for rebuilt MLModel.")
            mlmodel = ct.models.MLModel(spec, weights_dir=weights_dir)
            spec = mlmodel.get_spec()
            out_names = [o.name for o in spec.description.output]
        except Exception as e:
            print("Warn: spec-level rename failed:", e)

    # Metadata and IO descriptions using the concrete names
    mlmodel.short_description = (
        "GridTrackNet (5 frames). Outputs conf/x_off/y_off grids per frame."
    )
    for i in range(F):
        mlmodel.input_description[f"f{i+1}"] = (
            f"RGB frame {i+1} of 5 (size must be {W}x{H} (WxH); pre-resize on iOS)."
        )
    # Map: 0->conf, 1->x_off, 2->y_off
    mlmodel.output_description[desired_out_names[0]] = "Confidence grids; shape (5, 48, 27)."
    mlmodel.output_description[desired_out_names[1]] = (
        "X offsets in grid cell units; shape (5, 48, 27)."
    )
    mlmodel.output_description[desired_out_names[2]] = (
        "Y offsets in grid cell units; shape (5, 48, 27)."
    )

    save_path.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(save_path))
    print("Output names:", [o.name for o in mlmodel.get_spec().description.output])
    print(f"Saved: {save_path}")


if __name__ == "__main__":
    main()
