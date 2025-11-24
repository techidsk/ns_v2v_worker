FROM runpod/worker-comfyui:5.5.1-base

# 调整 handler 配置
RUN sed -i \
    -e 's/^COMFY_API_AVAILABLE_INTERVAL_MS = [0-9]\+/COMFY_API_AVAILABLE_INTERVAL_MS = 500/' \
    -e 's/^COMFY_API_AVAILABLE_MAX_RETRIES = [0-9]\+/COMFY_API_AVAILABLE_MAX_RETRIES = 2000/' \
    /handler.py

# 固定时区，避免 tzdata 交互
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    TRITON_CACHE_DIR=/opt/triton-cache \
    TORCHINDUCTOR_CACHE_DIR=/opt/inductor-cache

# install custom nodes into comfyui
RUN comfy-node-install comfyui_essentials

# download models into comfyui
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors --relative-path models/vae --filename wan_2.1_vae.safetensors
RUN comfy model download --url https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22_relight/WanAnimate_relight_lora_fp16_resized_from_128_to_dynamic_22.safetensors --relative-path models/loras --filename WanAnimate_relight_lora_fp16_resized_from_128_to_dynamic_22.safetensors
RUN comfy model download --url https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors --relative-path models/unet --filename Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors
RUN comfy model download --url https://huggingface.co/lightx2v/Wan2.2-Distill-Loras/resolve/main/wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors --relative-path models/loras --filename wan2.2_i2v_A14b_low_noise_lora_rank64_lightx2v_4step_1022.safetensors
RUN comfy model download --url https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan22_PusaV1_lora_LOW_resized_dynamic_avg_rank_98_bf16.safetensors --relative-path models/loras --filename Wan22_PusaV1_lora_LOW_resized_dynamic_avg_rank_98_bf16.safetensors
RUN comfy model download --url https://huggingface.co/alibaba-pai/Wan2.2-Fun-Reward-LoRAs/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors --relative-path models/loras --filename Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors
RUN comfy model download --url https://huggingface.co/VeryAladeen/Sec-4B/resolve/main/SeC-4B-fp16.safetensors?download=true --relative-path models/sams --filename Sec-4B-fp16.safetensors
RUN comfy model download --url https://huggingface.co/Kijai/vitpose_comfy/resolve/ae68f4e542151cebec0995b8469c70b07b8c3df4/onnx/vitpose_h_wholebody_model.onnx --relative-path models/detection --filename vitpose_h_wholebody_model.onnx
RUN comfy model download --url https://huggingface.co/Kijai/vitpose_comfy/resolve/ae68f4e542151cebec0995b8469c70b07b8c3df4/onnx/vitpose_h_wholebody_data.bin --relative-path models/detection --filename vitpose_h_wholebody_data.bin
RUN comfy model download --url https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx --relative-path models/detection --filename yolov10m.onnx
RUN comfy model download --url https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors --relative-path models/clip --filename CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors
RUN comfy model download --url https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n.pt --relative-path models/ultralytics/bbox --filename face_yolov8n.pt
RUN comfy model download --url https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors --relative-path models/text_encoders --filename umt5_xxl_fp8_e4m3fn_scaled.safetensors

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
RUN comfy-node-install https://github.com/kijai/ComfyUI-KJNodes
RUN comfy-node-install https://github.com/1038lab/ComfyUI-RMBG
RUN comfy-node-install https://github.com/yolain/ComfyUI-Easy-Use
RUN comfy-node-install https://github.com/kijai/ComfyUI-GIMM-VFI
RUN comfy-node-install https://github.com/Stability-AI/stability-ComfyUI-nodes
RUN comfy-node-install https://github.com/WASasquatch/was-node-suite-comfyui
RUN comfy-node-install https://github.com/cubiq/ComfyUI_essentials
RUN comfy-node-install https://github.com/chflame163/ComfyUI_LayerStyle
RUN comfy-node-install https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
RUN comfy-node-install https://github.com/kijai/ComfyUI-WanVideoWrapper
RUN comfy-node-install https://github.com/kijai/ComfyUI-WanAnimatePreprocess
RUN comfy-node-install https://github.com/filliptm/ComfyUI_Fill-Nodes
RUN comfy-node-install https://github.com/9nate-drake/Comfyui-SecNodes

# 修改 handler.py 以支持 video 通过 URL 上传
RUN python3 << 'EOF'
import re

# 读取原始 handler.py
with open('/handler.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 在 upload_images 函数之后添加 upload_videos 函数
upload_videos_func = '''

def upload_videos(videos):
    """
    Upload a list of videos (base64 encoded or URL) to the ComfyUI server using the /upload/image endpoint.
    Note: ComfyUI uses the same endpoint for videos as it does for images.

    Args:
        videos (list): A list of dictionaries, each containing the 'name' of the video and either:
                      - 'video': a base64 encoded string
                      - 'url': a URL to download the video from

    Returns:
        dict: A dictionary indicating success or error.
    """
    if not videos:
        return {"status": "success", "message": "No videos to upload", "details": []}

    responses = []
    upload_errors = []

    print(f"worker-comfyui - Uploading {len(videos)} video(s)...")

    for video in videos:
        try:
            name = video["name"]

            # Check if video is provided as URL or base64
            if "url" in video and video["url"]:
                # Download video from URL
                print(f"worker-comfyui - Downloading video from URL: {video['url']}")
                video_response = requests.get(video["url"], timeout=120, stream=True)
                video_response.raise_for_status()

                # Get content type to determine video format
                content_type = video_response.headers.get('content-type', 'video/mp4')
                blob = video_response.content

            elif "video" in video and video["video"]:
                # Handle base64 encoded video
                video_data_uri = video["video"]

                # Strip Data URI prefix if present
                if "," in video_data_uri:
                    base64_data = video_data_uri.split(",", 1)[1]
                else:
                    base64_data = video_data_uri

                blob = base64.b64decode(base64_data)
                content_type = "video/mp4"  # Default to mp4
            else:
                raise ValueError(f"Video {name} must have either 'url' or 'video' field")

            # Prepare the form data (ComfyUI uses /upload/image for videos too)
            files = {
                "image": (name, BytesIO(blob), content_type),
                "overwrite": (None, "true"),
            }

            # POST request to upload the video
            response = requests.post(
                f"http://{COMFY_HOST}/upload/image", files=files, timeout=60
            )
            response.raise_for_status()

            responses.append(f"Successfully uploaded {name}")
            print(f"worker-comfyui - Successfully uploaded video {name}")

        except requests.exceptions.RequestException as e:
            error_msg = f"Error downloading video from URL for {video.get('name', 'unknown')}: {e}"
            upload_errors.append(error_msg)
            print(f"worker-comfyui - {error_msg}")
        except base64.binascii.Error as e:
            error_msg = f"Error decoding base64 for {video.get('name', 'unknown')}: {e}"
            upload_errors.append(error_msg)
            print(f"worker-comfyui - {error_msg}")
        except Exception as e:
            error_msg = f"Unexpected error uploading {video.get('name', 'unknown')}: {e}"
            upload_errors.append(error_msg)
            print(f"worker-comfyui - {error_msg}")

    if upload_errors:
        return {
            "status": "error",
            "message": "Some videos failed to upload",
            "details": responses + upload_errors,
        }

    return {"status": "success", "message": "All videos uploaded successfully", "details": responses}
'''

# 找到 upload_images 函数的结束位置并插入 upload_videos
# 查找 upload_images 函数后的下一个函数定义
match = re.search(r'(def upload_images.*?)\n(def \w+)', content, re.DOTALL)
if match:
    content = content[:match.end(1)] + upload_videos_func + '\n' + content[match.end(1):]
else:
    # 如果找不到下一个函数，就添加到文件末尾
    content += upload_videos_func

# 2. 修改 validate_input 函数以支持 videos 参数
# 在 images 验证之后添加 videos 验证
videos_validation = '''
    # Validate 'videos' in input, if provided
    videos = job_input.get("videos")
    if videos is not None:
        if not isinstance(videos, list) or not all(
            "name" in video and ("video" in video or "url" in video) for video in videos
        ):
            return None, "Invalid 'videos' format, must be a list of objects with 'name' and either 'video' (base64) or 'url'"
'''

# 在 images 验证代码块之后插入
pattern = r'(# Validate \'images\' in input.*?return None, "Invalid \'images\' format[^"]*")\s*\n'
match = re.search(pattern, content, re.DOTALL)
if match:
    content = content[:match.end()] + '\n' + videos_validation + content[match.end():]

# 3. 在 handler 函数中添加对 videos 的处理
# 查找 upload_images 调用的位置
pattern = r'(upload_result = upload_images\(validated_input\.get\("images"\)\))'
replacement = r'''\1

    # Handle video uploads if provided
    if "videos" in validated_input:
        upload_videos_result = upload_videos(validated_input.get("videos"))
        if upload_videos_result["status"] == "error":
            return {"error": upload_videos_result["message"], "details": upload_videos_result["details"]}'''

content = re.sub(pattern, replacement, content)

# 写回文件
with open('/handler.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("handler.py has been successfully modified to support video uploads via URL")
EOF
