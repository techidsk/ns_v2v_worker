# ComfyUI Worker API 接口文档

## 概述

本文档描述了支持视频通过URL上传的ComfyUI Worker接口。此worker基于RunPod的worker-comfyui，并扩展了视频上传功能。

## 基础信息

- **端点**: RunPod Serverless Endpoint
- **方法**: POST
- **内容类型**: application/json

## 请求格式

### 请求体结构

```json
{
  "input": {
    "workflow": {},
    "images": [],
    "videos": []
  }
}
```

### 参数说明

#### workflow (必需)

类型: `object`

ComfyUI的工作流JSON对象，定义了图像/视频处理流程。

#### images (可选)

类型: `array`

图像上传数组，每个元素包含：

| 字段 | 类型 | 必需 | 描述 |
|------|------|------|------|
| name | string | 是 | 图像文件名（例如: "input.png"） |
| image | string | 是 | Base64编码的图像数据，可包含Data URI前缀 |

**示例:**

```json
{
  "images": [
    {
      "name": "input_image.png",
      "image": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
    }
  ]
}
```

#### videos (可选) - 新增功能

类型: `array`

视频上传数组，每个元素包含：

| 字段 | 类型 | 必需 | 描述 |
|------|------|------|------|
| name | string | 是 | 视频文件名（例如: "input.mp4"） |
| url | string | 二选一 | 视频文件的URL地址 |
| video | string | 二选一 | Base64编码的视频数据，可包含Data URI前缀 |

**注意**: 每个视频对象必须包含 `url` 或 `video` 其中之一。

## 请求示例

### 示例 1: 使用URL上传视频

```json
{
  "input": {
    "workflow": {
      "3": {
        "inputs": {
          "seed": 42,
          "steps": 20,
          "cfg": 8,
          "sampler_name": "euler",
          "scheduler": "normal",
          "denoise": 1,
          "model": ["4", 0],
          "positive": ["6", 0],
          "negative": ["7", 0],
          "latent_image": ["5", 0]
        },
        "class_type": "KSampler"
      }
    },
    "videos": [
      {
        "name": "input_video.mp4",
        "url": "https://example.com/videos/sample.mp4"
      }
    ]
  }
}
```

### 示例 2: 使用Base64上传视频

```json
{
  "input": {
    "workflow": {...},
    "videos": [
      {
        "name": "input_video.mp4",
        "video": "data:video/mp4;base64,AAAAIGZ0eXBpc29tAAACAGlzb21pc28y..."
      }
    ]
  }
}
```

### 示例 3: 同时上传图像和视频

```json
{
  "input": {
    "workflow": {...},
    "images": [
      {
        "name": "reference.png",
        "image": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg..."
      }
    ],
    "videos": [
      {
        "name": "input_video.mp4",
        "url": "https://cdn.example.com/video.mp4"
      },
      {
        "name": "mask_video.mp4",
        "url": "https://cdn.example.com/mask.mp4"
      }
    ]
  }
}
```

## 响应格式

### 成功响应

```json
{
  "status": "COMPLETED",
  "output": {
    "message": "Job completed successfully",
    "images": [
      "base64_encoded_output_image_1",
      "base64_encoded_output_image_2"
    ]
  }
}
```

### 错误响应

#### 验证错误

```json
{
  "status": "FAILED",
  "error": "Invalid 'videos' format, must be a list of objects with 'name' and either 'video' (base64) or 'url'"
}
```

#### 上传错误

```json
{
  "status": "FAILED",
  "error": "Some videos failed to upload",
  "details": [
    "Successfully uploaded input_video.mp4",
    "Error downloading video from URL for mask_video.mp4: 404 Not Found"
  ]
}
```

## 技术细节

### 视频上传机制

1. **URL下载**:
   - 超时时间: 120秒
   - 支持流式下载
   - 自动从响应头获取Content-Type

2. **Base64解码**:
   - 自动剥离Data URI前缀
   - 默认Content-Type为 `video/mp4`

3. **上传端点**:
   - 使用ComfyUI的 `/upload/image` 端点
   - 设置 `overwrite=true` 自动覆盖同名文件
   - 超时时间: 60秒

### 支持的视频格式

- MP4 (推荐)
- MOV
- AVI
- WebM
- 其他ComfyUI支持的视频格式

### 限制

- 单个视频文件下载超时: 120秒
- 单个视频上传超时: 60秒
- 文件大小限制取决于ComfyUI配置

## 错误码

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| Missing 'workflow' parameter | 缺少必需的workflow参数 | 确保请求包含workflow对象 |
| Invalid 'videos' format | videos数组格式不正确 | 检查每个video对象是否包含name和url/video字段 |
| Error downloading video from URL | URL无法访问或下载超时 | 检查URL有效性，确保网络连接正常 |
| Error decoding base64 | Base64编码格式错误 | 检查base64字符串是否正确编码 |
| Unexpected error uploading | 其他上传错误 | 查看详细错误信息进行排查 |

## 日志输出

Worker会输出以下日志信息，便于调试：

```
worker-comfyui - Uploading 2 video(s)...
worker-comfyui - Downloading video from URL: https://example.com/video.mp4
worker-comfyui - Successfully uploaded video input_video.mp4
```

## 最佳实践

1. **使用URL上传**（推荐）:
   - 减少请求体大小
   - 更快的传输速度
   - 避免base64编码开销

2. **文件命名**:
   - 使用唯一的文件名避免冲突
   - 包含正确的文件扩展名（.mp4, .mov等）

3. **错误处理**:
   - 检查响应中的details字段获取详细错误信息
   - 对于URL上传，确保URL公网可访问

4. **性能优化**:
   - 对于大文件优先使用URL方式
   - 将视频托管在CDN上以获得更好的下载速度

## 版本历史

- **v1.1** (2025-11-24): 添加视频URL上传支持
- **v1.0**: 基础图像处理功能
