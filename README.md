# PetSnap

English | [简体中文](README_zh.md)

A HarmonyOS image-classification application that runs a cat/dog model with MindSpore Lite.

## Overview

The application accepts a selected image or camera capture, preprocesses it for the bundled model and displays classification scores. Inference runs on the device. The confidence threshold is a display heuristic and does not make the model a general animal detector.

## Technology and Dependencies

ArkTS, ArkUI/HDS, MindSpore Lite, HarmonyOS API 21, OHPM and Hvigor. The application uses a 224×224 input model stored as `pet.ms`; runtime availability depends on device support for MindSpore Lite.

## Repository Structure

- `entry/src/main/ets/` — ArkTS application code
- `entry/src/main/resources/` — resources and routes
- `AppScope/` — application metadata
- `build-profile.example.json5` — build configuration template
- `oh-package.json5` — package dependencies
- `entry/src/main/ets/pages/Index.ets` — image input and result UI
- `entry/src/main/ets/pages/ModelPredictor.ets` — model loading, preprocessing and inference
- `entry/src/main/resources/rawfile/pet.ms` — inference model

## Quick Start

1. Open the repository root in DevEco Studio with the SDK required by `build-profile.example.json5`.
2. Copy that template to `build-profile.json5`, restore OHPM dependencies and configure signing locally if installing on a device.
3. Select the `entry` module and a compatible device/emulator, then build and run from the IDE. Keep certificates and machine-specific paths outside version control.

Confirm that `pet.ms` is present in `entry/src/main/resources/rawfile/`. Select an image from the system picker or grant the requested camera permission and take a photo; inspect the resulting classification scores.
