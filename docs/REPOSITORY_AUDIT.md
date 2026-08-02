# Focused repository audit

Audit scope is limited to the six shallow snapshots listed in
`docs/REFERENCE_LOCK.json`. The observations below are from checked-in files at
the locked commits; README marketing claims are not treated as runtime proof.

## Phase 1 integration facts

| Repository | Usable fact for a future design | Evidence inspected | License |
| --- | --- | --- | --- |
| `elliotttate/SpliceKit` | A candidate programmatic FCP boundary: MCP client sends newline-delimited JSON-RPC to `127.0.0.1:9876`; source bridge dispatches private ObjC calls and includes FCPXML import/export. Its patcher reads the installed app version and targets a copied app path. | `mcp/server.py:1-45,795-805,1469-1558`; `Sources/SpliceKitServer.m:1-13,63,1816-1908,28341-28389`; `patcher/patch_fcp.sh:18-34,227-233,265-272`; `docs/FCPXML_FORMAT_REFERENCE.md:35-47` | MIT (`LICENSE`) |
| `Comfy-Org/ComfyUI` | A local, modular node-graph engine with an HTTP/API-oriented server, workflow JSON, asynchronous queue, custom-node directory, and Apple Silicon support stated in the README. This is a potential out-of-process media/model worker, not an FCP control plane. | `README.md:38-43,47-58,105-116`; `server.py:1-19`; `requirements.txt:1-37`; top-level `custom_nodes/`, `api_server/`, `comfy_execution/` | GPL-3.0 (`LICENSE`) |
| `BrokenSource/DepthFlow` | Python package/CLI (`depthflow` and `depth`) for image-to-video parallax; declares Python >=3.10 and dependencies including Torch, Transformers, ShaderFlow, Pillow, NumPy, and SciPy. It can be a candidate depth/parallax worker if dependencies/models are separately validated. | `readme.md:16-23`; `pyproject.toml:1-31` | AGPL-3.0 (`license.txt`) |
| `akatz-ai/ComfyUI-Depthflow-Nodes` | ComfyUI custom nodes expose image + depth map + motion/effects inputs, frame-rate/quality controls, and batch-image output for later video encoding. Requirements pin `depthflow==0.9.1` plus NumPy/Pydantic/OpenCV. | `README.md:29-52,76-115,117-129`; `requirements.txt:1-4`; top-level `__init__.py`, `src/`, `example_workflows/` | AGPL-3.0 (`LICENSE`) |
| `AEmotionStudio/ComfyUI-FFMPEGA` | A ComfyUI extension with an FFmpeg-based editing path, no-LLM/manual mode, preview/batch concepts, and a video-editor node described in its release table. Its declared required dependencies are small, but optional AI features have additional installs. | `README.md:30-55,66-107`; `requirements.txt:1-22`; top-level `nodes/`, `core/`, `videoeditor/`, `skills/` | GPL-3.0 (`LICENSE`) |
| `DannyMac180/sol-advisor` | Governance/reference only: defines orchestrator, routine/harder implementation lanes, and a fresh read-only Sol review. It is not a media or FCP runtime dependency. | `README.md:1-22,65-90`; `.codex-plugin/` is absent in this shallow snapshot; top-level `plugins/` | MIT (`LICENSE`) |

## Deferred or irrelevant surfaces

- SpliceKit's patcher, code signing, dylib injection, private FCP runtime calls,
  screenshots, and bridge behavior are deferred until an authorized design and
  isolated copy test exist. They were inspected but not executed.
- ComfyUI model downloads, API-server startup, custom-node installation, and
  GPU/Metal performance are untested. No model weights or Python environments
  were installed.
- DepthFlow depth-estimation model acquisition, shader/GPU support, and actual
  ProRes output are untested. The package metadata does not establish a working
  local pipeline.
- The Depthflow node pack's Flex integration and example workflows are source
  references only; the declared `depthflow==0.9.1` dependency may not match the
  locked DepthFlow source snapshot and must be resolved explicitly.
- FFMPEGA's optional LLM providers, AI models, skills, browser/editor UI, and
  third-party model installers are out of Stage 1/2 scope. Its GPLv3 license and
  transitive model licenses require review before redistribution.
- Sol Advisor files document delegation governance only; they do not prove that
  the local Codex installation or any FCP/Comfy runtime is available.

## Cross-repository conclusion

The narrowest evidence-backed Phase 1 seam is a future out-of-process media
worker (ComfyUI/DepthFlow/FFMPEGA candidates) producing declared artifacts under
the Movies runtime directories, paired with a separately verified FCP interchange
or control boundary (FCPXML first; SpliceKit JSON-RPC only if an isolated copied
FCP build is later proven). No repository in this audit proves a safe, installed,
end-to-end FCPCommandConsole workflow today.
