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


def choose_device(data, requested=None, family="iphone"):
    devices = []
    for runtime, group in data.get('devices', {}).items():
        for device in group:
            if device.get('isAvailable') and ('iPad' if family == 'ipad' else 'iPhone') in device.get('name', ''):
                devices.append({**device, 'runtime': runtime})
    if requested:
        matches = [device for device in devices if device['udid'] == requested]
        if not matches:
            raise RuntimeError(f'指定 UDID 不是可用的 {family} 模拟器，请先运行 xcrun simctl list devices available。')
        if family == 'ipad' and not ('13-inch' in matches[0]['name'] or '12.9-inch' in matches[0]['name']):
            raise RuntimeError('iPad 商店截图需要13英寸或12.9英寸设备，指定设备不匹配。')
        return matches[0]
    if family == 'ipad':
        devices = [device for device in devices if '13-inch' in device['name'] or '12.9-inch' in device['name']]
    if not devices:
        raise RuntimeError('没有可用的匹配模拟器；iPad 商店截图需要 13 英寸或 12.9 英寸设备。')
    booted = [device for device in devices if device['state'] == 'Booted']
    if len(booted) > 1:
        raise RuntimeError('有多个已启动的匹配模拟器，请用 --device 明确指定 UDID，避免误拍。')
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
    parser.add_argument('--language', choices=['en', 'zh-Hans', 'both'], default='en', help='目标截图语言；both 依次拍英文与简体中文')
    parser.add_argument('--device-family', choices=['iphone', 'ipad'], default='iphone', help='ipad 使用原生 13/12.9 英寸设备，每种语言恰好三个状态')
    parser.add_argument('--demo-photo', type=Path, default=ROOT / 'design/demo/cartoon-portrait.png', help='已确认可公开的演示图片，用 simctl addmedia 导入')
    parser.add_argument('--device', help='明确指定匹配设备族的 Simulator UDID；否则优先已启动设备')
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
        device = choose_device(json.loads(result.stdout), args.device, args.device_family)
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
        if args.include_photo_pages or args.device_family == 'ipad':
            if not args.demo_photo.is_file():
                raise RuntimeError(f'演示图片不存在：{args.demo_photo}')
            execute(['xcrun', 'simctl', 'addmedia', udid, args.demo_photo])
            manifest['demo_photo'] = str(args.demo_photo)
        languages = ['en', 'zh-Hans'] if args.language == 'both' else [args.language]
        manifest['languages'] = languages
        manifest['device_family'] = args.device_family
        device_name = re.sub(r'[^A-Za-z0-9]+', '-', device['name']).strip('-')
        if args.device_family == 'ipad':
            pages = [('settings', '启动规格页：确认目标语言，选择蓝色照片背景，返回表单顶部，关闭键盘。不要点击确定，先拍这一张'),
                     ('editor', '点击确定，然后用文件夹选择已导入的 cartoon-portrait.png；拖动方框对齐头顶、下巴，确认绿框；不拍黑色实时相机画面'),
                     ('result', '点击生成，等待实际单张证件照与8张拼版出现，必要时滚动以展示生成结果；不能拍载入/错误或权限弹窗')]
        else:
            pages = [('main', '首页：确认当前App界面已显示，无弹窗、无载入中状态'),
                     ('settings', '参数设置页：点击规格设置图标，确认参数已显示，键盘关闭')]
            if args.include_photo_pages:
                pages += [('editor', '导入已获授权的演示照片，显示正确头部方框'),
                          ('result', '实际生成成功后，显示证件照和打印拼版')]
        manifest['requested_count'] = len(languages) * len(pages)
        for language in languages:
            execute(['xcrun', 'simctl', 'terminate', udid, BUNDLE], check=False)
            # NSArgumentDomain scopes the requested app language to this launch.
            launch = execute(['xcrun', 'simctl', 'launch', udid, BUNDLE,
                              '-appInterfaceLanguage', language])
            manifest.setdefault('launch_results', {})[language] = launch.stdout.strip()
            manifest['status'] = 'running'
            print('本轮目标语言：' + ('English (UK)' if language == 'en' else '简体中文'))
            print('请确认竖屏、App真实运行、界面无弹窗；脚本只截图，不代替你操作页面。')
            for number, (label, description) in enumerate(pages, 1):
                print('\n请手动在指定模拟器中切换页面：' + description)
                response = input('已确认真实页面正确后回车截图；s 跳过，q 结束：').strip().lower()
                if response == 'q':
                    raise RuntimeError('用户结束截图流程')
                if response == 's':
                    continue
                filename_language = 'en-GB' if language == 'en' else language
                path = directory / f'Screenshot-{number:02d}-{label}-{device_name}-{filename_language}-v{version}.png'
                if path.exists():
                    raise FileExistsError(path)
                execute(['xcrun', 'simctl', 'io', udid, 'screenshot', '--type=png', path])
                properties = png_properties(path)
                if args.device_family == 'ipad' and (properties['width'], properties['height']) not in {(2064, 2752), (2048, 2732)}:
                    raise RuntimeError(f'实际截图不是13英寸iPad可上传竖屏尺寸：{properties}')
                entry = {'file': path.name, 'page': label, 'description': description,
                         'language': filename_language, 'user_confirmed_page': True,
                         'capture_command': f'xcrun simctl io {udid} screenshot --type=png', **properties}
                manifest['screenshots'].append(entry)
                if properties['alpha_channel'] is not False:
                    raise RuntimeError('PNG含alpha通道，保留原生截图但尚未符合商店无透明通道要求；请先无损转为不带alpha的RGB PNG再上传。')
                print(f'已保存 {path.name}：{properties["width"]} × {properties["height"]}', flush=True)
        manifest['status'] = 'captured' if len(manifest['screenshots']) == manifest['requested_count'] else 'partial'
        manifest['app_store_spec_validation'] = 'native PNG dimensions and alpha checked; App Review acceptance not asserted'
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
