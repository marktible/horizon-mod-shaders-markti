# Install through Add from GitHub

In Horizon's launcher, open **Mods → Add from GitHub** and paste:

`https://github.com/marktible/horizon-mod-shaders-markti`

1. Choose `markti_shaders_mod` for **Markti Shader**, or
   `markti_shaders_ultra_mod` for **Markti Shaders Ultra Performance**. You can install both.
2. Review Horizon's native-code notice and the source, then install.
3. Use **Build & Play**. The first native build compiles official Horizon with
   the enabled bundles; later unchanged launches reuse it.
4. At the title screen, open **Options → Horizon Settings → Shader Packs** and
   select the installed preset. The folders are `native-markti_shaders_mod` and
   `native-markti_shaders_ultra_mod`. Open **Shader Options** to customize it.

Each mod installs its pack on the first frame, before entering a world. It keeps
your previous shader selection and saved options. Only one shader pack runs at
a time. Turning the matching mod off pauses its `native-<mod-id>` pack without
erasing the selection; unrelated shader packs are unaffected.

The message **“holds no native mod”** at `b136d1b` was accurate for that old commit:
it contained shader packages only. Retry the repository URL or use its
`/tree/main` URL to resolve current source. These bundles are present from 1.1.1.
GitHub installation does not require a Horizon catalog listing.

For a direct installation with no native build, download either `.hshader` from
the [README](../README.md), copy it into `shaderpacks/`, and select it in the same
Shader Packs screen. It uses the same rendering code. The native mod route also adds FSR 1 through official render hooks.

## FSR 1 (version 1.2.0)

Update the mod source in the launcher and rebuild. Select the installed Markti
pack, then use **Options → Mods → its Settings → FSR 1 (EASU + RCAS): ON**.
In Horizon Graphics choose **67% render resolution** (approximately Quality) and
**Native** upscaling. Both EASU and RCAS run before the hand and HUD. Sharpness
defaults to 0.2; settings save per mod. FSR defaults off and preserves your render
resolution. See [all ratios and limitations](settings.md).

MCRS chooses the official base version. The tested November 4 commit is a baseline,
not a forced downgrade; supported newer hook APIs can be rebuilt by the launcher.
A standalone shader update cannot add Rust hooks to an already-built game.
