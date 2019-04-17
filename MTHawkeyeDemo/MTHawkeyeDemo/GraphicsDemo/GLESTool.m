//
//  GLESTool.m
//  MTHawkeyeDemo
//
//  Created by David.Dai on 2019/3/20.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "GLESTool.h"

NSString *const kTexutreVertexShaderString = GLES_SHADER_STRING(
    attribute vec2 position;
    attribute vec2 inputTextureCoordinate;
    varying vec2 textureCoordinate;

    void main() {
        gl_Position = vec4(position.xy, 0, 1);
        textureCoordinate = inputTextureCoordinate;
    });

NSString *const kTextureFragmentShaderString = GLES_SHADER_STRING(
    varying highp vec2 textureCoordinate;
    uniform sampler2D inputTexture;

    void main() {
        gl_FragColor = texture2D(inputTexture, textureCoordinate);
    });

@implementation GLESTool

#pragma mark - GLES Program Tool
+ (GLESProgram)programWithVertexShader:(NSString *)vertexShaderStr fragmentShader:(NSString *)fragmentShaderStr {
    GLuint program = 0;
    GLint status = 0;
    GLuint vertexShader = 0;
    GLuint fragmentShader = 0;

    program = glCreateProgram();

    const GLchar *verSource = [vertexShaderStr cStringUsingEncoding:NSUTF8StringEncoding];
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &verSource, NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        GLint logLength = 0;
        glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar log[logLength];
            glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
            NSLog(@"%s", log);
        }
        return (GLESProgram){0, 0, 0};
    }

    const GLchar *fragSource = [fragmentShaderStr cStringUsingEncoding:NSUTF8StringEncoding];
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragSource, NULL);
    glCompileShader(fragmentShader);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        GLint logLength = 0;
        glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar log[logLength];
            glGetShaderInfoLog(fragmentShader, logLength, &logLength, log);
            NSLog(@"%s", log);
        }
        return (GLESProgram){0, 0, 0};
    }

    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);

    glLinkProgram(program);
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        return (GLESProgram){0, 0, 0};
    }

    if (vertexShader) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }

    if (fragmentShader) {
        glDeleteShader(fragmentShader);
        fragmentShader = 0;
    }

    GLESProgram glProgram = {program, vertexShader, fragmentShader};
    return glProgram;
}

+ (void)releaseProgram:(GLESProgram)program {
    if (program.vertexShader) {
        glDeleteShader(program.vertexShader);
    }

    if (program.fragmentShader) {
        glDeleteShader(program.fragmentShader);
    }

    if (program.program) {
        glDeleteProgram(program.program);
    }
}

+ (GLESTextureProgramAttribute)attchTextureAttributeToProgram:(GLESProgram)program {
    GLESTextureProgramAttribute textureAttr;
    textureAttr.inputTextureCoorAttribute = [self attributeIndex:@"inputTextureCoordinate" program:program.program];
    textureAttr.positionAttribute = [self attributeIndex:@"position" program:program.program];
    textureAttr.textureUniform = [self uniformIndex:@"inputTexture" program:program.program];
    return textureAttr;
}

+ (GLint)attributeIndex:(NSString *)attributeName program:(GLuint)program {
    return glGetAttribLocation(program, [attributeName cStringUsingEncoding:NSUTF8StringEncoding]);
}

+ (GLint)uniformIndex:(NSString *)uniformName program:(GLuint)program {
    return glGetUniformLocation(program, [uniformName cStringUsingEncoding:NSUTF8StringEncoding]);
}

#pragma mark - GLES Texture Tool
+ (unsigned char *)pixelRGBABytesFromImageRef:(CGImageRef)imageRef {
    int RGBA = 4;

    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)malloc(width * height * sizeof(unsigned char) * RGBA);
    NSUInteger bytesPerPixel = RGBA;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
        bitsPerComponent, bytesPerRow, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);

    return rawData;
}

+ (GLuint)getImageTexutre:(UIImage *)image {
    GLuint imageFormat = GL_RGBA;
    int alignment = 1;

    GLuint texureFormat = GL_RGBA;
    GLuint textureId = 0;

    void *data = [self pixelRGBABytesFromImageRef:image.CGImage];

    // 字节对齐方式
    glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);

    // 生成并绑定Texure
    glGenTextures(1, &textureId);
    glBindTexture(GL_TEXTURE_2D, textureId);
    glTexImage2D(GL_TEXTURE_2D, 0, imageFormat, (int)image.size.width, (int)image.size.height, 0, texureFormat, GL_UNSIGNED_BYTE, data);

    // 设置纹理单元的滤波方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // 设置纹理单元的环绕模式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

    return textureId;
}

+ (void)releaseTexture:(GLESTextureInfo)textureInfo {
    if (textureInfo.texutreId != 0) {
        glDeleteTextures(1, &textureInfo.texutreId);
    }
}

+ (GLfloat *)textureVertexForViewSize:(CGSize)viewSize textureSize:(CGSize)textureSize {
    static GLfloat position[8];

    GLfloat viewAspectRatio = (float)viewSize.width / (float)viewSize.height;
    GLfloat textureAspectRatio = (float)textureSize.width / (float)textureSize.height;

    GLfloat widthScaling = 1;
    GLfloat heightScaling = 1;
    if (viewAspectRatio < textureAspectRatio) {
        GLfloat height = ((float)viewSize.width / (float)textureSize.width) * (float)textureSize.height;
        heightScaling = height / (float)viewSize.height;
    } else {
        GLfloat width = ((float)viewSize.height / (float)textureSize.height) * (float)textureSize.width;
        widthScaling = width / (float)viewSize.width;
    }

    position[0] = -widthScaling;
    position[1] = -heightScaling;
    position[2] = widthScaling;
    position[3] = -heightScaling;
    position[4] = -widthScaling;
    position[5] = heightScaling;
    position[6] = widthScaling;
    position[7] = heightScaling;
    return position;
}

+ (GLESTextureInfo)texture:(UIImage *)image {
    GLESTextureInfo textureInfo;
    textureInfo.texutreId = [self getImageTexutre:image];
    textureInfo.width = (float)image.size.width;
    textureInfo.height = (float)image.size.height;
    return textureInfo;
}
@end
