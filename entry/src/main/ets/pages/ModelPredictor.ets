import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { resourceManager } from '@kit.LocalizationKit';

const TAG = 'PetSnap';

/**
 * 模型信息配置 —— 与训练时 config.py 的参数保持一致
 */
export class ModelConfig {
  static readonly MODEL_NAME: string = 'pet.ms';
  static readonly INPUT_HEIGHT: number = 224;
  static readonly INPUT_WIDTH: number = 224;
  static readonly RESIZE_SHORT: number = 256;
  static readonly CROP_OFFSET: number = 16;
  // ImageNet 标准化参数（MobileNetV2 训练时使用）
  static readonly MEANS: number[] = [0.485, 0.456, 0.406];
  static readonly STDS: number[] = [0.229, 0.224, 0.225];
  // 分类标签
  static readonly LABELS: string[] = ['cat', 'dog'];
}

/**
 * 预测结果
 */
export interface PredictionResult {
  label: string;
  confidence: number;
}

/**
 * 猫狗分类模型推理器
 *
 * 封装了模型加载、图片预处理、推理执行和后处理
 */
export class CatDogPredictor {
  private model: mindSporeLite.Model | null = null;
  private modelLoaded: boolean = false;

  /**
   * 从 rawfile 加载 .ms 模型文件
   */
  async loadModel(resMgr: resourceManager.ResourceManager): Promise<void> {
    if (this.modelLoaded) {
      return;
    }

    try {
      hilog.info(0xFF00, TAG, '========== 开始加载模型 ==========');

      // 1. 从 rawfile 读取模型文件
      const rawFileData: Uint8Array = await resMgr.getRawFileContent(ModelConfig.MODEL_NAME);
      hilog.info(0xFF00, TAG, `模型文件大小: ${rawFileData.byteLength} bytes`);

      // 2. 创建推理上下文（CPU 推理，单线程）
      const context: mindSporeLite.Context = {
        target: ['cpu'],
        cpu: {
          threadNum: 1,
          threadAffinityMode: 1,
          precisionMode: 'enforce_fp32'
        }
      };

      // 3. 从内存 buffer 加载模型
      this.model = await mindSporeLite.loadModelFromBuffer(rawFileData.buffer as ArrayBuffer, context);

      if (!this.model) {
        throw new Error('模型加载返回 null');
      }

      this.modelLoaded = true;
      hilog.info(0xFF00, TAG, '========== 模型加载成功 ==========');
    } catch (err) {
      hilog.error(0xFF00, TAG, `模型加载失败: ${JSON.stringify(err)}`);
      throw new Error(`模型加载失败: ${err}`);
    }
  }

  /**
   * 图片预处理 —— 将 PixelMap 转换为模型输入张量
   *
   * 预处理流程（与训练完全一致）：
   *   RGBA → 丢弃 Alpha 通道提取 BGR → 归一化 (/255.0) → 标准化 (mean/std)
   */
  private preprocess(pixelMap: image.PixelMap): Float32Array {
    const height = ModelConfig.INPUT_HEIGHT;
    const width = ModelConfig.INPUT_WIDTH;
    const channels = 3;
    const float32Data = new Float32Array(height * width * channels);
    let imageInfo: image.ImageInfo;
    try {
      imageInfo = pixelMap.getImageInfoSync();
    } catch (e) {
      throw new Error('获取图片信息失败');
    }
    const rawWidth = imageInfo.size.width;
    const rawHeight = imageInfo.size.height;

    hilog.info(0xFF00, TAG, `预处理: 输入尺寸=${rawWidth}x${rawHeight}, 目标尺寸=${width}x${height}`);

    // 读取 PixelMap 的全部像素数据 (RGBA8888)
    const readBuffer = new ArrayBuffer(rawHeight * rawWidth * 4);
    pixelMap.readPixelsToBuffer(readBuffer);
    const pixels = new Uint8Array(readBuffer);

    const meanR: number = ModelConfig.MEANS[0];
    const meanG: number = ModelConfig.MEANS[1];
    const meanB: number = ModelConfig.MEANS[2];
    const stdR: number = ModelConfig.STDS[0];
    const stdG: number = ModelConfig.STDS[1];
    const stdB: number = ModelConfig.STDS[2];

    // BGR 通道重排 + 标准化
    let index = 0;
    for (let i = 0; i < pixels.length; i += 4) {
      if (index >= float32Data.length) {
        break;
      }
      // pixels[i] = R, pixels[i+1] = G, pixels[i+2] = B, pixels[i+3] = A
      float32Data[index]     = (pixels[i + 2] / 255.0 - meanB) / stdB; // B 通道
      float32Data[index + 1] = (pixels[i + 1] / 255.0 - meanG) / stdG; // G 通道
      float32Data[index + 2] = (pixels[i]     / 255.0 - meanR) / stdR; // R 通道
      index += 3;
    }

    hilog.info(0xFF00, TAG,
      `预处理完成: float32Data 长度=${float32Data.length}, 前6个值=[${float32Data[0].toFixed(4)}, ${float32Data[1].toFixed(4)}, ${float32Data[2].toFixed(4)}, ${float32Data[3].toFixed(4)}, ${float32Data[4].toFixed(4)}, ${float32Data[5].toFixed(4)}]`);

    return float32Data;
  }

  /**
   * 执行推理
   *
   * @param pixelMap 预处理后的图片 PixelMap（需已 resize + crop 到 224x224）
   * @returns 按置信度排序的分类结果列表
   */
  async predict(pixelMap: image.PixelMap): Promise<PredictionResult[]> {
    if (!this.model || !this.modelLoaded) {
      throw new Error('模型未加载，请先调用 loadModel()');
    }

    try {
      hilog.info(0xFF00, TAG, '========== 开始推理 ==========');

      // 1. 图片预处理
      const inputData = this.preprocess(pixelMap);

      // 2. 获取模型输入张量，填入数据
      const inputs: mindSporeLite.MSTensor[] = this.model.getInputs();
      if (inputs.length === 0) {
        throw new Error('模型没有输入张量');
      }
      hilog.info(0xFF00, TAG, `输入张量数: ${inputs.length}, 名称: ${inputs[0].name}`);

      inputs[0].setData(inputData.buffer as ArrayBuffer);

      // 3. 执行推理
      const outputs: mindSporeLite.MSTensor[] = await this.model.predict(inputs);
      hilog.info(0xFF00, TAG, `推理完成, 输出张量数: ${outputs.length}`);

      // 4. 解析输出 —— 2 分类, Softmax 输出
      const outputData = new Float32Array(outputs[0].getData());
      hilog.info(0xFF00, TAG, `原始输出: [${outputData[0].toFixed(4)}, ${outputData[1].toFixed(4)}]`);

      // 5. 后处理：生成带标签和置信度的结果
      const results: PredictionResult[] = [];
      for (let i = 0; i < Math.min(outputData.length, ModelConfig.LABELS.length); i++) {
        results.push({
          label: ModelConfig.LABELS[i],
          confidence: outputData[i]
        });
      }

      // 按置信度降序排列
      results.sort((a, b) => b.confidence - a.confidence);

      hilog.info(0xFF00, TAG, `分类结果: ${results[0].label} (${(results[0].confidence * 100).toFixed(2)}%)`);
      hilog.info(0xFF00, TAG, '========== 推理结束 ==========');

      return results;
    } catch (err) {
      hilog.error(0xFF00, TAG, `推理失败: ${JSON.stringify(err)}`);
      throw new Error(`推理失败: ${err}`);
    }
  }

  /**
   * 释放模型资源
   */
  release(): void {
    this.model = null;
    this.modelLoaded = false;
    hilog.info(0xFF00, TAG, '模型资源已释放');
  }

  get isModelLoaded(): boolean {
    return this.modelLoaded;
  }
}
