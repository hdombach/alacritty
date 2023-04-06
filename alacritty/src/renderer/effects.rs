use crate::{renderer::shader::{ShaderError, ShaderProgram, ShaderVersion}, gl::{types::{GLuint, GLenum, GLint}, self}, display::SizeInfo};
use crate::renderer::{self, cstr};
use std::{mem, time::SystemTime};

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct Vertex {
    // Normalized screen coordinates.
    x: f32,
    y: f32,

    // Color.
    u: f32,
    v: f32,
}

#[derive(Debug)]
pub struct EffectRenderer {
    vao: GLuint,
    vbo: GLuint,
    framebuffer: GLuint,
    framebuffer_texture: GLuint,
    blur_texture: GLuint,
    blur_scale: i32,
    blur_framebuffer: GLuint,

    blur_pingpong_texture: [GLuint; 2],
    blur_pingpong_framebuffer: [GLuint; 2],

    program: EffectShaderProgram,
    blur_scale_program: BlurScaleEffectShaderProgram,
    blur_main_program: BlurMainEffectShaderProgram,

}

impl EffectRenderer {
    pub fn new(shader_version: ShaderVersion) -> Result<Self, renderer::Error> {
        let mut vao: GLuint = 0;
        let mut vbo: GLuint = 0;

        let mut framebuffer: GLuint = 0;
        let mut framebuffer_texture: GLuint = 0;
        let mut blur_texture: GLuint = 0;
        let mut blur_framebuffer: GLuint = 0;
        let mut blur_pingpong_texture: [GLuint; 2] = [0, 0];
        let mut blur_pingpong_framebuffer: [GLuint; 2] = [0, 0];

        let blur_scale: i32 = 32;

        let program = EffectShaderProgram::new(shader_version)?;
        let blur_scale_program = BlurScaleEffectShaderProgram::new(shader_version)?;
        let blur_main_program = BlurMainEffectShaderProgram::new(shader_version)?;

        let mut vertices: Vec<Vertex> = Vec::new();
        vertices.push(Vertex { x: -1.0, y: -1.0, u: 0.0, v: 0.0 });
        vertices.push(Vertex { x: 1.0, y: -1.0,  u: 1.0, v: 0.0 });
        vertices.push(Vertex { x: -1.0, y: 1.0,  u: 0.0, v: 1.0 });
        vertices.push(Vertex { x: 1.0, y: -1.0,  u: 1.0, v: 0.0 });
        vertices.push(Vertex { x: -1.0, y: 1.0,  u: 0.0, v: 1.0 });
        vertices.push(Vertex { x: 1.0, y: 1.0,  u: 1.0, v: 1.0 });


        unsafe {
            //Set up vertex stuff
            gl::GenVertexArrays(1, &mut vao);
            gl::GenBuffers(1, &mut vbo);
            gl::BindVertexArray(vao);
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo);
            gl::BufferData(
                gl::ARRAY_BUFFER,
                (vertices.len() * mem::size_of::<Vertex>()) as isize,
                vertices.as_ptr() as *const _,
                gl::STATIC_DRAW,
            );

            let mut attribute_offset = 0;
            // Position.
            gl::VertexAttribPointer(
                0,
                2,
                gl::FLOAT,
                gl::FALSE,
                mem::size_of::<Vertex>() as i32,
                attribute_offset as *const _,
            );
            gl::EnableVertexAttribArray(0);
            attribute_offset += mem::size_of::<f32>() * 2;

            // Color.
            gl::VertexAttribPointer(
                1,
                2,
                gl::FLOAT,
                gl::FALSE,
                mem::size_of::<Vertex>() as i32,
                attribute_offset as *const _,
            );
            gl::EnableVertexAttribArray(1);

            // Reset buffer bindings.
            gl::BindVertexArray(0);
            gl::BindBuffer(gl::ARRAY_BUFFER, 0);

            //set up framebuffer for main rending pass
            gl::GenFramebuffers(1, &mut framebuffer);
            gl::BindFramebuffer(gl::FRAMEBUFFER, framebuffer);

            //main texture
            gl::GenTextures(1, &mut framebuffer_texture);
            gl::BindTexture(gl::TEXTURE_2D, framebuffer_texture);
            gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, 1600, 1200, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MAG_FILTER, gl::NEAREST as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MIN_FILTER, gl::NEAREST as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_S, gl::CLAMP_TO_EDGE as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_T, gl::CLAMP_TO_EDGE as i32);
            gl::FramebufferTexture(gl::FRAMEBUFFER, gl::COLOR_ATTACHMENT0, framebuffer_texture, 0);

            let draw_buffers: [GLenum; 1] = [gl::COLOR_ATTACHMENT0];
            //let draw_buffers: [GLenum; 2] = [gl::COLOR_ATTACHMENT0, gl::COLOR_ATTACHMENT1];
            gl::DrawBuffers(draw_buffers.len() as i32, draw_buffers.as_ptr());

            //set up framebuffer for blur downscale
            gl::GenFramebuffers(1, &mut blur_framebuffer);
            gl::BindFramebuffer(gl::FRAMEBUFFER, blur_framebuffer);
            //blur texture
            gl::GenTextures(1, &mut blur_texture);
            gl::BindTexture(gl::TEXTURE_2D, blur_texture);
            gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, 1600 / blur_scale, 1200 / blur_scale, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MAG_FILTER, gl::LINEAR as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MIN_FILTER, gl::LINEAR as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_S, gl::CLAMP_TO_EDGE as i32);
            gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_T, gl::CLAMP_TO_EDGE as i32);
            gl::FramebufferTexture(gl::FRAMEBUFFER, gl::COLOR_ATTACHMENT0, blur_texture, 0);

            let draw_buffers: [GLenum; 1] = [gl::COLOR_ATTACHMENT0];
            gl::DrawBuffers(draw_buffers.len() as i32, draw_buffers.as_ptr());
 
            //Actual blur effect
            gl::GenFramebuffers(2, blur_pingpong_framebuffer.as_mut_ptr());
            gl::GenTextures(2, blur_pingpong_texture.as_mut_ptr());
            for i in 0..2 {
                println!("cycle {}", i);
                gl::BindFramebuffer(gl::FRAMEBUFFER, blur_pingpong_framebuffer[i]);
                gl::BindTexture(gl::TEXTURE_2D, blur_pingpong_texture[i]);
                gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, 1600 / blur_scale, 1200 / blur_scale, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
                gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MAG_FILTER, gl::LINEAR as i32);
                gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MIN_FILTER, gl::LINEAR as i32);
                gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_S, gl::CLAMP_TO_EDGE as i32);
                gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_T, gl::CLAMP_TO_EDGE as i32);
                gl::FramebufferTexture2D(gl::FRAMEBUFFER, gl::COLOR_ATTACHMENT0, gl::TEXTURE_2D, blur_pingpong_texture[i], 0);
            }

            let result = gl::CheckFramebufferStatus(gl::FRAMEBUFFER);
            if result != gl::FRAMEBUFFER_COMPLETE {
                println!("ERROR: invalide frambuffer: {}", result);
            }

            gl::BindFramebuffer(gl::FRAMEBUFFER, 0);
        }

        Ok(Self {
            vao,
            vbo,
            program,
            framebuffer_texture,
            blur_texture,
            framebuffer,
            blur_scale,
            blur_framebuffer,
            blur_scale_program,
            blur_pingpong_framebuffer,
            blur_pingpong_texture,
            blur_main_program,
        })
    }

    pub fn setup(&mut self) {
        unsafe {
            gl::BindFramebuffer(gl::FRAMEBUFFER, self.framebuffer);
            gl::Clear(gl::COLOR_BUFFER_BIT);
        }
    }

    pub fn resize(&self, size_info: &SizeInfo) {
        //println!("resize to {}x{}", size_info.width(), size_info.height());
        unsafe {
            gl::BindTexture(gl::TEXTURE_2D, self.framebuffer_texture);
            gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, size_info.width() as i32, size_info.height() as i32, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
            gl::BindTexture(gl::TEXTURE_2D, self.blur_texture);
            gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, size_info.width() as i32 / self.blur_scale, size_info.height() as i32 / self.blur_scale, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
            for i in 0..2 {
                gl::BindTexture(gl::TEXTURE_2D, self.blur_pingpong_texture[i]);
                gl::TexImage2D(gl::TEXTURE_2D, 0, gl::RGBA as i32, size_info.width() as i32 / self.blur_scale, size_info.height() as i32 / self.blur_scale, 0, gl::RGBA, gl::UNSIGNED_BYTE, 0 as *const _);
            }
        }
    }

    pub fn draw(&mut self, size_info: &SizeInfo) {
        unsafe {
            gl::BindVertexArray(self.vao);
            gl::BindBuffer(gl::ARRAY_BUFFER, self.vbo);

            gl::Viewport(0, 0, size_info.width() as i32, size_info.height() as i32);

            //do the blur downsaling
            gl::BindFramebuffer(gl::FRAMEBUFFER, self.blur_framebuffer);

            gl::UseProgram(self.blur_scale_program.id());

            gl::ActiveTexture(gl::TEXTURE0);
            gl::BindTexture(gl::TEXTURE_2D, self.framebuffer_texture);

            self.blur_scale_program.update_uniforms(self.blur_scale as f32);

            gl::DrawArrays(gl::TRIANGLES, 0, 6);

            //actually blur
            gl::Viewport(0, 0, size_info.width() as i32 / self.blur_scale, size_info.height() as i32 / self.blur_scale);

            let mut horizontal = true;
            let mut current_texture = self.blur_texture;
            let amount = 4;
            gl::UseProgram(self.blur_main_program.id());
            for _ in 0..amount {
                gl::BindFramebuffer(gl::FRAMEBUFFER, self.blur_pingpong_framebuffer[horizontal as usize]);
                self.blur_main_program.update_uniforms(horizontal);
                gl::BindTexture(gl::TEXTURE_2D, current_texture);
                gl::DrawArrays(gl::TRIANGLES, 0, 6);
                horizontal = !horizontal;
                current_texture = self.blur_pingpong_texture[!horizontal as usize];
            }

            gl::Viewport(0, 0, size_info.width() as i32, size_info.height() as i32);
            //do main shade
            gl::BindFramebuffer(gl::FRAMEBUFFER, 0);

            gl::UseProgram(self.program.id());

            self.program.update_frame_uniforms();
            
            gl::ActiveTexture(gl::TEXTURE0);
            gl::BindTexture(gl::TEXTURE_2D, self.framebuffer_texture);

            gl::ActiveTexture(gl::TEXTURE1);
            gl::BindTexture(gl::TEXTURE_2D, current_texture);

            self.program.update_uniforms();

            gl::DrawArrays(gl::TRIANGLES, 0, 6);

            gl::UseProgram(0);

            gl::BindBuffer(gl::ARRAY_BUFFER, 0);
            gl::BindVertexArray(0);
        }
    }
}

//static EFFECT_SHADER_F: &str = include_str!("../../res/blur_combine_effect.g.glsl");
static EFFECT_SHADER_F: &str = include_str!("../../res/crtv_2_effect.f.glsl");
static BLUR_EFFECT_SCALE_SHADER_F: &str = include_str!("../../res/blur_scale_effect.f.glsl");
static BLUR_EFFECT_MAIN_SHADER_F: &str = include_str!("../../res/blur_main_effect.g.glsl");
static EFFECT_SHADER_V: &str = include_str!("../../res/effect.v.glsl");

#[derive(Debug)]
pub struct EffectShaderProgram {
    program: ShaderProgram,

    u_framebuffer_texture: Option<GLint>,
    u_framebuffer_blur_texture: Option<GLint>,
    u_time: Option<GLint>,
}

impl EffectShaderProgram {
    pub fn new(shader_version: ShaderVersion) -> Result<Self, ShaderError> {
        let program = ShaderProgram::new(shader_version, None, EFFECT_SHADER_V, EFFECT_SHADER_F)?;
     
        Ok(Self{
            u_framebuffer_texture: program.get_uniform_location(cstr!("renderedTexture")).ok(),
            u_framebuffer_blur_texture: program.get_uniform_location(cstr!("blurTexture")).ok(),
            u_time: program.get_uniform_location(cstr!("time")).ok(),
            program,
        })
    }
    pub fn id(&self) -> u32 {
        return self.program.id();
    }

    pub fn update_uniforms(&self) {
        unsafe {
            if let Some(u_framebuffer_texture) = self.u_framebuffer_texture {
                gl::Uniform1i(u_framebuffer_texture, 0);
            }
            if let Some(u_framebuffer_blur_texture) = self.u_framebuffer_blur_texture {
                gl::Uniform1i(u_framebuffer_blur_texture, 1);
            }

        }
    }

    pub fn update_frame_uniforms(&self) {
        unsafe {
            if let Some(u_time) = self.u_time {
                let duration = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
                let time = duration.as_millis() as f64;
                let time = (time % 100.0) as f32;
                gl::Uniform1f(u_time, time);
            }
        }
    }
}

#[derive(Debug)]
pub struct BlurScaleEffectShaderProgram {
    program: ShaderProgram,

    u_framebuffer_texture: Option<GLint>,
    u_blur_scale: Option<GLint>,
}

impl BlurScaleEffectShaderProgram {
    pub fn new(shader_version: ShaderVersion) -> Result<Self, ShaderError> {
        let program = ShaderProgram::new(shader_version, None, EFFECT_SHADER_V, BLUR_EFFECT_SCALE_SHADER_F)?;

        Ok(Self{
            u_framebuffer_texture: program.get_uniform_location(cstr!("renderedTexture")).ok(),
            u_blur_scale: program.get_uniform_location(cstr!("blur_scale")).ok(),
            program,
        })
    }

    pub fn id(&self) -> u32 {
        return self.program.id();
    }

    pub fn update_uniforms(&self, blur_scale: f32) {
        unsafe {
            if let Some(u_framebuffer_texture) = self.u_framebuffer_texture {
                gl::Uniform1i(u_framebuffer_texture, 0);
            }
            if let Some(u_blur_scale) = self.u_blur_scale {
                gl::Uniform1f(u_blur_scale, blur_scale);
            }
        }
    }
}

#[derive(Debug)]
pub struct BlurMainEffectShaderProgram {
    program: ShaderProgram,

    u_frame_buffer_texture: Option<GLint>,
    u_horizontal: Option<GLint>,
}

impl BlurMainEffectShaderProgram {
    pub fn new(shader_version: ShaderVersion) -> Result<Self, ShaderError> {
        let program = ShaderProgram::new(shader_version, None, EFFECT_SHADER_V, BLUR_EFFECT_MAIN_SHADER_F)?;

        Ok(Self{
            u_frame_buffer_texture: program.get_uniform_location(cstr!("renderedTexture")).ok(),
            u_horizontal: program.get_uniform_location(cstr!("horizontal")).ok(),
            program,
        })
    }

    pub fn id(&self) -> u32 {
        return self.program.id();
    }

    pub fn update_uniforms(&self, horizontal: bool) {
        unsafe {
            if let Some(u_frame_buffer_texture) = self.u_frame_buffer_texture {
                gl::Uniform1i(u_frame_buffer_texture, 0);
            }
            if let Some(u_horizontal) = self.u_horizontal {
                gl::Uniform1i(u_horizontal, horizontal as i32);
            }
        }
    }
}
