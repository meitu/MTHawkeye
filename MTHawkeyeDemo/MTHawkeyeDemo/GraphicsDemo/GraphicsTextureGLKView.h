//
//  GraphicsTextureGLKView.h
//  MTHawkeyeDemo
//
//  Created by David.Dai on 2019/3/20.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import <GLKit/GLKit.h>
#import "GLESTool.h"

NS_ASSUME_NONNULL_BEGIN

@interface GraphicsTextureGLKView : GLKView
@property (nonatomic, strong, nullable) UIImage *imageToRender;
@property (nonatomic, assign) BOOL leakTexture;
@end

NS_ASSUME_NONNULL_END
