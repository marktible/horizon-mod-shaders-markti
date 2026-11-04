//! RCAS after the native pack's EASU presentation, before hand/HUD composition.
use horizon_client::mod_api::{WorldDrawn, wgpu};

pub struct Gpu {
    device: wgpu::Device,
    format: wgpu::TextureFormat,
    size: [u32; 2],
    pipeline: wgpu::RenderPipeline,
    source: wgpu::Texture,
    group: wgpu::BindGroup,
    settings: wgpu::Buffer,
    sharpness: f32,
}

impl Gpu {
    pub fn matches(&self, world: &WorldDrawn<'_>) -> bool {
        self.device == *world.device && self.format == world.color_format && self.size == world.size
    }

    pub fn new(world: &WorldDrawn<'_>) -> Self {
        let device = world.device;
        let source = device.create_texture(&wgpu::TextureDescriptor {
            label: Some("Markti FSR 1 EASU snapshot"),
            size: world.color.size(),
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: world.color.format(),
            usage: wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING,
            view_formats: &[world.color_format],
        });
        let view = source.create_view(&wgpu::TextureViewDescriptor {
            format: Some(world.color_format),
            ..Default::default()
        });
        let settings = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Markti FSR 1 RCAS settings"),
            size: 16,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Markti FSR 1 RCAS layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: false },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(16),
                    },
                    count: None,
                },
            ],
        });
        let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Markti FSR 1 RCAS group"),
            layout: &layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: settings.as_entire_binding(),
                },
            ],
        });
        let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Markti FSR 1 RCAS"),
            source: wgpu::ShaderSource::Wgsl(include_str!("../data/fsr1_rcas.wgsl").into()),
        });
        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Markti FSR 1 RCAS pipeline layout"),
            bind_group_layouts: &[Some(&layout)],
            immediate_size: 0,
        });
        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Markti FSR 1 RCAS"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &module,
                entry_point: Some("vertex"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &module,
                entry_point: Some("fragment"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState {
                    format: world.color_format,
                    blend: None,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: Default::default(),
            depth_stencil: None,
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        Self {
            device: device.clone(),
            format: world.color_format,
            size: world.size,
            pipeline,
            source,
            group,
            settings,
            sharpness: -1.0,
        }
    }

    pub fn draw(&mut self, world: &mut WorldDrawn<'_>, sharpness: f32) {
        if self.sharpness != sharpness {
            // AMD sharpness is measured in stops: 0 is strongest, 2 is mild.
            let value = 2.0f32.powf(-2.0 * (1.0 - sharpness.clamp(0.0, 1.0)));
            let mut bytes = [0u8; 16];
            bytes[..4].copy_from_slice(&value.to_le_bytes());
            world.queue.write_buffer(&self.settings, 0, &bytes);
            self.sharpness = sharpness;
        }
        world.encoder.copy_texture_to_texture(
            world.color.as_image_copy(),
            self.source.as_image_copy(),
            world.color.size(),
        );
        let mut pass = world
            .encoder
            .begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Markti FSR 1 RCAS"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: world.color_view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Load,
                        store: wgpu::StoreOp::Store,
                    },
                })],
                ..Default::default()
            });
        pass.set_pipeline(&self.pipeline);
        pass.set_bind_group(0, &self.group, &[]);
        pass.draw(0..3, 0..1);
    }
}
