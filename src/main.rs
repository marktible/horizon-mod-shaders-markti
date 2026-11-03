//! Development validator using the actual Horizon loader, including the shadow pipeline.
use horizon_shaders::{
    GameInputs, GbuffersInputs, Macros, Pack, Properties, dimension_folder, load_post,
};
use std::{path::Path, process::ExitCode};

fn reads(program: &horizon_shaders::PostProgram, sampler: &str) -> bool {
    program
        .program
        .as_ref()
        .is_some_and(|p| p.interface.samplers.iter().any(|s| s.name == sampler))
}

fn check(path: &Path) -> Result<(), String> {
    if horizon_shader_api::package::is_pack(path) {
        let pack = horizon_shader_api::Pack::read(path)?;
        let report = horizon_shader_api::check(&pack).map_err(|problems| {
            problems
                .iter()
                .map(|p| format!("{p:?}"))
                .collect::<Vec<_>>()
                .join("\n")
        })?;
        for required in [
            horizon_shader_api::StageKind::Sky,
            horizon_shader_api::StageKind::Material,
            horizon_shader_api::StageKind::Post,
        ] {
            if !report.stages.iter().any(|s| s.kind == required) {
                return Err(format!("Missing native {required:?} stage"));
            }
        }
        let material = report
            .stages
            .iter()
            .find(|s| s.kind == horizon_shader_api::StageKind::Material)
            .unwrap();
        for resource in [
            "block_light_colors",
            "shadow_map",
            "shadow_map_translucent",
            "shadow_color",
            "opaque_depth",
            "opaque_color",
        ] {
            if !material.reads(resource) {
                return Err(format!("Native Markti material is missing {resource}"));
            }
        }
        if report.manifest.lights.is_empty() || report.shadow.is_none() {
            return Err("Native Markti needs its colored light table and shadow settings".into());
        }
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let entry: horizon_mods::index::registry::Entry = toml::from_str(
            &std::fs::read_to_string(
                root.join("registry")
                    .join(format!("{}.toml", pack.manifest.id)),
            )
            .map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        horizon_mods::index::registry::page(
            &entry,
            &std::fs::read_to_string(root.join("horizon-registry.toml"))
                .map_err(|e| e.to_string())?,
        )?;
        if path.is_file() {
            let asset = path
                .file_name()
                .unwrap()
                .to_str()
                .ok_or("Non-UTF8 artifact name")?;
            let tag = format!("v{}", pack.manifest.version);
            let release = horizon_mods::index::registry::Release {
                tag: &tag,
                published: "2026-11-03",
                notes: "Local registry validation only",
                asset,
                game: "26.3",
                signature: None,
            };
            horizon_mods::index::registry::release_version(&entry, &release, path)?;
        }
        println!(
            "{}: native {} {}: {} stages, shader API {}, color grid and shadow/refraction resources validated",
            path.display(),
            pack.manifest.id,
            pack.manifest.version,
            report.stages.len(),
            pack.manifest.api
        );
        return Ok(());
    }
    let pack = Pack::open(path).map_err(|e| e.to_string())?;
    let settings = pack.read_text("lib/settings.glsl").unwrap_or_default();
    let dimension_effects = pack.read_text("lib/dimension.glsl").is_some();
    let shadow_history = pack.read_text("lib/shadow_history.glsl").is_some()
        && !settings
            .lines()
            .any(|l| l.starts_with("#define SHADOW_TEMPORAL 0"));
    let celestial = pack.read_text("gbuffers_skytextured.fsh").is_some();
    let surface_reflections = settings
        .lines()
        .any(|l| l == "#define SURFACE_REFLECTIONS 1 // [0 1]");
    let macros = Macros::standard();
    let properties = Properties::parse(
        &pack.read_text("shaders.properties").unwrap_or_default(),
        &macros,
    );
    if !properties.notes.is_empty() {
        return Err(format!("Invalid properties: {:?}", properties.notes));
    }
    let custom = horizon_shaders::Custom::parse(&properties);
    if !custom.notes.is_empty() {
        return Err(format!("Invalid custom uniforms: {:?}", custom.notes));
    }
    let terrain = GbuffersInputs {
        declarations: "layout(location=0) in vec3 test_position;".into(),
        body: "hz_Vertex=vec4(test_position,1.0); hz_Color=vec4(1.0); hz_Normal=vec3(0,1,0); hz_MultiTexCoord0=vec4(0.0); hz_MultiTexCoord1=vec4(240,240,0,1);".into(),
        attributes: vec![("mc_Entity".into(), "vec4(0.0)".into())],
        ..Default::default()
    };
    let inputs = GameInputs {
        terrain: Some(terrain.clone()),
        sky: Some(terrain.clone()),
        celestial: Some(terrain.clone()),
        entities: Some(terrain.clone()),
        clouds: Some(terrain.clone()),
        weather: Some(terrain.clone()),
        hand: Some(terrain),
        ..Default::default()
    };
    for dimension in [0, -1, 1] {
        let folder = dimension_folder(&pack, dimension);
        let result = load_post(&pack, &folder, &properties, &macros, &inputs);
        for note in result.notes.iter().chain(&result.config.notes) {
            eprintln!("{note}");
        }
        if !result.notes.is_empty() || !result.config.notes.is_empty() {
            return Err(format!(
                "{}: dimension {dimension} has loader diagnostics",
                path.display()
            ));
        }
        if result.programs.is_empty() {
            return Err(format!("dimension {dimension}: no post-processing loaded"));
        }
        if dimension == 0
            && (!result.shadow_pass
                || result.shadow.is_none()
                || result.terrain.is_none()
                || result.water.is_none())
        {
            return Err("Overworld requires a working shadow, terrain, and water program".into());
        }
        if dimension == 0 || dimension_effects {
            if result.terrain.is_none() || result.water.is_none() || result.entities.is_none() {
                return Err(format!(
                    "Dimension {dimension} needs terrain, translucent terrain and entity shaders"
                ));
            }
            if dimension != 0 && (result.shadow_pass || result.sky_textured.is_some()) {
                return Err(
                    "Nether/End must not inherit Overworld sun/moon or directional shadow maps"
                        .into(),
                );
            }
            if dimension != 0
                && result.programs.iter().any(|p| {
                    // Final targets the window; its default buffer list is not an MRT write.
                    (p.group != horizon_shaders::Group::Final && p.buffers.contains(&4))
                        || reads(p, "colortex4")
                })
            {
                return Err("Nether/End must compile out Overworld shadow history".into());
            }
            if celestial && dimension == 0 {
                let bodies = result
                    .sky_textured
                    .as_ref()
                    .ok_or("Sun/moon program did not load")?;
                let deferred = result
                    .programs
                    .iter()
                    .find(|p| p.name == "deferred")
                    .ok_or("Missing deferred")?;
                if !bodies.buffers.contains(&0)
                    || !bodies.buffers.contains(&6)
                    || !result.config.buffers[6].clear
                    || !reads(bodies, "texture")
                    || !reads(deferred, "colortex6")
                {
                    return Err("Sun/moon requires its native atlas and cleared horizon-preservation buffer".into());
                }
            }
            for required in ["deferred", "composite", "final"] {
                if !result.programs.iter().any(|p| p.name == required) {
                    return Err(format!(
                        "Missing {required}: HDR / reflection chain is incomplete"
                    ));
                }
            }
            let water = result.water.as_ref().expect("checked water program");
            for required in ["colortex1", "depthtex1"] {
                if !reads(water, required) {
                    return Err(format!(
                        "Water is missing {required}; the opaque SSR snapshot is unavailable"
                    ));
                }
            }
            if dimension == 0 && !reads(water, "shadowtex0") {
                return Err("Overworld water requires shadow-map visibility".into());
            }
            if dimension != 0 && reads(water, "shadowtex0") {
                return Err(
                    "Nether/End water must compile out sunlight and its shadow sampler".into(),
                );
            }
            let terrain = result.terrain.as_ref().expect("checked terrain");
            if ["radianceVoxelLight", "radianceRayScene", "radianceBlockIds"]
                .iter()
                .any(|name| reads(terrain, name))
            {
                return Err("Markti must use standard Horizon shader resources".into());
            }
            let hdr = horizon_shaders::Format::parse("RGBA16F").expect("HDR format");
            let packed_hdr = horizon_shaders::Format::parse("R11F_G11F_B10F").expect("packed HDR");
            let snapshot = result.config.buffers[1].format;
            let compact_setting = settings.lines().find_map(|line| {
                line.strip_prefix("#define COMPACT_WATER_BUFFER ")
                    .map(|value| value.starts_with('1'))
            });
            if let Some(compact) = compact_setting {
                let expected = if compact { packed_hdr } else { hdr };
                if result.config.buffers[1].format != expected {
                    return Err("Water snapshot format does not match COMPACT_WATER_BUFFER".into());
                }
            }
            if result.config.buffers[0].format != hdr || (snapshot != hdr && snapshot != packed_hdr)
            {
                return Err("World must retain RGBA16F and the water snapshot must retain floating-point HDR".into());
            }
            if shadow_history && dimension == 0 {
                let terrain = result.terrain.as_ref().expect("checked terrain");
                let deferred = result
                    .programs
                    .iter()
                    .find(|p| p.name == "deferred")
                    .expect("checked deferred");
                if !terrain.buffers.contains(&3)
                    || !deferred.buffers.contains(&4)
                    || result.config.buffers[4].clear
                    || result.config.buffers[4].format != hdr
                {
                    return Err("Shadow history requires direct-light output and a persistent HDR history buffer".into());
                }
            }
            if surface_reflections {
                let terrain = result.terrain.as_ref().expect("checked terrain");
                let composite = result
                    .programs
                    .iter()
                    .find(|p| p.name == "composite")
                    .expect("checked composite");
                if !terrain.buffers.contains(&5)
                    || !water.buffers.contains(&5)
                    || !result.config.buffers[5].clear
                {
                    return Err("Surface reflections require cleared material metadata from opaque/translucent terrain".into());
                }
                for required in ["colortex0", "depthtex0", "colortex5"] {
                    if !reads(composite, required) {
                        return Err(format!("Surface reflections are missing {required}"));
                    }
                }
            }
        }
        println!(
            "{}: dimension {dimension}: {} post pass(es), shadow={} at {} px / {} blocks, terrain={}, water={}",
            path.display(),
            result.programs.len(),
            result.shadow_pass,
            result.config.shadow.resolution,
            result.config.shadow.distance,
            result.terrain.is_some(),
            result.water.is_some()
        );
    }
    Ok(())
}

fn main() -> ExitCode {
    let paths: Vec<_> = std::env::args_os().skip(1).collect();
    if paths.is_empty() {
        eprintln!("Usage: horizon-pack-check PACK_FOLDER_OR_ZIP [...]");
        return ExitCode::FAILURE;
    }
    for path in paths {
        if let Err(e) = check(Path::new(&path)) {
            eprintln!("FAILED: {e}");
            return ExitCode::FAILURE;
        }
    }
    ExitCode::SUCCESS
}

#[cfg(test)]
mod tests {
    use super::*;
    use horizon_shaders::{Custom, Val};

    #[test]
    fn shadow_light_ignores_yaw_pitch_and_view_roll() {
        let pack = Pack::open(&Path::new(env!("CARGO_MANIFEST_DIR")).join("packs/markti"))
            .expect("source pack");
        let properties = Properties::parse(
            &pack.read_text("shaders.properties").expect("properties"),
            &Macros::standard(),
        );
        let multiply = |a: [[f64; 3]; 3], b: [[f64; 3]; 3]| {
            std::array::from_fn(|r| {
                std::array::from_fn(|c| (0..3).map(|k| a[r][k] * b[k][c]).sum())
            })
        };
        // Both hemispheres and grazing light; real builtin matrices/vectors are f32.
        for world in [
            [50.0_f64, 80.0, -40.0],
            [-50.0, 80.0, 40.0],
            [70.0, 0.05, -35.0],
        ] {
            let mut custom = Custom::parse(&properties);
            let length = world.iter().map(|v| v * v).sum::<f64>().sqrt();
            for yaw in [-180.0_f64, -95.0, -45.0, 0.0, 37.0, 90.0, 179.0] {
                for pitch in [-85.0_f64, -25.0, 0.0, 40.0, 85.0] {
                    for roll in [-2.0_f64, 0.0, 2.0] {
                        let (sy, cy) = yaw.to_radians().sin_cos();
                        let (sp, cp) = pitch.to_radians().sin_cos();
                        let (sr, cr) = roll.to_radians().sin_cos();
                        let rotation = multiply(
                            multiply(
                                [[cy, 0.0, sy], [0.0, 1.0, 0.0], [-sy, 0.0, cy]],
                                [[1.0, 0.0, 0.0], [0.0, cp, -sp], [0.0, sp, cp]],
                            ),
                            [[cr, -sr, 0.0], [sr, cr, 0.0], [0.0, 0.0, 1.0]],
                        );
                        let mut matrix = [0.0; 16];
                        for c in 0..3 {
                            for r in 0..3 {
                                matrix[c * 4 + r] = f64::from(rotation[r][c] as f32);
                            }
                        }
                        matrix[15] = 1.0;
                        let view: [f64; 3] = std::array::from_fn(|c| {
                            f64::from((0..3).map(|r| rotation[r][c] * world[r]).sum::<f64>() as f32)
                        });
                        let index = custom
                            .uniforms()
                            .position(|(name, _)| name == "radianceShadowLight")
                            .unwrap();
                        let light = custom.eval(1.0 / 60.0, &|name| match name {
                            "gbufferModelViewInverse" => Some(Val::vector(&matrix)),
                            "shadowLightPosition" => Some(Val::vector(&view)),
                            _ => None,
                        })[index];
                        for (axis, expected) in world.iter().enumerate() {
                            assert!(
                                (light.v[axis] - expected / length).abs() < 2e-7,
                                "camera moved light at yaw={yaw}, pitch={pitch}, roll={roll}"
                            );
                        }
                    }
                }
            }
            assert!(custom.notes.is_empty(), "{:?}", custom.notes);
        }
    }

    #[test]
    fn shadow_light_stays_in_world_space_and_moves_between_ticks() {
        let pack = Pack::open(&Path::new(env!("CARGO_MANIFEST_DIR")).join("packs/markti"))
            .expect("source pack");
        let properties = Properties::parse(
            &pack.read_text("shaders.properties").expect("properties"),
            &Macros::standard(),
        );
        let mut custom = Custom::parse(&properties);
        assert!(custom.notes.is_empty(), "{:?}", custom.notes);
        let frame = |custom: &mut Custom, turned: bool, moved: bool| {
            let matrix = if turned {
                [
                    0., 0., -1., 0., 0., 1., 0., 0., 1., 0., 0., 0., 0., 0., 0., 1.,
                ]
            } else {
                [
                    1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.,
                ]
            };
            let world = if moved {
                [50.1, 80., -39.9]
            } else {
                [50., 80., -40.]
            };
            let view = if turned {
                [-world[2], world[1], world[0]]
            } else {
                world
            };
            let values = custom.eval(1.0 / 60.0, &|name| match name {
                "gbufferModelViewInverse" => Some(Val::vector(&matrix)),
                "shadowLightPosition" => Some(Val::vector(&view)),
                _ => None,
            });
            let index = custom
                .uniforms()
                .position(|(name, _)| name == "radianceShadowLight")
                .expect("continuous shadow light");
            let right = values[custom
                .uniforms()
                .position(|(name, _)| name == "radianceShadowRight")
                .expect("shadow right")];
            let up = values[custom
                .uniforms()
                .position(|(name, _)| name == "radianceShadowUp")
                .expect("shadow up")];
            let dot = |a: Val, b: Val| (0..3).map(|i| a.v[i] * b.v[i]).sum::<f64>();
            for axis in [values[index], right, up] {
                assert!(
                    (dot(axis, axis) - 1.0).abs() < 1e-8,
                    "shadow basis must be unit length"
                );
            }
            assert!(dot(values[index], right).abs() < 1e-8);
            assert!(dot(values[index], up).abs() < 1e-8);
            assert!(dot(right, up).abs() < 1e-8);
            values[index]
        };
        let initial = frame(&mut custom, false, false);
        let turned = frame(&mut custom, true, false);
        for i in 0..3 {
            assert!(
                (initial.v[i] - turned.v[i]).abs() < 1e-8,
                "camera turn moved the light"
            );
        }
        let next = frame(&mut custom, true, true);
        let length = (50.1_f64.powi(2) + 80.0_f64.powi(2) + 39.9_f64.powi(2)).sqrt();
        assert!(next.v[0] > initial.v[0] && next.v[0] < 50.1 / length);
        assert!(next.v[2] > initial.v[2] && next.v[2] < -39.9 / length);
        assert!(custom.notes.is_empty(), "{:?}", custom.notes);
    }
}
