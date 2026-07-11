import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CatDogPredictor, ModelConfig, PredictionResult } from './ModelPredictor';

const TAG = 'PetSnap';

@Entry
@Component
struct Index {
  // ==================== 状态变量 ====================

  /** 模型加载状态 */
  @State modelStatus: string = '正在加载模型...';
  /** 模型加载进度颜色 */
  @State modelStatusColor: string = '#FF9800';
  /** 预测结果文本 */
  @State resultText: string = '';
  /** 预测置信度 */
  @State confidenceText: string = '';
  /** 结果区域的背景色（根据分类变化） */
  @State resultBgColor: string = '#F5F5F5';
  /** 是否正在推理 */
  @State isPredicting: boolean = false;
  /** 选中的图片 URI */
  @State selectedImageUri: string = '';
  /** 上次分类的 top label */
  @State private lastTopLabel: string = '';
  /** 选择的图片文件描述符 (fd) */
  private selectedFd: number = -1;

  /** 模型推理器 */
  private predictor: CatDogPredictor = new CatDogPredictor();

  // ==================== 生命周期 ====================

  aboutToAppear(): void {
    // 页面出现时加载模型
    this.initModel();
  }

  aboutToDisappear(): void {
    // 页面销毁时释放模型
    this.predictor.release();
  }

  /**
   * 初始化模型 —— 从 rawfile 加载 pet.ms
   */
  private async initModel(): Promise<void> {
    try {
      const uiContext = this.getUIContext();
      if (!uiContext) {
        this.modelStatus = 'UI上下文获取失败';
        this.modelStatusColor = '#F44336';
        return;
      }
      const hostContext = uiContext.getHostContext();
      if (!hostContext) {
        this.modelStatus = 'Host上下文获取失败';
        this.modelStatusColor = '#F44336';
        return;
      }
      const resMgr = hostContext.resourceManager;

      await this.predictor.loadModel(resMgr);
      this.modelStatus = '模型已就绪';
      this.modelStatusColor = '#4CAF50';
    } catch (err) {
      this.modelStatus = `模型加载失败: ${err}`;
      this.modelStatusColor = '#F44336';
      hilog.error(0xFF00, TAG, `模型初始化失败: ${JSON.stringify(err)}`);
    }
  }

  // ==================== 图片选择 ====================

  /**
   * 从相册选择图片
   */
  private async pickFromGallery(): Promise<void> {
    try {
      const photoOptions = new photoAccessHelper.PhotoSelectOptions();
      photoOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoOptions.maxSelectNumber = 1;

      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(photoOptions);

      if (result.photoUris.length === 0) {
        return;
      }

      this.selectedImageUri = result.photoUris[0];
      this.resultText = '';
      this.confidenceText = '';
      this.lastTopLabel = '';
      hilog.info(0xFF00, TAG, `已选择图片: ${this.selectedImageUri}`);

      // 自动执行推理
      await this.runInference();
    } catch (err) {
      this.resultText = `选择图片失败: ${JSON.stringify(err)}`;
      this.resultBgColor = '#FFEBEE';
      this.lastTopLabel = '';
      hilog.error(0xFF00, TAG, `选择图片失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 打开相机拍照（占位，真机再实现）
   */
  private async takePhoto(): Promise<void> {
    this.resultText = '请使用真机测试拍照功能\n当前请使用"从相册选择"';
    this.resultBgColor = '#FFF3E0';
    this.confidenceText = '';
    this.lastTopLabel = '';
  }

  // ==================== 图片预处理 ====================

  /**
   * 图片预处理 pipeline —— 与训练时完全一致
   *
   *   原始图片 → Resize(256, 256) → CenterCrop(16, 16, 224, 224) → 标准化 (ModelPredictor 内部)
   */
  private async preprocessImage(fd: number): Promise<image.PixelMap> {
    const imageSource: image.ImageSource = image.createImageSource(fd);
    if (imageSource === undefined) {
      throw new Error('创建 ImageSource 失败');
    }

    const pixelMap = await imageSource.createPixelMap();
    const info = await pixelMap.getImageInfo();
    const origW: number = info.size.width;
    const origH: number = info.size.height;
    hilog.info(0xFF00, TAG, `原始图片尺寸: ${origW} x ${origH}`);

    const resizeRatio: number = ModelConfig.RESIZE_SHORT / Math.min(origW, origH);
    const targetW: number = Math.round(origW * resizeRatio);
    const targetH: number = Math.round(origH * resizeRatio);
    await pixelMap.scale(resizeRatio, resizeRatio);
    hilog.info(0xFF00, TAG, `Resize 后: ${targetW} x ${targetH}`);

    const scaleInfo = await pixelMap.getImageInfo();
    const scaledW: number = scaleInfo.size.width;
    const scaledH: number = scaleInfo.size.height;
    const cropX: number = Math.round((scaledW - ModelConfig.INPUT_WIDTH) / 2);
    const cropY: number = Math.round((scaledH - ModelConfig.INPUT_HEIGHT) / 2);
    hilog.info(0xFF00, TAG, `Crop 偏移: x=${cropX}, y=${cropY}`);

    await pixelMap.crop({
      x: cropX,
      y: cropY,
      size: { width: ModelConfig.INPUT_WIDTH, height: ModelConfig.INPUT_HEIGHT }
    });

    const cropInfo = await pixelMap.getImageInfo();
    hilog.info(0xFF00, TAG, `Crop 后: ${cropInfo.size.width} x ${cropInfo.size.height}`);

    return pixelMap;
  }

  // ==================== 推理 ====================

  /**
   * 执行完整的推理流程
   */
  private async runInference(): Promise<void> {
    if (!this.predictor.isModelLoaded) {
      this.resultText = '模型尚未加载';
      this.resultBgColor = '#FFEBEE';
      this.lastTopLabel = '';
      return;
    }

    if (!this.selectedImageUri) {
      this.resultText = '请先选择一张图片';
      this.resultBgColor = '#FFF3E0';
      this.lastTopLabel = '';
      return;
    }

    this.isPredicting = true;
    this.resultText = '正在识别...';
    this.resultBgColor = '#FFF3E0';

    try {
      // 1. 通过 URI 打开文件获取 fd
      const file = fileIo.openSync(this.selectedImageUri, fileIo.OpenMode.READ_ONLY);
      this.selectedFd = file.fd;
      hilog.info(0xFF00, TAG, `文件已打开, fd=${file.fd}`);

      // 2. 图片预处理
      const processedPixelMap = await this.preprocessImage(file.fd);

      // 3. 模型推理
      const results: PredictionResult[] = await this.predictor.predict(processedPixelMap);

      // 4. 关闭文件
      fileIo.closeSync(file);
      this.selectedFd = -1;

      // 5. 展示结果
      const topResult = results[0];
      this.lastTopLabel = topResult.label;
      if (topResult.label === 'cat') {
        this.resultText = '🐱 猫';
        this.resultBgColor = '#E8F5E9';
      } else {
        this.resultText = '🐶 狗';
        this.resultBgColor = '#FFF8E1';
      }
      this.confidenceText =
        `置信度: ${(topResult.confidence * 100).toFixed(1)}%\n` +
        `Cat: ${((results.find(r => r.label === 'cat')?.confidence ?? 0) * 100).toFixed(1)}%  |  ` +
        `Dog: ${((results.find(r => r.label === 'dog')?.confidence ?? 0) * 100).toFixed(1)}%`;

      hilog.info(0xFF00, TAG, `最终结果: ${this.resultText} ${this.confidenceText}`);

    } catch (err) {
      this.resultText = `识别失败: ${err}`;
      this.resultBgColor = '#FFEBEE';
      this.lastTopLabel = '';
      hilog.error(0xFF00, TAG, `推理失败: ${JSON.stringify(err)}`);
    } finally {
      this.isPredicting = false;
    }
  }

  // ==================== UI 构建 ====================

  build() {
    Column() {
      // ---- 标题栏 ----
      Row() {
        Text('PetSnap 猫狗分类识别')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

      // ---- 状态指示 ----
      Row() {
        Stack()
          .width(8)
          .height(8)
          .backgroundColor(this.modelStatusColor)
          .borderRadius(4)
        Text(this.modelStatus)
          .fontSize(14)
          .fontColor(this.modelStatusColor)
          .margin({ left: 6 })
      }
      .margin({ top: 12, bottom: 4 })

      // ---- 图片预览区域 ----
      Column() {
        if (this.selectedImageUri) {
          Image(this.selectedImageUri)
            .objectFit(ImageFit.Contain)
            .width('100%')
            .height('100%')
        } else {
          Column() {
            Text('📷')
              .fontSize(48)
              .margin({ bottom: 8 })
            Text('选择一张猫或狗的照片')
              .fontSize(15)
              .fontColor('#999999')
          }
        }
      }
      .width('100%')
      .height(280)
      .backgroundColor('#FAFAFA')
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .margin({ left: 16, right: 16, top: 12 })

      // ---- 操作按钮 ----
      Row() {
        // 相册选择
        Button() {
          Text('从相册选择')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }
        .type(ButtonType.Capsule)
        .backgroundColor('#E3F2FD')
        .fontColor('#1565C0')
        .layoutWeight(1)
        .height(44)
        .margin({ right: 8 })
        .onClick(() => {
          this.pickFromGallery();
        })

        // 拍照（暂用相同逻辑示意，真实设备上走 takePhoto）
        Button() {
          Text('拍照识别')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }
        .type(ButtonType.Capsule)
        .backgroundColor('#FFF3E0')
        .fontColor('#E65100')
        .layoutWeight(1)
        .height(44)
        .margin({ left: 8 })
        .onClick(() => {
          this.takePhoto();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ top: 12 })

      // ---- 推理中 Loading ----
      if (this.isPredicting) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#1565C0')
          .margin({ top: 16 })
        Text('模型推理中...')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 })
      }

      // ---- 识别结果 ----
      if (this.resultText && !this.isPredicting) {
        Column() {
          Text(this.resultText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.lastTopLabel === 'cat' ? '#2E7D32' : (this.lastTopLabel === 'dog' ? '#E65100' : '#666666'))

          if (this.confidenceText) {
            Text(this.confidenceText)
              .fontSize(14)
              .fontColor('#666666')
              .margin({ top: 8 })
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16, left: 16, right: 16 })
        .backgroundColor(this.resultBgColor)
        .borderRadius(12)
        .margin({ left: 16, right: 16, top: 16 })
      }

      // ---- 底部空白 ----
      Blank()

      // ---- 底部提示 ----
      Text('Powered by MindSpore Lite · MobileNetV2')
        .fontSize(11)
        .fontColor('#BBBBBB')
        .margin({ bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }
}
