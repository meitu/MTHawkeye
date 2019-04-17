//
//  GraphicsTextureGLKView.m
//  MTHawkeyeDemo
//
//  Created by David.Dai on 2019/3/20.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "GraphicsTextureGLKView.h"
@interface GraphicsTextureGLKView ()
@property (nonatomic, assign) GLESProgram textureProgram;
@property (nonatomic, assign) GLESTextureProgramAttribute textureProgramAttr;
@property (nonatomic, assign) GLESTextureInfo textureInfo;
@end

@implementation GraphicsTextureGLKView

- (void)setImageToRender:(UIImage *)imageToRender {
    _imageToRender = imageToRender;

    [EAGLContext setCurrentContext:self.context];
    [GLESTool releaseProgram:self.textureProgram];
    [GLESTool releaseTexture:self.textureInfo];

    self.textureInfo = [GLESTool texture:imageToRender];
    self.textureProgram = [GLESTool programWithVertexShader:kTexutreVertexShaderString fragmentShader:kTextureFragmentShaderString];
    self.textureProgramAttr = [GLESTool attchTextureAttributeToProgram:self.textureProgram];
    [EAGLContext setCurrentContext:nil];
}

- (void)dealloc {
    if (_leakTexture) {
        return;
    }
    [EAGLContext setCurrentContext:self.context];
    [GLESTool releaseProgram:self.textureProgram];
    [GLESTool releaseTexture:self.textureInfo];
    [EAGLContext setCurrentContext:nil];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (!self.imageToRender || !self.context) {
        return;
    }

    CGFloat r = 0, g = 0, b = 0, a = 1;
    [self.backgroundColor getRed:&r green:&g blue:&b alpha:&a];

    [EAGLContext setCurrentContext:self.context];

    glUseProgram(self.textureProgram.program);
    glClearColor((float)r, (float)g, (float)b, (float)a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    const float inputTextureCoor[8] = {
        0, 0,
        1.0, 0,
        0, 1.0,
        1.0, 1.0};

    float rotateInputTextureCoor[8];
    rotateInputTextureCoor[0] = inputTextureCoor[4];
    rotateInputTextureCoor[1] = inputTextureCoor[5];
    rotateInputTextureCoor[2] = inputTextureCoor[6];
    rotateInputTextureCoor[3] = inputTextureCoor[7];
    rotateInputTextureCoor[4] = inputTextureCoor[0];
    rotateInputTextureCoor[5] = inputTextureCoor[1];
    rotateInputTextureCoor[6] = inputTextureCoor[2];
    rotateInputTextureCoor[7] = inputTextureCoor[3];

    GLfloat *positionCoor = [GLESTool textureVertexForViewSize:self.frame.size textureSize:CGSizeMake(self.textureInfo.width, self.textureInfo.height)];

    glEnableVertexAttribArray(self.textureProgramAttr.positionAttribute);
    glEnableVertexAttribArray(self.textureProgramAttr.inputTextureCoorAttribute);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureInfo.texutreId);
    glUniform1i(self.textureProgramAttr.textureUniform, 0);

    glVertexAttribPointer(self.textureProgramAttr.positionAttribute, 2, GL_FLOAT, GL_FALSE, 0, positionCoor);
    glVertexAttribPointer(self.textureProgramAttr.inputTextureCoorAttribute, 2, GL_FLOAT, GL_FALSE, 0, rotateInputTextureCoor);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDisableVertexAttribArray(self.textureProgramAttr.positionAttribute);
    glDisableVertexAttribArray(self.textureProgramAttr.inputTextureCoorAttribute);

    [EAGLContext setCurrentContext:nil];
}
@end
