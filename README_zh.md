# PetSnap

[English](README.md) | 简体中文

通过 MindSpore Lite 运行猫狗分类模型的 HarmonyOS 图片识别应用。

## 项目概述

应用接收相册图片或拍摄结果，按内置模型要求预处理并展示分类分数，推理在设备端完成。置信度阈值属于展示规则，不代表模型具备通用动物检测能力。

## 技术栈与依赖

ArkTS、ArkUI/HDS、MindSpore Lite、HarmonyOS API 21、OHPM、Hvigor。应用使用 224×224 输入的 `pet.ms` 模型；运行环境需支持 MindSpore Lite。

## 文件结构

- `entry/src/main/ets/` — ArkTS 应用代码
- `entry/src/main/resources/` — 资源与路由
- `AppScope/` — 应用配置
- `build-profile.example.json5` — 构建配置模板
- `oh-package.json5` — 包依赖
- `entry/src/main/ets/pages/Index.ets` — 图片输入与结果界面
- `entry/src/main/ets/pages/ModelPredictor.ets` — 模型加载、预处理与推理
- `entry/src/main/resources/rawfile/pet.ms` — 推理模型

## 快速上手

1. 使用 DevEco Studio 打开仓库根目录，并安装 `build-profile.example.json5` 指定的 SDK。
2. 将模板复制为 `build-profile.json5`，恢复 OHPM 依赖；如需真机安装，在本地配置签名。
3. 选择 `entry` 模块和兼容设备或模拟器，在 IDE 中构建运行。证书及机器路径不进入版本控制。

确认 `entry/src/main/resources/rawfile/` 中存在 `pet.ms`。通过系统选择器选图，或授予所需相机权限后拍照，再查看分类结果。
