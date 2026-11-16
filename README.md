# MiniMax H3 Hybrid B25–49 · ComfyUI 参考生视频

这个工作流使用 MiniMax H3 Hybrid B25–49 INT8 底模和 Qwen3-VL Heretic INT8 ConvRot 编码器，从一张参考图生成带声音的 MP4。示例是水面上的红色纸船。

## 运行环境

- 使用支持 MiniMax H3 原生节点的 [ComfyUI](https://github.com/Comfy-Org/ComfyUI)。示例在 Windows、ComfyUI 0.45.0、RTX 5070 Ti 16 GB 显存和 32 GB 内存的机器上跑通。工作流只用内置节点，无需安装第三方节点包。
- 四份权重合计约 50.75 GB（47.26 GiB）。另预留 ComfyUI、下载缓存和输出空间。16 GB 显卡运行时会在显存和系统内存之间卸载权重，首轮读取模型需要时间。

## 下载模型

请按表格放入 `ComfyUI/` 下的对应目录，并保留原文件名。这里仅提供权重来源链接。

| 文件 | 放入目录 | 大小 | 下载 |
| --- | --- | ---: | --- |
| `minimax_h3_hybrid_fl2va_ref2va_b25-49-int8.safetensors` | `models/diffusion_models/` | 20.97 GB | [smhfacct](https://huggingface.co/smhfacct/Minimax-H3-fl2va-ref2va-hybrid-models/resolve/a36feb17fbd1f20ff4bdd509ccd07e2b7b585a38/minimax_h3_hybrid_fl2va_ref2va_b25-49-int8.safetensors) |
| `qwen3vl_32b_minimax_h3_ultra_uncensored_heretic_int8_convrot.safetensors` | `models/text_encoders/` | 26.36 GB | [OTMFLY](https://huggingface.co/OTMFLY/Qwen3-VL-32B-Ultra-Heretic-MiniMax-H3-ComfyUI-INT8-ConvRot/resolve/a7fc7d013153adb0fa77af64f6e859986fce4ac8/qwen3vl_32b_minimax_h3_ultra_uncensored_heretic_int8_convrot.safetensors) |
| `minimax_h3_video_vae_int8_convrot.safetensors` | `models/vae/` | 2.81 GB | [Comfy-Org](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_int8_convrot.safetensors) |
| `minimax_h3_audio_vae_fp32.safetensors` | `models/vae/` | 0.61 GB | [Comfy-Org](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors) |

## 导入并运行

1. 启动 ComfyUI。把 [minimax-h3-hybrid-r2v.json](minimax-h3-hybrid-r2v.json) 拖到画布上。
2. 在 **Load Image** 节点上传 [h3-hybrid-reference.png](h3-hybrid-reference.png)，或提前把图片放在 `ComfyUI/input/`。换自己的参考图时，在 **MiniMax H3 Reference to Video** 节点修改提示词，可用 `<Picture 1>` 指代第一张参考图。
3. 点 **运行（Queue）**。示例预设为 448 × 256、56 帧、24 fps、20 步。完成后在 **Save Video** 节点预览，也可在 `ComfyUI/output/video/` 找到 MP4。

## 来源与许可

工作流改编自 Comfy Org 的 [MiniMax H3 Reference to Video 模板](https://github.com/Comfy-Org/workflow_templates/blob/main/templates/video_minimax_h3_r2v.json)，保留原模板的 [MIT 许可及版权声明](LICENSE)。此许可适用于工作流。模型权重适用各自上游条款。 [底模说明](https://huggingface.co/smhfacct/Minimax-H3-fl2va-ref2va-hybrid-models) · [编码器说明](https://huggingface.co/OTMFLY/Qwen3-VL-32B-Ultra-Heretic-MiniMax-H3-ComfyUI-INT8-ConvRot) · [MiniMax H3 社区许可](https://huggingface.co/MiniMaxAI/MiniMax-H3/blob/main/LICENSE)
