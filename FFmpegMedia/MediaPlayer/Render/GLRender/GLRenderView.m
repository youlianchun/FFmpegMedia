//
//  GLRenderView.m
//  FFmpegMedia
//
//  Created by YLCHUN on 2018/11/10.
//  Copyright © 2018年 YLCHUN. All rights reserved.
//

#import "GLRenderView.h"
@import OpenGLES;
@import QuartzCore;
//////////////////////////////////////////////////////////

#pragma mark - shaders

#define TO_STRING(str) @#str
static NSString *const vertexShaderString = TO_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 tc;
 
 void main() {
     gl_Position = modelViewProjectionMatrix * position;
     tc = texcoord.xy;
 }
 );

static NSString *const fragmentShaderString_rgb = TO_STRING
(
 varying highp vec2 tc;
 uniform sampler2D s_texture_rgb;
 
 void main() {
     gl_FragColor = texture2D(s_texture_rgb, tc);
 }
 );

static NSString *const fragmentShaderString_yuv420P = TO_STRING
(
 varying highp vec2 tc;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, tc).r;
     highp float u = texture2D(s_texture_u, tc).r - 0.5;
     highp float v = texture2D(s_texture_v, tc).r - 0.5;
     highp float r = y + 1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );

static NSString *const fragmentShaderString_yuv420SP = TO_STRING
(
 varying highp vec2 tc;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_uv;
 
 void main(void)
 {
     highp float y = texture2D(s_texture_y, tc).r;
     highp float u = texture2D(s_texture_uv, tc).r - 0.5;
     highp float v = texture2D(s_texture_uv, tc).g - 0.5;
     highp float r = y + 1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );


static BOOL validateProgram(GLuint prog)
{
    GLint status;
    
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", prog);
        return NO;
    }
    
    return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
    GLint status;
    const GLchar *sources = (GLchar *)shaderString.UTF8String;
    
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        NSLog(@"Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}

//////////////////////////////////////////////////////////
static void glDelTextures(GLsizei count, GLuint *textures) {
    if (count == 0) return;
    if (textures[0])
        glDeleteTextures(count, textures);
}

static void glSetTextures(GLsizei count, GLuint *textures, const UInt8 **pixels,const GLsizei *widths, const GLsizei *heights, const GLuint *formats) {
    if (count == 0) return;
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    // 生成纹理
    if (0 == textures[0])
        glGenTextures(count, textures);
    
    for (int i = 0; i < count; ++i) {
        
        glBindTexture(GL_TEXTURE_2D, textures[i]);// 绑定纹理 也就是指定下面要操作的是_texture这个纹理
        
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     formats[i],
                     widths[i],
                     heights[i],
                     0,
                     formats[i],
                     GL_UNSIGNED_BYTE,
                     pixels[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

static BOOL glPrepareRender(GLsizei count, GLuint *textures, GLint *uniformSamplers) {
    if (count == 0) return NO;
    if (textures[0] == 0) return NO;
    for (int i = 0; i < count; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);// 选择一个纹理槽位 GL_TEXTURE0 + n
        glBindTexture(GL_TEXTURE_2D, textures[i]);// 绑定纹理
        // 给shader里的变量赋值
        /*
         第一个参数指定被赋值变量的位置 同一个shader里面会定义多个输出对象 每个都有自己的对应的位置 可以这样获得：
         _uniformSampler = glGetUniformLocation(program, "s_texture");
         这就是取得uniform变量s_texture的位置，赋值给_uniformSampler。下面方法第二个参数就是指定哪个纹理，传入n，就是GL_TEXTURE0+n槽位的纹理，这里传入0，结合代码3.1和3.2，其实就是把_texture。然后_uniformSampler是s_texture的位置，所以整体就是把_texture赋值给了shader里面的s_texture变量。
         这样，纹理数据就传递给了shader，进入到OpenGL的pipline里了。
         */
        glUniform1i(uniformSamplers[i], i);
    }
    return YES;
}

//////////////////////////////////////////////////////////
#import "GLTexture.h"

@protocol GLRendererProtocol
- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (BOOL) prepareRender;
- (void) setTexture: (GLTexture *)texture;
@end

#pragma mark - frame renderers

@interface GLRenderer_RGB : NSObject<GLRendererProtocol>
@end

@implementation GLRenderer_RGB
{
    GLint _uniformSamplers[1];
    GLuint _textures[1];
}

- (BOOL) isValid {
    return (_textures[0] != 0);
}

- (NSString *) fragmentShader {
    return fragmentShaderString_rgb;
}

- (void) resolveUniforms: (GLuint) program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_rgb");
}

// 把frame转化成纹理
- (void) setTexture: (GLTextureRGB *)texture {
//    assert(texture.RGBA.length == texture.width * texture.height * 3);
    const UInt8 *pixels[1] = { texture.RGBA.bytes };
    const GLsizei widths[1]  = { texture.width };
    const GLsizei heights[1] = { texture.height };
    const GLuint format[1] = { GL_RGB };
    glSetTextures(1, _textures, pixels, widths, heights, format);
}

- (BOOL) prepareRender {
    return glPrepareRender(1, _textures, _uniformSamplers);
}

- (void) dealloc {
    glDelTextures(1, _textures);
}

@end

@interface GLRenderer_YUV420P : NSObject<GLRendererProtocol>
@end

@implementation GLRenderer_YUV420P
{
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}


- (BOOL) isValid {
    return (_textures[0] != 0);
}

- (NSString *) fragmentShader {
    return fragmentShaderString_yuv420P;
}

- (void) resolveUniforms: (GLuint) program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void) setTexture: (GLTextureYUV_P *)texture {
//    assert(texture.Y.length == texture.width * texture.height);
//    assert(texture.U.length == (texture.width * texture.height) / 4);
//    assert(texture.V.length == (texture.width * texture.height) / 4);
    
    const UInt8 *pixels[3] = { texture.Y.bytes, texture.U.bytes, texture.V.bytes };
    const GLsizei widths[3] = { texture.width, texture.width / 2, texture.width / 2 };
    const GLsizei heights[3] = { texture.height, texture.height / 2, texture.height / 2 };
    const GLuint format[3] = { GL_LUMINANCE, GL_LUMINANCE, GL_LUMINANCE };
    
    glSetTextures(3, _textures, pixels, widths, heights, format);
}

- (BOOL) prepareRender {
    return glPrepareRender(3, _textures, _uniformSamplers);
}

- (void) dealloc {
    glDelTextures(3, _textures);
}

@end

@interface GLRenderer_YUV420SP : NSObject<GLRendererProtocol>
@end

@implementation GLRenderer_YUV420SP
{
    GLint _uniformSamplers[2];
    GLuint _textures[2];
}

- (BOOL) isValid {
    return (_textures[0] != 0);
}


- (NSString *) fragmentShader {
    return fragmentShaderString_yuv420SP;
}

- (void)resolveUniforms: (GLuint) program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_uv");
}

- (void) setTexture: (GLTextureYUV_SP *)texture {
    const UInt8 *pixels[2] = { texture.Y.bytes, texture.UV.bytes};
    const GLsizei widths[2]  = { texture.width, texture.width / 2 };
    const GLsizei heights[2] = { texture.height, texture.height / 2 };
    const GLuint format[2] = { GL_RED, GL_RG };
    
    glSetTextures(3, _textures, pixels, widths, heights, format);
}

- (BOOL) prepareRender {
    return glPrepareRender(2, _textures, _uniformSamplers);
}

- (void) dealloc {
    glDelTextures(2, _textures);
}

@end


//////////////////////////////////////////////////////////

#pragma mark - gl view

enum {
    ATTRIBUTE_VERTEX,
    ATTRIBUTE_TEXCOORD,
};

@implementation GLRenderView {
    
    EAGLContext     *_context;
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
    GLint           _backingWidth;
    GLint           _backingHeight;
    GLuint          _program;
    GLint           _uniformMatrix;
    GLfloat         _vertices[8];
    
    id<GLRendererProtocol> _renderer;
    
    CGSize _size;
    BOOL _isYUV;
}
@synthesize textureSize = _size;

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id) initWithFrame:(CGRect)frame textureType:(GLTextureType)type size:(CGSize)size
{
    self = [super initWithFrame:frame];
    if (self) {
        super.contentMode = UIViewContentModeScaleAspectFit;
        _size = size;
        switch (type) {
            case GLTextureTypeRGB:
                 _renderer = [[GLRenderer_RGB alloc] init];
                break;
            case GLTextureTypeYUV420P:
                _renderer = [[GLRenderer_YUV420P alloc] init];
                break;
            case GLTextureTypeYUV420SP:
                _renderer = [[GLRenderer_YUV420SP alloc] init];
                break;
        }
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context ||
            ![EAGLContext setCurrentContext:_context]) {
            NSLog( @"failed to setup EAGLContext");
            self = nil;
            return nil;
        }
        
        // render buffer的绑定代码
        // 生成和绑定一个render buffer 实际上只是生成了一个名字 并没有内存空间
        glGenFramebuffers(1, &_framebuffer);
        glGenRenderbuffers(1, &_renderbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        
        // _context从self.layer获取到一段内存给新生成的render buffer
        // 根据iOS文档，render buffer和这个CAEAGLLayer对象是共享内存的
        // 没看到具体文档，但我猜这就是为什么_context调用presentRenderbuffer，然后self.layer就会更新内容的原因，这句代码把_context、render buffer和self.layer关联了起来。
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
        
        
        // 把render buffer 绑定给FBO,注意第二个参数使用GL_COLOR_ATTACHMENT0，这个指定了这个render buffer使用来存储颜色信息的，所以OpenGL把数据渲染到FBO后，这个render buffer保存的是颜色信息。
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            
            NSLog(@"failed to make complete framebuffer object %x", status);
            self = nil;
            return nil;
        }
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            
            NSLog(@"failed to setup GL %x", glError);
            self = nil;
            return nil;
        }
        
        if (![self loadShaders]) {
            
            self = nil;
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
        
        NSLog(@"OK setup GL");
    }
    
    return self;
}

- (void)dealloc
{
    _renderer = nil;
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
}

- (void)layoutSubviews
{
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        
        NSLog(@"failed to make complete framebuffer object %x", status);
        
    } else {
        
        NSLog(@"OK setup GL framebuffer %d:%d", _backingWidth, _backingHeight);
    }
    
    [self updateVertices];
    [self renderTexture:nil];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    [self updateVertices];
    if (_renderer.isValid)
        [self renderTexture:nil];
}

static BOOL loadShaders(NSString *fragmentShader, void(^callback)(GLint uniformMatrix, GLuint program))
{
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
    GLint uniformMatrix = 0, program = 0;
    
    program = glCreateProgram();
    
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShaderString);
    if (!vertShader) {
        glDeleteProgram(program);
        return NO;
    }
    
    fragShader = compileShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (!fragShader){
        glDeleteProgram(program);
        glDeleteShader(vertShader);
        return NO;
    }
    
    glAttachShader(program, vertShader);
    glAttachShader(program, fragShader);
    glBindAttribLocation(program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(program, ATTRIBUTE_TEXCOORD, "texcoord");
    
    glLinkProgram(program);
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", program);
        glDeleteProgram(program);
        glDeleteShader(vertShader);
        glDeleteShader(fragShader);
        return NO;
    }
    
    result = validateProgram(program);
    if (!result) {
        glDeleteProgram(program);
        glDeleteShader(vertShader);
        glDeleteShader(fragShader);
        return NO;
    }
    uniformMatrix = glGetUniformLocation(program, "modelViewProjectionMatrix");
    
    callback(uniformMatrix, program);
    
    glDeleteShader(vertShader);
    glDeleteShader(fragShader);

    return result;
}

- (BOOL)loadShaders
{
    return loadShaders(_renderer.fragmentShader, ^(GLint uniformMatrix, GLuint program) {
        self->_uniformMatrix = uniformMatrix;
        self->_program = program;
        [self->_renderer resolveUniforms:self->_program];
    });
}

- (void)updateVertices
{
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = _size.width;
    const float height  = _size.height;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

-(void)onRender:(BOOL(^)(void))prepare {
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    [EAGLContext setCurrentContext:_context];
    
    // 绑定_framebuffer 之后所有的framebuffer的操作就是针对这个_framebuffer了
    // OpenGL的绘制结果不是直接显示到屏幕上，而是存起来了，这个存储的东西就是FBO。所以FBO里面包含了color、depth、stencil等一些用于显示的信息。
    // 指定当前使用的FBO是哪个，然后执行后数据就会输入到这个FBO里了。frameBuffer Object(FBO)
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(_program);
    
    // 有了数据纹理 就把纹理传到OpenGL的pipline里去
    if (prepare()) {
        
        GLfloat modelviewProj[16];
        mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
        glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
        
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    // OpenGL把数据输入给我们绑定的FBO，FBO管理着各种buffer，其中就有color buffer。_renderbuffer就是绑定在当前FBO上的color buffer，存储着颜色信息，第一句glBindRenderbuffer指定下面对GL_RENDERBUFFER的操作是使用GL_RENDERBUFFER，然后_context显示render buffer。然后数据就被显示到屏幕上了。
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void) renderTexture: (GLTexture*)texture {
    [self onRender:^BOOL{
        if (texture) {
            [self->_renderer setTexture:texture];
        }
        return [self->_renderer prepareRender];
    }];
}
@end
