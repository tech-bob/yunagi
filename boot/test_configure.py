"""Boot config regression checks; all writes go to temporary fixtures."""
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from configure import HERE, configure, style_config

ORIGINAL = '''timeout: 3
term_font: boot():/missing-font.bin
serial: yes

/Arch Linux (linux)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: root=UUID=keep-me rw rootflags=subvol=@
    module_path: boot():/initramfs-linux.img

/Arch Linux (fallback)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: root=UUID=keep-me rw
    module_path: boot():/initramfs-linux-fallback.img

/Windows
    protocol: efi
    path: boot(2):/EFI/Microsoft/Boot/bootmgfw.efi
'''


class BootTests(unittest.TestCase):
    def test_entries_and_recovery_survive(self):
        header = (HERE / 'ion/limine.conf').read_text()
        result = style_config(ORIGINAL, header)
        self.assertIn('root=UUID=keep-me rw rootflags=subvol=@ quiet splash', result)
        self.assertIn(ORIGINAL[ORIGINAL.index('/Arch Linux (fallback)'):].rstrip(), result)
        self.assertIn('serial: yes', result)
        self.assertNotIn('missing-font.bin', result)
        self.assertEqual(result, style_config(result, header))

    def test_kernel_cmdline_alias(self):
        header = (HERE / 'ion/limine.conf').read_text()
        result = style_config(ORIGINAL.replace('cmdline:', 'kernel_cmdline:'), header)
        self.assertIn('kernel_cmdline: root=UUID=keep-me rw rootflags=subvol=@ quiet splash', result)

    def test_uefi_and_bios_install_and_backup(self):
        for relative in ('boot/EFI/arch-limine/limine.conf', 'boot/limine/limine.conf'):
            with self.subTest(config=relative), tempfile.TemporaryDirectory(dir=Path.home() / '.cache') as tmp:
                root = Path(tmp)
                config = root / relative
                config.parent.mkdir(parents=True)
                config.write_text(ORIGINAL)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertTrue(configure(root))
                    first = config.read_bytes()
                    self.assertTrue(configure(root))
                self.assertEqual(first, config.read_bytes())
                self.assertEqual(ORIGINAL, config.with_name('limine.conf.yunagi-backup').read_text())
                self.assertIn('boot():/' + str(config.parent.relative_to(root)) + '/yunagi-ion.png', config.read_text())
                self.assertTrue((root / 'usr/share/plymouth/themes/yunagi-ion/yunagi-ion.script').exists())
                self.assertTrue((config.parent / 'yunagi-ion.png').exists())

    def test_other_bootloaders_unchanged(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / '.cache') as tmp:
            root = Path(tmp)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(configure(root))
            self.assertEqual([], list(root.iterdir()))

    def test_separate_boot_partition_uses_partition_relative_path(self):
        with tempfile.TemporaryDirectory(dir=Path.home() / '.cache') as tmp:
            root = Path(tmp)
            config = root / 'boot/EFI/arch-limine/limine.conf'
            config.parent.mkdir(parents=True)
            config.write_text(ORIGINAL)
            with patch.object(Path, 'is_mount', lambda path: path == root / 'boot'):
                with contextlib.redirect_stdout(io.StringIO()):
                    configure(root)
            self.assertIn('wallpaper: boot():/EFI/arch-limine/yunagi-ion.png', config.read_text())

    def test_hooks_keep_encryption_and_keyboard_order(self):
        for hooks, unlock in [
            ('base udev autodetect kms keyboard keymap block encrypt filesystems fsck', 'encrypt'),
            ('base systemd autodetect kms keyboard sd-vconsole block sd-encrypt filesystems fsck', 'sd-encrypt'),
            ('base udev plymouth kms keyboard block filesystems fsck', 'filesystems'),
        ]:
            with self.subTest(hooks=hooks):
                result = subprocess.check_output([
                    'bash', '-c',
                    'HOOKS=($1); source "$2"; source "$2"; printf "%s\\n" "${HOOKS[@]}"',
                    'test', hooks, str(HERE / 'plymouth.conf'),
                ], text=True).splitlines()
                self.assertEqual(1, result.count('plymouth'))
                self.assertLess(result.index('keyboard'), result.index('plymouth'))
                self.assertLess(result.index('plymouth'), result.index(unlock))
                self.assertEqual(hooks.split().count('sd-encrypt'), result.count('sd-encrypt'))


if __name__ == '__main__':
    unittest.main()
