#!/usr/bin/env python3
"""Convert the existing Python project's MODNet into a bundled Core ML model."""
import argparse
import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def register_model(project: Path):
    """Register a model only after conversion has successfully created its file."""
    file_id = hashlib.sha1(b'MODNet.mlmodel').hexdigest()[:24].upper()
    build_id = hashlib.sha1(b'buildMODNet.mlmodel').hexdigest()[:24].upper()
    text = project.read_text()
    if file_id in text:
        return
    refs = (f'\n{file_id} = {{ isa = PBXFileReference; lastKnownFileType = file.mlmodel; path = MODNet.mlmodel; sourceTree = "<group>"; }};\n'
            f'{build_id} = {{ isa = PBXBuildFile; fileRef = {file_id}; }};')
    group = 'path = AutoIDPhoto; sourceTree = "<group>"; children = ('
    phase = 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ('
    if group not in text or phase not in text:
        raise RuntimeError('Project structure changed: add AutoIDPhoto/MODNet.mlmodel to the target in Xcode manually.')
    text = text.replace('objects = {', 'objects = {' + refs, 1)
    text = text.replace(group, group + file_id + ',', 1)
    text = text.replace(phase, phase + build_id + ',', 1)
    project.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/Users/jialishen/Coding/Python/AutoIDPhotos'))
    parser.add_argument('--checkpoint', choices=['webcam', 'photographic'], default='webcam')
    parser.add_argument('--trace-only', action='store_true', help='Validate PyTorch weights and tracing without conversion tools')
    parser.add_argument('--verify', action='store_true', help='Compare Core ML and PyTorch outputs on a deterministic tensor (requires a working local Core ML runtime)')
    args = parser.parse_args()
    source = args.source.resolve()
    checkpoint = source / 'MODNet' / 'pretrained' / f'modnet_{args.checkpoint}_portrait_matting.ckpt'
    if not checkpoint.is_file():
        parser.error(f'Missing checkpoint: {checkpoint}')
    import torch
    import numpy as np
    sys.path.insert(0, str(source))
    from MODNet.src.models.modnet import MODNet

    torch.set_num_threads(2)
    torch.manual_seed(7)
    net = MODNet(backbone_pretrained=False)
    state = torch.load(checkpoint, map_location='cpu', weights_only=True)
    net.load_state_dict({key.removeprefix('module.'): value for key, value in state.items()}, strict=True)
    net.eval()

    class MatteOnly(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.net = net
        def forward(self, image):
            return self.net(image, True)[2]

    wrapper = MatteOnly().eval()
    sample = torch.rand(1, 3, 512, 512) * 2 - 1
    with torch.no_grad():
        expected = wrapper(sample)
        traced = torch.jit.trace(wrapper, sample, check_trace=False)
        actual = traced(sample)
    np.testing.assert_allclose(actual.numpy(), expected.numpy(), atol=1e-5, rtol=1e-4)
    print('Weights loaded; TorchScript parity passed:', tuple(actual.shape), flush=True)
    if args.trace_only:
        return
    try:
        import coremltools as ct
    except ImportError as error:
        raise SystemExit('Missing coremltools. Run ./scripts/prepare-modnet.sh in a normal network-enabled terminal.') from error
    # Neural-network format supports CPU-only execution and avoids a Python runtime on iOS.
    model = ct.convert(traced, convert_to='neuralnetwork',
                       inputs=[ct.ImageType(name='image', shape=(1, 3, 512, 512),
                                            scale=2.0 / 255.0, bias=[-1.0, -1.0, -1.0],
                                            color_layout=ct.colorlayout.RGB)],
                       outputs=[ct.TensorType(name='matte')],
                       minimum_deployment_target=ct.target.iOS14,
                       compute_units=ct.ComputeUnit.CPU_ONLY)
    model.author = 'MODNet authors; Core ML conversion for AutoIDPhoto'
    model.short_description = f'MODNet {args.checkpoint} portrait matting; RGB 512x512; alpha output in [0,1].'
    model.input_description['image'] = 'RGB image; preprocessing: channel / 127.5 - 1'
    model.output_description['matte'] = 'Foreground alpha: [1,1,512,512], 0 background, 1 person'
    model.user_defined_metadata['checkpoint_sha256'] = hashlib.sha256(checkpoint.read_bytes()).hexdigest()
    model.user_defined_metadata['source'] = 'https://github.com/ZHKKKe/MODNet'
    output = ROOT / 'AutoIDPhoto' / 'MODNet.mlmodel'
    temporary = output.with_name('MODNet.pending.mlmodel')
    model.save(str(temporary))
    if args.verify:
        from PIL import Image
        rgb = np.random.default_rng(7).integers(0, 256, (512, 512, 3), dtype=np.uint8)
        normalized = torch.from_numpy(rgb.copy()).permute(2, 0, 1).float()[None] / 127.5 - 1
        with torch.no_grad():
            reference = wrapper(normalized).numpy()
        prediction = model.predict({'image': Image.fromarray(rgb)})['matte']
        error = float(np.abs(reference - prediction).mean())
        print('Core ML vs PyTorch mean absolute alpha error:', error)
        if not np.isfinite(error) or error > 0.02:
            raise RuntimeError('Core ML numerical comparison failed; model not registered.')
    temporary.replace(output)
    register_model(ROOT / 'AutoIDPhoto.xcodeproj' / 'project.pbxproj')
    print(f'Ready: {output}. Rebuild in Xcode to include MODNet.')


if __name__ == '__main__':
    main()
