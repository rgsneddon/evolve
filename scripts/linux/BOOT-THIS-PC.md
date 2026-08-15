# Boot Linux on this Windows PC, then call `grok` in the terminal

You already have **Ubuntu 26.04** at:

`C:\Users\rgsne\Downloads\ubuntu-26.04-desktop-amd64.iso`

This USB will be **wiped** when the ISO is written. Windows on the internal disk is not touched.

## 1. Plug the USB in (now)

1. Close anything using the stick.
2. Plug it into a USB port on this PC.
3. Tell Grok it is in. I will list disks and write the ISO only to the USB.
4. Do **not** reboot until the write finishes.

If the stick already has a working Ubuntu installer and you only want to boot it, skip the write and go to step 3.

## 2. After the write (I do this)

You will see a log line like `USB write complete`. Eject the stick in Windows, then leave it plugged in.

## 3. Boot the USB on this machine

1. Save work. Start → **Restart** (not Shut down).
2. As soon as the screen goes black, tap **F12** or **Esc** (Dell/HP often F12; some boards use F10 / F9).
3. In the boot menu pick the USB (UEFI). Examples: `UEFI: USB`, `SanDisk`, `Kingston`.
4. If the USB is missing:
   - Enter firmware setup (**F2** or **Del**).
   - **Boot → USB** enabled.
   - Try **Secure Boot = Disabled** if Ubuntu will not start.
   - Save and retry F12.
5. Ubuntu menu: **Try or Install Ubuntu** → **Try Ubuntu** first.  
   That is a live session. It does **not** erase Windows.

## 4. Call Grok on Ubuntu (and later Arch)

In the live (or installed) terminal:

```bash
# If you can see the Windows disk:
lsblk
sudo mkdir -p /mnt/windows
# pick the big NTFS partition from lsblk (not the USB)
sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/windows
bash /mnt/windows/Users/rgsne/Desktop/linux-usb-guide/install-grok-linux.sh
```

Or, with internet and no Windows mount:

```bash
curl -fsSL https://x.ai/cli/install.sh | bash
export PATH="$HOME/.grok/bin:$PATH"
grok --version
grok
```

Same script works on **Arch** (`pacman`) and **Ubuntu/Debian** (`apt`). After install:

```
grok          # TUI — sign in when the browser / device code appears
grok login    # if auth is needed again
```

## 5. Do Evolve Linux/Arch work (same **4.2.1** tag)

Full commands: [docs/HANDOVER_4.2.1_LINUX_ARCH.md](../../docs/HANDOVER_4.2.1_LINUX_ARCH.md).

```bash
git clone https://github.com/rgsneddon/evolve.git
cd evolve
# flutter build linux --release --build-name=4.2.1 --build-number=181
# package evolve-v4.2.1-linux-x64.tar.gz
# Arch: evolve-v4.2.1-archlinux-x86_64.pkg.tar.zst
# upload onto existing GitHub tag v4.2.1 only — never v4.2.1-linux
```

## 6. Leave Windows intact

- **Try Ubuntu** = temporary. Remove the USB, reboot, Windows is back.
- **Install Ubuntu** only if you want a permanent disk install. Choose **Install alongside Windows**. Do not pick “Erase disk” unless you mean to wipe this PC.

BitLocker: if Windows asks for a recovery key after firmware changes, use your Microsoft account key. Live USB “Try Ubuntu” usually does not trigger that.

## Arch later

This stick is Ubuntu. For Arch, write an official Arch ISO the same way (different file). Then run `install-grok-linux.sh` — it detects `arch` and uses `pacman`.
