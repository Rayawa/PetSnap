import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { CatDogPredictor, ModelConfig, PredictionResult } from './ModelPredictor';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@hms.hds.hdsBaseComponent';
import { LengthMetrics } from '@kit.ArkUI';
import { hdsMaterial, TitleSize } from '@kit.UIDesignKit';

const TAG = 'PetSnap';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Index {
  @Provide pathStack: NavPathStack = new NavPathStack();

  @State modelStatus: string = '正在加载模型...';
  @State modelStatusColor: string = '#FF9800';
  @State resultText: string = '';
  @State confidenceText: string = '';
  @State confidencePercent: number = 0;
  @State isPredicting: boolean = false;
  @State selectedImageUri: string = '';
  @State showResult: boolean = false;
  @State resultIsLowConfidence: boolean = false;
  @State animatedConfidencePercent: number = 0;
  @State resultOpacity: number = 0;
  private predictor: CatDogPredictor = new CatDogPredictor();

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, '========== 页面启动 ==========');
    this.initModel();
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, '========== 页面销毁 ==========');
    this.predictor.release();
  }

  private async initModel(): Promise<void> {
    hilog.info(DOMAIN, TAG, '开始加载模型');
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext !== undefined) {
        const resMgr = hostContext.resourceManager;
        await this.predictor.loadModel(resMgr);
        this.modelStatus = '模型就绪，可以开始识别';
        this.modelStatusColor = '#4CAF50';
        hilog.info(DOMAIN, TAG, '模型初始化成功');
      } else {
        hilog.error(DOMAIN, TAG, 'hostContext 为 undefined，模型初始化失败');
        this.modelStatus = '初始化失败';
        this.modelStatusColor = '#F44336';
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `模型初始化异常: ${JSON.stringify(err)}`);
      this.modelStatus = '模型加载失败';
      this.modelStatusColor = '#F44336';
    }
  }

  private async pickFromGallery(): Promise<void> {
    hilog.info(DOMAIN, TAG, '========== 打开相册选取 ==========');
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      hilog.info(DOMAIN, TAG, `相册选取完成, 图片数: ${result.photoUris.length}`);
      if (result.photoUris.length > 0) {
        this.selectedImageUri = result.photoUris[0];
        hilog.info(DOMAIN, TAG, `选中图片: ${this.selectedImageUri}`);
        this.resetResult();
        this.runInference();
      } else {
        hilog.warn(DOMAIN, TAG, '用户取消相册选取');
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `相册选取异常: ${JSON.stringify(err)}`);
    }
  }

  private async takePhoto(): Promise<void> {
    hilog.info(DOMAIN, TAG, '========== 启动拍照 ==========');
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      hilog.error(DOMAIN, TAG, '拍照失败: hostContext 为 undefined');
      return;
    }

    try {
      const pathDir: string = hostContext.filesDir;
      const fileName: string = `photo_${Date.now()}.jpg`;
      const filePath: string = `${pathDir}/${fileName}`;
      hilog.info(DOMAIN, TAG, `创建临时文件: ${filePath}`);
      const tmpFile = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.closeSync(tmpFile);

      const saveUri: string = fileUri.getUriFromPath(filePath);
      hilog.info(DOMAIN, TAG, `saveUri: ${saveUri}`);

      const pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        saveUri: saveUri
      };

      hilog.info(DOMAIN, TAG, '调用系统相机');
      const result: cameraPicker.PickerResult = await cameraPicker.pick(
        hostContext, [cameraPicker.PickerMediaType.PHOTO], pickerProfile
      );
      hilog.info(DOMAIN, TAG, `拍照返回: resultCode=${result.resultCode}, uri=${result.resultUri}`);

      if (result.resultCode === 0 && result.resultUri.length > 0) {
        this.selectedImageUri = result.resultUri;
        hilog.info(DOMAIN, TAG, `拍照成功, 图片: ${this.selectedImageUri}`);
        this.resetResult();
        this.runInference();
      } else {
        hilog.warn(DOMAIN, TAG, `用户取消拍照, resultCode=${result.resultCode}`);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `拍照异常: ${JSON.stringify(err)}`);
    }
  }

  private resetResult(): void {
    this.resultText = '';
    this.confidenceText = '';
    this.confidencePercent = 0;
    this.showResult = false;
    this.resultIsLowConfidence = false;
    this.animatedConfidencePercent = 0;
    this.resultOpacity = 0;
  }

  private async runInference(): Promise<void> {
    hilog.info(DOMAIN, TAG, '========== 开始推理 ==========');
    this.isPredicting = true;
    this.showResult = false;

    try {
      const file = fileIo.openSync(this.selectedImageUri, fileIo.OpenMode.READ_ONLY);
      hilog.info(DOMAIN, TAG, `打开图片文件成功, fd: ${file.fd}`);

      const imageSource: image.ImageSource = image.createImageSource(file.fd);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();
      const imageInfo: image.ImageInfo = pixelMap.getImageInfoSync();
      hilog.info(DOMAIN, TAG, `PixelMap 创建成功, 尺寸: ${imageInfo.size.width}x${imageInfo.size.height}`);

      const results: PredictionResult[] = await this.predictor.predict(pixelMap);
      const top: PredictionResult = results[0];
      const conf: number = top.confidence * 100;

      hilog.info(DOMAIN, TAG, `推理结果: label=${top.label}, confidence=${conf.toFixed(2)}%`);
      hilog.info(DOMAIN, TAG, `置信度阈值: ${(ModelConfig.CONFIDENCE_THRESHOLD * 100).toFixed(0)}%`);

      this.confidencePercent = conf;

      if (top.confidence < ModelConfig.CONFIDENCE_THRESHOLD) {
        hilog.warn(DOMAIN, TAG,
          `置信度 ${conf.toFixed(2)}% 低于阈值, 判定为非猫狗图片`);
        this.resultIsLowConfidence = true;
        this.resultText = '未能识别为猫或狗';
        this.confidenceText =
          `最高置信度 ${conf.toFixed(1)}%（${top.label === 'cat' ? '像猫' : '像狗'}），低于识别阈值 ${(ModelConfig.CONFIDENCE_THRESHOLD * 100).toFixed(0)}%`;
      } else {
        hilog.info(DOMAIN, TAG, `识别成功: ${top.label}`);
        this.resultIsLowConfidence = false;
        this.resultText = top.label === 'cat' ? '猫' : '狗';
        this.confidenceText = `置信度 ${conf.toFixed(1)}%`;
      }

      this.showResult = true;
      this.resultOpacity = 0;
      this.animatedConfidencePercent = 0;

      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.resultOpacity = 1;
        this.animatedConfidencePercent = conf;
      });

      pixelMap.release();
      fileIo.closeSync(file);
      hilog.info(DOMAIN, TAG, '========== 推理完成 ==========');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `推理异常: ${JSON.stringify(err)}`);
      this.resultText = '识别失败，请重试';
      this.confidenceText = '';
      this.confidencePercent = 0;
      this.resultIsLowConfidence = true;
      this.showResult = true;
    } finally {
      this.isPredicting = false;
    }
  }

  private getConfidenceBarColor(): Resource {
    if (this.resultIsLowConfidence) {
      return $r("app.color.confidence_warn");
    }
    if (this.confidencePercent >= 90) {
      return $r("app.color.confidence_high");
    }
    if (this.confidencePercent >= 70) {
      return $r("app.color.confidence_medium");
    }
    return $r("app.color.confidence_low");
  }

  linearGradientOptions: LinearGradientOptions = {
    angle: 45,
    colors: [[Color.Red, 0.0]]
  };

  build() {
    HdsNavigation(this.pathStack) {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
        Column() {
          Column().height(130)
          Stack({ alignContent: Alignment.Bottom }) {
            if (this.selectedImageUri.length > 0) {
              Image(this.selectedImageUri)
                .objectFit(ImageFit.Cover)
                .width('100%')
                .height('100%')
                .borderRadius(20)
            } else {
              Column({ space: 12 }) {
                SymbolGlyph($r("sys.symbol.xmark_picture")).fontSize(80).shaderStyle([new LinearGradientStyle(this.linearGradientOptions)])
                Text('当前暂无图片').fontSize(14).fontColor(Color.Red).margin({ bottom: 20 })
                Text('拍照或选择图片').fontSize(16).fontColor($r("app.color.text_hint"))
              }.width('100%').height('100%').justifyContent(FlexAlign.Center)
            }

            if (this.isPredicting) {
              Column({ space: 10 }) {
                LoadingProgress().width(32).height(32).color($r("app.color.loading_text"))
                Text('分析中...').fontSize(12).fontColor($r("app.color.loading_text"))
              }
              .width('100%')
              .height('100%')
              .backgroundColor($r("app.color.loading_overlay"))
              .justifyContent(FlexAlign.Center)
            }
          }
          .backgroundColor($r("app.color.card_bg"))
          .borderWidth(1).borderColor($r("app.color.border_light"))
          .width('92%')
          .aspectRatio(1)
          .borderRadius(20)
          .shadow({ radius: 15, color: $r("app.color.shadow"), offsetY: 6 })

          if (this.showResult && !this.isPredicting && this.selectedImageUri.length > 0) {
            Column({ space: 6 }) {
              Row() {
                Text(this.resultIsLowConfidence ? '⚠️' : '✅').fontSize(18)
                Text(this.resultText).fontSize(17).fontWeight(FontWeight.Bold).margin({ left: 8 })
              }.width('100%').margin({ bottom: 5 })
              Row() {
                Text('置信度').fontSize(14)
                Text(`${this.animatedConfidencePercent.toFixed(0)}%`).fontSize(14)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween)
              Stack({ alignContent: Alignment.Start }) {
                Row().width('100%').height(6).backgroundColor($r("app.color.bar_track")).borderRadius(3)
                Row().width(`${this.animatedConfidencePercent}%`).height(6)
                  .backgroundColor(this.getConfidenceBarColor())
                  .borderRadius(3)
                  .animation({ duration: 500, curve: Curve.EaseOut })
              }
            }
            .margin(16)
            .padding(12)
            .width('92%')
            .backgroundColor($r("app.color.result_card_bg"))
            .borderRadius(16)
            .opacity(this.resultOpacity)
            .margin({ top: 12 })
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
          }
        }
        .width('100%')
        .flexGrow(1)

        Column() {
          Row() {
            Circle({ width: 7, height: 7 }).fill(this.modelStatus === '模型就绪，可以开始识别' ? $r("app.color.status_ready") : $r("app.color.status_error"))
            Text(this.modelStatus).fontSize(14).fontColor($r("app.color.text_hint")).margin({ left: 8 })
          }
          .margin({ bottom: 20 })
          Text(`Powered by MindSpore Lite · MobileNetV2`)
            .fontColor($r("app.color.text_footer"))
            .fontSize(11)
            .margin(2)
          Text('HarmonyOS App by Ray Chen (Rayawa)')
            .fontColor($r("app.color.text_footer"))
            .fontSize(11)
        }
        .margin({ bottom: 30 })
        .width('100%')
      }
      .width("100%")
      .height("100%")
      .backgroundColor($r("app.color.app_bg"))
    }
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .width("100%")
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r("sys.color.ohos_id_color_background_transparent"),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r("sys.color.font_primary"),
              subTitleColor: $r("sys.color.font_secondary"),
            },
            menuStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
            backIconStyle: {
              backgroundColor: $r("sys.color.comp_background_tertiary"),
              iconColor: $r("sys.color.icon_primary"),
            },
          },
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      },
      content: {
        title: {
          mainTitle: "PetSnap猫狗识别",
          mainTitleSize: TitleSize.TITLE_ML,
        },
        menu: {
          value: [
            {
              content: {
                label: "camera",
                icon: $r("sys.symbol.camera"),
                isEnabled: true,
                action: () => { this.takePhoto() }
              },
            },
            {
              content: {
                label: "picture",
                icon: $r("sys.symbol.picture"),
                isEnabled: true,
                action: () => { this.pickFromGallery() }
              },
            },
          ],
        },
      },
    });
  }
}
