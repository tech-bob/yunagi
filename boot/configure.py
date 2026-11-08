#!/usr/bin/env python3
"""Install Ion on an existing Limine system, preserving its boot entries."""
from pathlib import Path
import os
import re
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
CONFIGS = (
    'boot/EFI/arch-limine/limine.conf', 'boot/EFI/BOOT/limine.conf',
    'efi/EFI/arch-limine/limine.conf', 'efi/EFI/BOOT/limine.conf',
    'boot/limine/limine.conf', 'boot/limine.conf',
)


def backup_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == content:
        return
    backup = path.with_name(path.name + '.yunagi-backup')
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    path.write_text(content)


def style_config(original, header):
    # Replace only the global options we own. Leave custom options and entries.
    keys = {line.split(':', 1)[0].strip().lower() for line in header.splitlines()
            if ':' in line and not line.lstrip().startswith('#')}
    # A previous custom font must not refer to an absent bitmap font.
    keys.update(('term_font', 'term_font_size'))
    comments = {line for line in header.splitlines() if line.startswith('#')}
    lines = [line for line in original.splitlines()
             if line not in comments
             and not (':' in line and line.split(':', 1)[0].strip().lower() in keys)]
    body = '\n'.join(lines)
    blocks = re.split(r'(?m)(?=^/)', body)
    for i, block in enumerate(blocks):
        if not re.search(r'(?im)^\s*protocol:\s*linux\s*$', block):
            continue
        # Keep recovery entries verbose and retain their original kernel arguments.
        if 'fallback' in block.splitlines()[0].lower():
            continue
        blocks[i] = re.sub(
            r'(?im)^(\s*(?:kernel_)?cmdline:)([^\n]*)',
            lambda m: m[1] + m[2].rstrip() + ''.join(
                ' ' + arg for arg in ('quiet', 'splash') if arg not in m[2].split()),
            block,
        )
    return header.rstrip() + '\n\n' + ''.join(blocks).strip('\n') + '\n'


def configure(root):
    config = next((root / name for name in CONFIGS if (root / name).is_file()), None)
    if config is None:
        print('Ion: no Limine config found; boot configuration left as-is.')
        return False
    # boot(): is the filesystem containing limine.conf, including on systems
    # where /boot is a plain directory rather than its own mounted filesystem.
    mount = config.parent
    while mount != root and not mount.is_mount():
        mount = mount.parent
    image = config.parent / 'yunagi-ion.png'
    wallpaper = 'boot():/' + image.relative_to(mount).as_posix()
    header = (HERE / 'ion/limine.conf').read_text().replace('@WALLPAPER@', wallpaper)
    original = config.read_text()
    shutil.copyfile(HERE / 'ion/limine.png', image)
    backup_write(config, style_config(original, header))
    theme = root / 'usr/share/plymouth/themes/yunagi-ion'
    theme.mkdir(parents=True, exist_ok=True)
    for source in (HERE / 'ion/plymouth').iterdir():
        if source.suffix in ('.png', '.script', '.plymouth'):
            shutil.copyfile(source, theme / source.name)
    backup_write(root / 'etc/mkinitcpio.conf.d/yunagi-plymouth.conf',
                 (HERE / 'plymouth.conf').read_text())
    print(f'Ion: styled {config}; original kept as {config.name}.yunagi-backup')
    return True


if __name__ == '__main__':
    if configure(Path('/')):
        subprocess.run(['plymouth-set-default-theme', 'yunagi-ion'], check=True)
        # The ISO installer builds the initramfs once, at the end
        if not os.environ.get('YUNAGI_DEFER_INITRAMFS'):
            subprocess.run(['mkinitcpio', '-P'], check=True)
