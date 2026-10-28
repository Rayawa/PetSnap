# PetSnap — MindSpore Lite Cat and Dog Classification App for HarmonyOS

English | [简体中文](README_zh.md)


## Project overview

PetSnap is a HarmonyOS app for classifying cat and dog images, using **MindSpore Lite** for real-time on-device inference. Users can select a gallery image or take a photo, and the app identifies whether the animal is a **cat** or a **dog**.

- **Task**: Binary classification (cat / dog)
- **Model architecture**: MobileNetV2 (frozen backbone + fine-tuned head)
- **Inference engine**: MindSpore Lite (CPU inference, FP32 precision)
- **Dataset**: Kaggle Cats vs Dogs (PetImages)
- **Model file**: `pet.ms` (MindSpore Lite format, bundled in the app's rawfile resources, ~2 MB)
- **Confidence threshold**: 70% (images below this threshold are treated as neither a cat nor a dog)
- **UI framework**: ArkUI + HdsNavigation, with adaptive light/dark modes
- **Input size**: 224×224 pixels

> For model training and conversion, see the [original project README](https://github.com/rayawaa/PetSnap).

---

## Contents

- [Project structure](#project-structure)
- [Key files](#key-files)
- [Requirements](#requirements)
- [Build and run](#build-and-run)
- [Inference flow](#inference-flow)
- [Key configuration parameters](#key-configuration-parameters)
- [License](#license)

---

## Project structure

```
PetSnap-HarmonyOS/
├── AppScope/
│   └── app.json5                      # Global app configuration (package, version, icon, title)
│
├── entry/                             # Main module (entry)
│   ├── build-profile.json5            # Module build configuration
│   ├── hvigorfile.ts                  # Module Hvigor task entry point
│   ├── obfuscation-rules.txt          # Code obfuscation rules
│   ├── oh-package.json5               # Module dependencies
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/
│       │   │   │   └── EntryAbility.ets          # App UIAbility entry point
│       │   │   ├── entrybackupability/
│       │   │   │   └── EntryBackupAbility.ets    # Backup extension capability
│       │   │   └── pages/
│       │   │       ├── Index.ets                 # Main page (UI interactions and inference calls)
│       │   │       └── ModelPredictor.ets        # Inference wrapper (loading/preprocessing/inference)
│       │   ├── module.json5          # Module configuration (Ability, permissions, routes)
│       │   ├── syscap.json           # System capabilities (MindSpore Lite)
│       │   └── resources/
│       │       ├── base/
│       │       │   ├── element/      # String, color, and dimension resources
│       │       │   ├── media/        # App icons
│       │       │   └── profile/      # Page routes and backup configuration
│       │       ├── dark/
│       │       │   └── element/      # Dark mode colors
│       │       └── rawfile/
│       │           └── pet.ms        # MindSpore Lite model (~2 MB)
│       ├── ohosTest/                 # On-device UI tests
│       └── test/                     # Local unit tests
│
├── hvigor/
│   └── hvigor-config.json5           # Global Hvigor engine configuration
├── hvigorfile.ts                     # Project Hvigor task entry point
├── build-profile.json5               # Project build configuration (signing, SDK, modules)
├── oh-package.json5                  # Project dependencies
└── code-linter.json5                 # Lint rules
```

---

## Key files

### Entry points and app framework

| File | Description |
|------|------|
| `entry/src/main/ets/entryability/EntryAbility.ets` | App UIAbility entry point; loads `pages/Index` in `onWindowStageCreate` |
| `entry/src/main/ets/entrybackupability/EntryBackupAbility.ets` | Backup extension capability (`BackupExtensionAbility`) |
| `entry/src/main/module.json5` | Module manifest: declares EntryAbility, the route table (`$profile:main_pages`), and gallery read permission |
| `entry/src/main/resources/base/profile/main_pages.json` | Page routes pointing to `pages/Index` |

### Core application code

| File | Description |
|------|------|
| `entry/src/main/ets/pages/Index.ets` | Main page: uses `HdsNavigation` for an immersive title bar with a gradient blur scroll effect and camera/gallery menu entries; includes image previews, loading animations, animated confidence progress bars, result cards, and complete interactions |
| `entry/src/main/ets/pages/ModelPredictor.ets` | Core inference module containing `CatDogPredictor` (model loading, preprocessing, inference, and postprocessing) and `ModelConfig` (model hyperparameters) |

### UI features

- **Immersive navigation bar**: `HdsNavigation` with `ScrollEffectType.GRADIENT_BLUR` for gradient blur on scroll and the `MaterialType.IMMERSIVE` system material
- **Dark mode**: Separate colors in `resources/base/` and `resources/dark/`, switching automatically with the system theme
- **Confidence animation**: Results fade in through `animateTo` with an animated progress bar, using green/yellow/orange for different confidence ranges
- **Status indicators**: Colored dots and text report model loading status in real time
- **Loading state**: A translucent overlay and LoadingProgress during inference

### Inference model

| File | Description |
|------|------|
| `entry/src/main/resources/rawfile/pet.ms` | Trained and converted MindSpore Lite model using MobileNetV2, 224×224 input, and two output classes (cat/dog) |

### Build and configuration

| File | Description |
|------|------|
| `build-profile.json5` | Project build configuration: signing certificates, SDK version (API 21, HarmonyOS), and debug/release modes |
| `entry/build-profile.json5` | Module build configuration: Stage mode and obfuscation policies (property/export-name obfuscation in release) |
| `hvigorfile.ts` | Root Hvigor build tasks (`@ohos/hvigor-ohos-plugin`) |
| `entry/hvigorfile.ts` | Module Hvigor build tasks |
| `code-linter.json5` | ESLint and security rule checks |
| `entry/src/main/syscap.json` | Declares the `SystemCapability.AI.MindSporeLite` dependency |

---

## Requirements

| Component | Version / description |
|------|-----------|
| Operating system | macOS / Windows |
| DevEco Studio | 5.0 or later |
| SDK | API 21 (HarmonyOS 6.0.1) |
| Device | HarmonyOS phone or tablet supporting the MindSpore Lite system capability |

---

## Build and run

### 1. Install DevEco Studio

Download and install DevEco Studio from the [HarmonyOS developer website](https://developer.huawei.com/consumer/cn/deveco-studio/).

### 2. Open the project

Select **Open** in DevEco Studio and locate the `PetSnap-HarmonyOS/` directory.

### 3. Configure signing

DevEco Studio uses automatic signing (debug certificates) by default. For physical-device debugging, configure the corresponding certificate in **File → Project Structure → Signing Configs**.

### 4. Build

Choose **Build → Build HAP(s)** in DevEco Studio, or use the command line:

```bash
cd PetSnap-HarmonyOS
hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug
```

Build outputs are in `entry/build/default/outputs/`.

### 5. Run

- **Emulator**: Use the built-in DevEco Studio emulator and click Run.
- **Physical device**: Connect a HarmonyOS device by USB, enable developer mode and USB debugging, then click Run.

---

## Inference flow

```
Select image / take photo → Decode to PixelMap → Preprocess → MindSpore Lite inference → Softmax postprocessing → Display result
```

### Preprocessing (`ModelPredictor.preprocess`)

Preprocessing matches the training stage exactly:

1. **Size**: The system image decoder has already resized/cropped the input PixelMap to 224×224.
2. **Channel reordering**: RGBA → BGR (discard Alpha).
3. **Normalization**: `pixel / 255.0`
4. **Standardization**:
   - Mean: `[0.485, 0.456, 0.406]`
   - Standard deviation: `[0.229, 0.224, 0.225]`

> During training, the shortest image edge is resized to `RESIZE_SHORT=256`, then center-cropped with `CROP_OFFSET=16` to produce 224×224 input. During inference, the HarmonyOS `Image` component uses `objectFit(ImageFit.Cover)` with a 1:1 container for aspect-preserving fill and cropping.

### Inference (`CatDogPredictor.predict`)

1. Call `preprocess()` to convert the PixelMap to a `Float32Array`.
2. Get the model input tensors (`model.getInputs()`) and fill them with preprocessed data.
3. Run `model.predict(inputs)` to obtain raw logits.
4. Compute Softmax manually to obtain a probability distribution.
5. Return `PredictionResult[]` sorted by descending confidence.

### Postprocessing (`Index.runInference`)

- Select the class with the highest confidence.
- If confidence is below 70% (`CONFIDENCE_THRESHOLD`), treat the image as neither cat nor dog and display "未能识别为猫或狗" (could not identify a cat or dog).
- Otherwise, display "猫" (cat) or "狗" (dog) and the confidence percentage.

### Model configuration (`ModelConfig`)

```typescript
export class ModelConfig {
  static readonly MODEL_NAME: string = 'pet.ms';
  static readonly INPUT_HEIGHT: number = 224;
  static readonly INPUT_WIDTH: number = 224;
  static readonly RESIZE_SHORT: number = 256;
  static readonly CROP_OFFSET: number = 16;
  static readonly MEANS: number[] = [0.485, 0.456, 0.406];
  static readonly STDS: number[] = [0.229, 0.224, 0.225];
  static readonly LABELS: string[] = ['cat', 'dog'];
  static readonly CONFIDENCE_THRESHOLD: number = 0.7;
}
```

> `RESIZE_SHORT` and `CROP_OFFSET` are training preprocessing parameters. During inference, system components have already resized/cropped the image to 224×224, so preprocessing uses that size directly.

---

## Key configuration parameters

| Parameter | Value | Description |
|------|-----|------|
| `bundleName` | `top.rayawa.pet_snap` | App package name |
| `targetSdkVersion` | `6.0.1(21)` | Target SDK version |
| `compatibleSdkVersion` | `6.0.1(21)` | Compatible SDK version |
| `runtimeOS` | `HarmonyOS` | Runtime operating system |
| `apiType` | `stageMode` | Stage mode |
| `INPUT_WIDTH / INPUT_HEIGHT` | 224 | Model input size |
| `RESIZE_SHORT` | 256 | Shortest-edge resize for training |
| `CROP_OFFSET` | 16 | Center-crop offset for training |
| `MEANS` | `[0.485, 0.456, 0.406]` | Standardization means (ImageNet) |
| `STDS` | `[0.229, 0.224, 0.225]` | Standardization standard deviations (ImageNet) |
| `CONFIDENCE_THRESHOLD` | 0.7 | Confidence threshold |
| `CPU threadNum` | 1 | Inference thread count |
| `CPU precisionMode` | `enforce_fp32` | Inference precision mode |
| Permission | `ohos.permission.READ_IMAGEVIDEO` | Gallery read permission |

---

## License

Project code is licensed under the **Apache License 2.0** (Copyright 2020 Huawei Technologies Co., Ltd).

The dataset uses the Microsoft Research license agreement.
