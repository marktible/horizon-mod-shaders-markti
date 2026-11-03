//! Shared source for the two generated native mod installers. No game dependency.
use std::{fs, io, path::Path};

/// Update only this mod's pack files. Selection, sidecars and other packs stay owned
/// by Horizon/the player. The manifest is published last after the shader files.
pub fn install_files(instance: &Path, folder: &str, files: &[(&str, &[u8])]) -> io::Result<()> {
    let target = instance.join("shaderpacks").join(folder);
    fs::create_dir_all(&target)?;
    for (name, data) in files
        .iter()
        .filter(|(name, _)| *name != "horizon-shaders.toml")
        .chain(
            files
                .iter()
                .filter(|(name, _)| *name == "horizon-shaders.toml"),
        )
    {
        let path = target.join(name);
        if fs::read(&path).is_ok_and(|current| current == *data) {
            continue;
        }
        let temporary = target.join(format!(".{name}.markti-incoming"));
        fs::write(&temporary, data)?;
        fs::rename(&temporary, &path)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct Fixture(std::path::PathBuf);

    impl Fixture {
        fn new() -> Self {
            static NEXT: AtomicUsize = AtomicUsize::new(0);
            let root = std::env::temp_dir().join(format!(
                "markti-installer-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir_all(&root).unwrap();
            Self(root)
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn installs_repairs_and_preserves_player_files() {
        let home = Fixture::new();
        let shaders = home.0.join("shaderpacks");
        fs::create_dir_all(&shaders).unwrap();
        let options = home.0.join("horizon-graphics.txt");
        let sidecar = shaders.join("native-markti_shaders_mod.txt");
        let other = shaders.join("other.hshader");
        fs::write(
            &options,
            b"pickedShaderPack:other.hshader\nresolutionScale:100\n",
        )
        .unwrap();
        fs::write(&sidecar, b"saturation=1.1\n").unwrap();
        fs::write(&other, b"other pack").unwrap();
        let before = [options, sidecar, other].map(|p| {
            let bytes = fs::read(&p).unwrap();
            (p, bytes)
        });
        let files: &[(&str, &[u8])] = &[
            ("horizon-shaders.toml", b"manifest"),
            ("water.wgsl", b"water"),
        ];
        let folder = "native-markti_shaders_mod";
        install_files(&home.0, folder, files).unwrap();
        let water = shaders.join(folder).join("water.wgsl");
        let original_time = fs::metadata(&water).unwrap().modified().unwrap();
        install_files(&home.0, folder, files).unwrap();
        assert_eq!(
            fs::metadata(&water).unwrap().modified().unwrap(),
            original_time
        );
        fs::write(&water, b"old shader").unwrap();
        install_files(&home.0, folder, files).unwrap();
        assert_eq!(fs::read(&water).unwrap(), b"water");
        for (path, bytes) in before {
            assert_eq!(fs::read(path).unwrap(), bytes);
        }
    }

    #[test]
    fn failed_shader_write_does_not_publish_new_manifest() {
        let home = Fixture::new();
        let folder = "native-markti_shaders_mod";
        let target = home.0.join("shaderpacks").join(folder);
        fs::create_dir_all(target.join("water.wgsl")).unwrap();
        fs::write(target.join("horizon-shaders.toml"), b"old manifest").unwrap();
        assert!(
            install_files(
                &home.0,
                folder,
                &[
                    ("horizon-shaders.toml", b"new manifest"),
                    ("water.wgsl", b"new water")
                ],
            )
            .is_err()
        );
        assert_eq!(
            fs::read(target.join("horizon-shaders.toml")).unwrap(),
            b"old manifest"
        );
    }
}
