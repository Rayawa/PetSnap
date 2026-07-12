# PetSnap — 基于 MindSpore Lite 的猫狗分类 HarmonyOS App

## 项目概述

PetSnap 是一款基于 HarmonyOS 的猫狗图像分类应用，使用 **MindSpore Lite** 在端侧完成实时推理。用户可从相册选取图片或拍照，应用将自动识别图像中的动物是 **猫** 还是 **狗**。

- **任务类型**：二分类（猫 / 狗）
- **模型架构**：MobileNetV2（Backbone 冻结 + Head 微调）
- **推理引擎**：MindSpore Lite（CPU 推理，FP32 精度）
- **数据集**：Kaggle Cats vs Dogs (PetImages)
- **模型文件**：`pet.ms`（MindSpore Lite 格式，集成于应用 rawfile 中，~2MB）
- **置信度阈值**：70%（低于此值判定为非猫狗图片）
- **UI 框架**：ArkUI + HdsNavigation，支持亮色/暗色模式自适应
- **输入尺寸**：224×224 像素

> 模型的训练、转换流程详见[原项目 README](https://github.com/rayawaa/PetSnap)。

---

## 目录

- [项目结构](#项目结构)
- [主要文件说明](#主要文件说明)
- [环境要求](#环境要求)
- [构建与运行](#构建与运行)
- [推理流程](#推理流程)
- [关键配置参数](#关键配置参数)
- [许可证](#许可证)

---

## 项目结构

```
PetSnap-HarmonyOS/
├── AppScope/
│   └── app.json5                      # 应用全局配置（包名、版本号、图标、标题）
│
├── entry/                             # 主模块（entry）
│   ├── build-profile.json5            # 模块构建配置
│   ├── hvigorfile.ts                  # 模块级 Hvigor 任务入口
│   ├── obfuscation-rules.txt          # 代码混淆规则
│   ├── oh-package.json5               # 模块依赖声明
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/
│       │   │   │   └── EntryAbility.ets          # 应用入口 UIAbility
│       │   │   ├── entrybackupability/
│       │   │   │   └── EntryBackupAbility.ets    # 备份扩展能力
│       │   │   └── pages/
│       │   │       ├── Index.ets                 # 主页面（UI 交互与推理调用）
│       │   │       └── ModelPredictor.ets        # 推理引擎封装（模型加载/预处理/推理）
│       │   ├── module.json5          # 模块配置（Ability、权限、路由）
│       │   ├── syscap.json           # 系统能力声明（MindSpore Lite）
│       │   └── resources/
│       │       ├── base/
│       │       │   ├── element/      # 字符串、颜色、尺寸资源
│       │       │   ├── media/        # 应用图标资源
│       │       │   └── profile/      # 页面路由、备份配置
│       │       ├── dark/
│       │       │   └── element/      # 暗色模式颜色资源
│       │       └── rawfile/
│       │           └── pet.ms        # MindSpore Lite 模型文件 (~2MB)
│       ├── ohosTest/                 # 设备端 UI 测试
│       └── test/                     # 本地单元测试
│
├── hvigor/
│   └── hvigor-config.json5           # Hvigor 引擎全局配置
├── hvigorfile.ts                     # 项目级 Hvigor 任务入口
├── build-profile.json5               # 项目构建配置（签名、SDK、模块列表）
├── oh-package.json5                  # 项目依赖声明
└── code-linter.json5                 # 代码 lint 规则
```

---

## 主要文件说明

### 入口与应用框架

| 文件 | 说明 |
|------|------|
| `entry/src/main/ets/entryability/EntryAbility.ets` | 应用的 UIAbility 入口，在 `onWindowStageCreate` 中加载 `pages/Index` |
| `entry/src/main/ets/entrybackupability/EntryBackupAbility.ets` | 备份扩展能力（`BackupExtensionAbility`） |
| `entry/src/main/module.json5` | 模块清单：声明 EntryAbility、路由表（`$profile:main_pages`）、相册读取权限 |
| `entry/src/main/resources/base/profile/main_pages.json` | 页面路由配置，指向 `pages/Index` |

### 核心业务代码

| 文件 | 说明 |
|------|------|
| `entry/src/main/ets/pages/Index.ets` | 主界面页面：使用 `HdsNavigation` 实现沉浸式标题栏（滑动渐变模糊效果），标题栏菜单提供拍照和相册选取入口；包含图片预览、加载动画、置信度进度条动画、结果卡片等完整交互 |
| `entry/src/main/ets/pages/ModelPredictor.ets` | 推理引擎核心模块，包含 `CatDogPredictor` 类（封装模型加载、预处理、推理、后处理）和 `ModelConfig` 类（模型超参配置） |

### UI 特性

- **沉浸式导航栏**：`HdsNavigation` 搭配 `ScrollEffectType.GRADIENT_BLUR` 实现滑动渐变模糊效果，`MaterialType.IMMERSIVE` 系统材质
- **暗色模式**：`resources/base/` 和 `resources/dark/` 独立配色，自动跟随系统主题切换
- **置信度动画**：识别结果以 `animateTo` 渐显 + 进度条动画展示，依置信度区间显示不同颜色（绿/黄/橙）
- **状态指示**：模型加载状态以彩色圆点 + 文字实时反馈
- **加载态**：推理过程中显示半透明遮罩 + LoadingProgress

### 推理模型

| 文件 | 说明 |
|------|------|
| `entry/src/main/resources/rawfile/pet.ms` | 训练并转换后的 MindSpore Lite 模型，MobileNetV2 架构，224×224 输入，2 分类输出（cat/dog） |

### 构建与配置

| 文件 | 说明 |
|------|------|
| `build-profile.json5` | 项目级构建配置：签名证书、SDK 版本（API 21, HarmonyOS）、debug/release 模式 |
| `entry/build-profile.json5` | 模块构建配置：Stage 模式、混淆策略（release 下启用属性/导出名混淆） |
| `hvigorfile.ts` | 根 Hvigor 构建任务（`@ohos/hvigor-ohos-plugin`） |
| `entry/hvigorfile.ts` | 模块 Hvigor 构建任务 |
| `code-linter.json5` | ESLint + 安全规则检查配置 |
| `entry/src/main/syscap.json` | 声明系统能力依赖 `SystemCapability.AI.MindSporeLite` |

---

## 环境要求

| 组件 | 版本/说明 |
|------|-----------|
| 操作系统 | macOS / Windows |
| DevEco Studio | 5.0 及以上 |
| SDK | API 21 (HarmonyOS 6.0.1) |
| 设备 | HarmonyOS 手机或平板（支持 MindSpore Lite 系统能力） |

---

## 构建与运行

### 1. 安装 DevEco Studio

前往 [HarmonyOS 开发者官网](https://developer.huawei.com/consumer/cn/deveco-studio/) 下载并安装 DevEco Studio。

### 2. 打开项目

在 DevEco Studio 中选择 **Open** → 定位到 `PetSnap-HarmonyOS/` 目录。

### 3. 配置签名

DevEco Studio 默认使用自动签名（调试证书）。如需真机调试，请在 **File → Project Structure → Signing Configs** 中配置对应证书。

### 4. 构建

在 DevEco Studio 中点击 **Build → Build HAP(s)**，或通过命令行：

```bash
cd PetSnap-HarmonyOS
hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug
```

构建产物在 `entry/build/default/outputs/` 目录下。

### 5. 运行

- **模拟器**：DevEco Studio 内置模拟器，直接点击 Run 按钮
- **真机**：USB 连接 HarmonyOS 设备，开启开发者模式及 USB 调试，点击 Run 按钮

---

## 推理流程

```
选择图片 / 拍照 → 图片解码为 PixelMap → 预处理 → MindSpore Lite 推理 → Softmax 后处理 → 展示结果
```

### 预处理（`ModelPredictor.preprocess`）

与训练阶段预处理完全一致：

1. **尺寸要求**：输入 PixelMap 已由系统图片解码组件缩放/裁剪至 224×224
2. **通道重排**：RGBA → BGR（丢弃 Alpha 通道）
3. **归一化**：`pixel / 255.0`
4. **标准化**：
   - 均值 `[0.485, 0.456, 0.406]`
   - 标准差 `[0.229, 0.224, 0.225]`

> 训练阶段先将图片最短边缩放到 `RESIZE_SHORT=256`，再中心裁剪 `CROP_OFFSET=16` 得到 224×224 输入。推理时则由 HarmonyOS `Image` 组件的 `objectFit(ImageFit.Cover)` 配合 1:1 容器完成等比填充裁剪。

### 推理（`CatDogPredictor.predict`）

1. 调用 `preprocess()` 将 PixelMap 转换为 `Float32Array`
2. 获取模型输入张量 (`model.getInputs()`)，填入预处理后的数据
3. 执行 `model.predict(inputs)` 获取原始 logits
4. 手动计算 Softmax 得到概率分布
5. 按置信度降序排列返回 `PredictionResult[]`

### 后处理（`Index.runInference`）

- 取最高置信度类别
- 若置信度 < 70%（`CONFIDENCE_THRESHOLD`），判定为非猫狗图片，显示 "未能识别为猫或狗"
- 否则显示 "猫" 或 "狗" 及置信度百分比

### 模型配置（`ModelConfig`）

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

> `RESIZE_SHORT` 和 `CROP_OFFSET` 为训练阶段的预处理参数，推理时图片已由系统组件缩放/裁剪至 224×224，故预处理阶段直接使用该尺寸。

---

## 关键配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| `bundleName` | `top.rayawa.pet_snap` | 应用包名 |
| `targetSdkVersion` | `6.0.1(21)` | 目标 SDK 版本 |
| `compatibleSdkVersion` | `6.0.1(21)` | 兼容 SDK 版本 |
| `runtimeOS` | `HarmonyOS` | 运行时系统 |
| `apiType` | `stageMode` | Stage 模式 |
| `INPUT_WIDTH / INPUT_HEIGHT` | 224 | 模型输入尺寸 |
| `RESIZE_SHORT` | 256 | 训练用最短边缩放尺寸 |
| `CROP_OFFSET` | 16 | 训练用中心裁剪偏移 |
| `MEANS` | `[0.485, 0.456, 0.406]` | 标准化均值 (ImageNet) |
| `STDS` | `[0.229, 0.224, 0.225]` | 标准化标准差 (ImageNet) |
| `CONFIDENCE_THRESHOLD` | 0.7 | 置信度阈值 |
| `CPU threadNum` | 1 | 推理线程数 |
| `CPU precisionMode` | `enforce_fp32` | 推理精度模式 |
| 权限 | `ohos.permission.READ_IMAGEVIDEO` | 相册读取权限 |

---

## 许可证

本项目代码基于 **Apache License 2.0**（Copyright 2020 Huawei Technologies Co., Ltd）。

数据集使用 Microsoft Research 许可协议。
