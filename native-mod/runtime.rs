//! Supported trait hooks. Settings/pack selection are refreshed around menus;
//! steady flight performs no file reads, texture creation or bind-group creation.
use horizon_client::mod_api::{
    FrameEvent, Hooks, Host, ModsEvent, NativeMod, RenderHooks, ScreenRenderPostEvent,
    SettingsClickEvent, SettingsEvent, ShaderParamsEvent, WorldDrawnEvent,
};
use std::{
    fs,
    sync::{
        Mutex, Once,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
};

pub struct Runtime {
    id: &'static str,
    folder: &'static str,
    title: &'static str,
    installed: Once,
    enabled: AtomicBool,
    on: AtomicBool,
    active: AtomicBool,
    sharpness: AtomicU32,
    menu_seen: AtomicBool,
    was_menu: AtomicBool,
    gpu: Mutex<Option<crate::fsr::Gpu>>,
}

impl Runtime {
    pub fn new(id: &'static str, folder: &'static str, title: &'static str) -> Self {
        Self {
            id,
            folder,
            title,
            installed: Once::new(),
            enabled: AtomicBool::new(false),
            on: AtomicBool::new(true),
            active: AtomicBool::new(false),
            sharpness: AtomicU32::new(0.2f32.to_bits()),
            menu_seen: AtomicBool::new(false),
            was_menu: AtomicBool::new(false),
            gpu: Mutex::new(None),
        }
    }

    fn refresh(&self, host: &dyn Host) {
        let text = fs::read_to_string(host.instance_dir().join("horizon-graphics.txt"))
            .unwrap_or_default();
        let file = self.id.strip_suffix("_mod").unwrap_or(self.id).to_owned() + ".hshader";
        let active = text.lines().any(|line| {
            line.strip_prefix("pickedShaderPack:")
                .is_some_and(|value| value.trim() == self.folder || value.trim() == file)
        });
        self.active.store(active, Ordering::Relaxed);
    }

    fn runs(&self) -> bool {
        self.on.load(Ordering::Relaxed)
            && self.active.load(Ordering::Relaxed)
            && self.enabled.load(Ordering::Relaxed)
    }
}

impl Hooks for Runtime {
    fn mods(&self, _host: &mut dyn Host, event: &mut ModsEvent<'_>) {
        event.mods.push(NativeMod {
            id: self.id.to_owned(),
            title: self.title.to_owned(),
            description: "Markti shaders with optional FSR 1 EASU upscaling and RCAS sharpening."
                .to_owned(),
            keys: Vec::new(),
        });
    }
    fn render(&self) -> Option<&dyn RenderHooks> {
        Some(self)
    }

    fn frame(&self, host: &mut dyn Host, _event: &mut FrameEvent) {
        self.on.store(host.on(self.id), Ordering::Relaxed);
        self.installed.call_once(|| {
            if let Err(error) = crate::payload::install(&host.instance_dir()) {
                eprintln!("{}: could not install shader pack: {error}", self.id);
            }
            self.enabled.store(
                host.setting(self.id, "fsr1").as_deref() == Some("1"),
                Ordering::Relaxed,
            );
            if let Some(value) = host
                .setting(self.id, "fsr1_sharpness")
                .and_then(|v| v.parse::<f32>().ok())
                .filter(|v| v.is_finite())
            {
                self.sharpness
                    .store(value.clamp(0.0, 1.0).to_bits(), Ordering::Relaxed);
            }
            self.refresh(host);
        });
        let menu = self.menu_seen.swap(false, Ordering::Relaxed);
        if self.was_menu.swap(menu, Ordering::Relaxed) && !menu {
            self.refresh(host);
        }
    }

    fn screen_render_post(&self, _host: &dyn Host, _event: &mut ScreenRenderPostEvent<'_>) {
        self.menu_seen.store(true, Ordering::Relaxed);
    }

    fn shader_params(&self, _host: &dyn Host, event: &mut ShaderParamsEvent<'_>) {
        // Only one of the two presets owns the selected file. Inactive mods
        // leave the slot alone, so installing both cannot double-sharpen.
        if self.active.load(Ordering::Relaxed) {
            event.params[7] = [
                f32::from(self.enabled.load(Ordering::Relaxed) && self.on.load(Ordering::Relaxed)),
                0.0,
                0.0,
                0.0,
            ];
        }
    }

    fn settings(&self, _host: &mut dyn Host, event: &mut SettingsEvent<'_>) {
        if event.mod_id != self.id {
            return;
        }
        event.buttons.push(format!(
            "FSR 1 (EASU + RCAS): {}",
            if self.enabled.load(Ordering::Relaxed) {
                "ON"
            } else {
                "OFF"
            }
        ));
        event.buttons.push(format!(
            "FSR 1 sharpness: {:.1}",
            f32::from_bits(self.sharpness.load(Ordering::Relaxed))
        ));
    }

    fn settings_click(&self, host: &mut dyn Host, event: &mut SettingsClickEvent<'_>) {
        if event.mod_id != self.id {
            return;
        }
        match event.button {
            0 => {
                let enabled = !self.enabled.load(Ordering::Relaxed);
                self.enabled.store(enabled, Ordering::Relaxed);
                host.set_setting(self.id, "fsr1", if enabled { "1" } else { "0" });
            }
            1 => {
                let current = f32::from_bits(self.sharpness.load(Ordering::Relaxed));
                let next = (((current * 10.0).round() as u32 + 2) % 12) as f32 / 10.0;
                self.sharpness.store(next.to_bits(), Ordering::Relaxed);
                host.set_setting(self.id, "fsr1_sharpness", &next.to_string());
            }
            _ => {}
        }
    }
}

impl RenderHooks for Runtime {
    fn world_drawn(&self, event: &mut WorldDrawnEvent<'_, '_>) {
        if !self.runs() {
            return;
        }
        let Ok(mut cached) = self.gpu.lock() else {
            return;
        };
        if cached.as_ref().is_none_or(|gpu| !gpu.matches(event.world)) {
            *cached = Some(crate::fsr::Gpu::new(event.world));
        }
        cached.as_mut().unwrap().draw(
            event.world,
            f32::from_bits(self.sharpness.load(Ordering::Relaxed)),
        );
    }
}
