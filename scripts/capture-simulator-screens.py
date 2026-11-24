#!/usr/bin/env python3
"""Build/run AutoIDPhoto and capture real Simulator pages after manual navigation."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import re
import shlex
import struct
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = Path('/Users/jialishen/Work/MobileSoft/Projects/AutoIDPhoto')
FALLBACK_OUTPUT = ROOT / 'design/screen-agent/AutoIDPhoto'
BUNDLE = 'com.jialishen.AutoIDPhoto'


def execute(command, *, timeout=120, check=True):
    print('$ ' + shlex.join(map(str, command)), flush=True)
    result = subprocess.run(list(map(str, command)), cwd=ROOT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            errors='replace', timeout=timeout)
    if check and result.returncode:
        raise RuntimeError(result.stdout.strip() or f'Command failed: {command}')
    return result


def choose_device(data, requested=None):
    devices = []
    for runtime, group in data.get('devices', {}).items():
        for device in group:
            if device.get('isAvailable') and 'iPhone' in device.get('name', ''):
                devices.append({**device, 'runtime': runtime})
    if requested:
        matches = [device for device in devices if device['udid'] == requested]
        if not matches:
            raise RuntimeError('指定 UDID 不是可用的 iPhone 模拟器，请先运行 xcrun simctl list devices available。')
        return matches[0]
    if not devices:
        raise RuntimeError('没有可用的 iPhone 模拟器；请在 Xcode 中安装 runtime 并创建模拟器。')
    booted = [device for device in devices if device['state'] == 'Booted']
    if len(booted) > 1:
        raise RuntimeError('有多个已启动的 iPhone 模拟器，请用 --device 明确指定 UDID，避免误拍。')
    return booted[0] if booted else sorted(devices, key=lambda item: (item['runtime'], item['name']), reverse=True)[0]


def output_directory(requested):
    for path in [requested, FALLBACK_OUTPUT]:
        try:
            path.mkdir(parents=True, exist_ok=True)
            probe = path / ('.screen-writecheck-' + uuid.uuid4().hex)
            with probe.open('xb') as file:
                file.write(b'')
            probe.unlink()
            if path != requested:
                print(f'目标目录不可写，改存工作区：{path}', flush=True)
            return path
        except PermissionError:
            if path == FALLBACK_OUTPUT:
                raise
    raise RuntimeError('没有可写的截图目录。')


def next_version(directory):
    version = 1
    while (list(directory.glob(f'Screenshot-*-v{version}.png')) or
           list(directory.glob(f'Screenshots-*-v{version}.*'))):
        version += 1
    return version


def png_properties(path):
    with path.open('rb') as file:
        header = file.read(29)
    if len(header) < 29 or header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
        raise RuntimeError(f'无效 PNG：{path}')
    width, height = struct.unpack('>II', header[16:24])
    if width < 500 or height < 500:
        raise RuntimeError(f'图片不像原生模拟器截图：{width} × {height}')
    return {'width': width, 'height': height, 'format': 'PNG',
            'alpha_channel': (header[25] in (4, 6)) if header[25] != 3 else 'palette transparency not inspected',
            'orientation': 'portrait' if height >= width else 'landscape', 'bytes': path.stat().st_size}


def save_json(path, contents):
    with path.open('x', encoding='utf-8') as file:
        json.dump(contents, file, ensure_ascii=False, indent=2)
        file.write('\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--language', choices=['en', 'zh-Hans'], default='en', help='目标截图语言；截屏前使用 App 右上角语言按钮确认')
    parser.add_argument('--device', help='明确指定 iPhone Simulator UDID；否则优先使用唯一已启动的 iPhone')
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--include-photo-pages', action='store_true', help='额外拍编辑/生成页；请先准备已获授权可公开的测试照片')
    args = parser.parse_args()
    directory = output_directory(args.output.expanduser().resolve())
    version = next_version(directory)
    manifest_path = directory / f'Screenshots-Manifest-v{version}.json'
    manifest = {'project': str(ROOT), 'requested_output': str(args.output),
                'actual_output': str(directory), 'created_utc': datetime.now(timezone.utc).isoformat(),
                'bundle_id': BUNDLE, 'scheme': 'AutoIDPhoto', 'language': args.language, 'language_verification': 'manual confirmation before capture',
                'screenshots': [], 'status': 'preparing', 'visual_review': 'pending',
                'app_store_spec_validation': 'not performed; native simulator screenshots',
                'limitations': ['模拟器不支持真实摄像头；本脚本不验证相机功能。',
                                '需逐张查看图片确认实际页面、无弹窗及无敏感信息；图片未做合成、裁切或缩放。']}
    try:
        manifest['xcode'] = execute(['xcodebuild', '-version']).stdout.strip()
        result = execute(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], timeout=30)
        device = choose_device(json.loads(result.stdout), args.device)
        manifest['simulator'] = device
        udid = device['udid']
        print(f'本次仅操作 {device["name"]}（{udid}）', flush=True)
        if device['state'] != 'Booted':
            execute(['xcrun', 'simctl', 'boot', udid])
        execute(['open', '-a', '/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'])
        execute(['xcrun', 'simctl', 'bootstatus', udid, '-b'], timeout=180)
        derived = Path(tempfile.mkdtemp(prefix='autoid-screen-build-', dir='/private/tmp'))
        command = ['xcodebuild', '-project', 'AutoIDPhoto.xcodeproj', '-scheme', 'AutoIDPhoto',
                   '-configuration', 'Debug', '-sdk', 'iphonesimulator', '-destination', f'id={udid}',
                   '-derivedDataPath', derived, 'CODE_SIGNING_ALLOWED=NO', 'build']
        manifest['build_command'] = list(map(str, command))
        manifest['derived_data'] = str(derived)
        build = execute(command, timeout=1200, check=False)
        log_path = directory / f'Screenshots-Build-v{version}.log'
        with log_path.open('x', encoding='utf-8') as file:
            file.write(build.stdout)
        manifest['build_log'] = str(log_path)
        if build.returncode:
            raise RuntimeError(f'构建失败，未安装或截图。日志：{log_path}')
        app = derived / 'Build/Products/Debug-iphonesimulator/AutoIDPhoto.app'
        with (app / 'Info.plist').open('rb') as file:
            info = plistlib.load(file)
        manifest['app_version'] = info.get('CFBundleShortVersionString')
        manifest['app_build'] = info.get('CFBundleVersion')
        if info.get('CFBundleIdentifier') != BUNDLE:
            raise RuntimeError('构建产物的 Bundle ID 与目标 App 不符，已停止。')
        execute(['xcrun', 'simctl', 'install', udid, app])
        execute(['xcrun', 'simctl', 'terminate', udid, BUNDLE], check=False)
        manifest['launch_result'] = execute(['xcrun', 'simctl', 'launch', udid, BUNDLE]).stdout.strip()
        manifest['status'] = 'running'
        print('截屏前请使用 App 右上角地球按钮确认界面语言：' + ('English' if args.language == 'en' else '简体中文'))
        pages = [('main', '首页：确认已显示当前 App 主界面，无弹窗、无载入中状态'),
                 ('settings', '参数设置页：点击“Photo & Print Settings / 证件照与打印规格”，确认参数已显示、键盘关闭')]
        if args.include_photo_pages:
            pages += [('editor', '照片编辑页：只导入已获授权可公开的测试照片，显示头部方框'),
                      ('result', '生成结果页：实际生成成功后，显示证件照和打印拼版')]
        device_name = re.sub(r'[^A-Za-z0-9]+', '-', device['name']).strip('-')
        for number, (label, description) in enumerate(pages, 1):
            print('\n请手动在上述指定模拟器中切换页面：' + description)
            response = input('确认页面合适后回车截图；s 跳过，q 结束：').strip().lower()
            if response == 'q':
                break
            if response == 's':
                continue
            path = directory / f'Screenshot-{number:02d}-{label}-{device_name}-{args.language}-v{version}.png'
            if path.exists():
                raise FileExistsError(path)
            execute(['xcrun', 'simctl', 'io', udid, 'screenshot', '--type=png', path])
            properties = png_properties(path)
            manifest['screenshots'].append({'file': path.name, 'page': label, 'description': description,
                                            'capture_command': f'xcrun simctl io {udid} screenshot --type=png', **properties})
            print(f'已保存 {path.name}：{properties["width"]} × {properties["height"]}', flush=True)
        manifest['status'] = 'captured' if manifest['screenshots'] else 'no screenshots selected'
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired, EOFError, KeyboardInterrupt) as error:
        manifest['status'] = 'blocked' if not manifest['screenshots'] else 'partial'
        manifest['error'] = str(error)
        print(f'未完成：{error}', file=sys.stderr)
    finally:
        save_json(manifest_path, manifest)
        print(f'记录：{manifest_path}', flush=True)
    return 0 if manifest['status'] == 'captured' else 1


if __name__ == '__main__':
    sys.exit(main())
