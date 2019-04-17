//
//  GLESTool.h
//  MTHawkeyeDemo
//
//  Created by David.Dai on 2019/3/20.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

#define GLES_LONG_STRING(x) #x
#define GLES_SHADER_STRING(name) @GLES_LONG_STRING(name)

extern NSString *const kTexutreVertexShaderString;
extern NSString *const kTextureFragmentShaderString;

typedef struct {
    GLuint program;
    GLuint vertexShader;
    GLuint fragmentShader;
} GLESProgram;

typedef struct {
    GLint positionAttribute;
    GLint inputTextureCoorAttribute;
    GLint textureUniform;
} GLESTextureProgramAttribute;

typedef struct {
    GLuint texutreId;
    float width;
    float height;
} GLESTextureInfo;

@interface GLESTool : NSObject
+ (GLESProgram)programWithVertexShader:(NSString *)vertexShaderStr fragmentShader:(NSString *)fragmentShaderStr;
+ (void)releaseProgram:(GLESProgram)program;
+ (GLESTextureProgramAttribute)attchTextureAttributeToProgram:(GLESProgram)program;
+ (GLint)attributeIndex:(NSString *)attributeName program:(GLuint)program;
+ (GLint)uniformIndex:(NSString *)uniformName program:(GLuint)program;

+ (GLESTextureInfo)texture:(UIImage *)image;
+ (void)releaseTexture:(GLESTextureInfo)textureInfo;
+ (unsigned char *)pixelRGBABytesFromImageRef:(CGImageRef)imageRef;
+ (GLfloat *)textureVertexForViewSize:(CGSize)viewSize textureSize:(CGSize)textureSize;
@end

NS_ASSUME_NONNULL_END
