//
//  GraphicsDemoViewController.m
//  MTHawkeyeDemo
//
//  Created by EuanC on 2019/3/7.
//  Copyright © 2019 Meitu. All rights reserved.
//

#import "GraphicsDemoViewController.h"
#import "GraphicsTextureGLKView.h"

@interface GraphicsDemoViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIButton *addTextureButton;
@property (nonatomic, strong) UIButton *addLeakTextureButton;

@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *exceptionDataSource;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation GraphicsDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self layoutInit];
}

- (void)layoutInit {
    self.addTextureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addTextureButton.backgroundColor = [UIColor colorWithRed:85 / 255.0 green:155 / 255.0 blue:242 / 255.0 alpha:1.0];
    [self.addTextureButton setTintColor:[UIColor whiteColor]];
    [self.addTextureButton setTitle:@"show a GL texture" forState:UIControlStateNormal];
    [self.addTextureButton addTarget:self action:@selector(addTextureEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addTextureButton];
    self.addTextureButton.frame = CGRectMake(20, 130, 150, 40);
    self.addTextureButton.layer.cornerRadius = 40 / 2.0;

    self.addLeakTextureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addLeakTextureButton.backgroundColor = [UIColor colorWithRed:85 / 255.0 green:155 / 255.0 blue:242 / 255.0 alpha:1.0];
    [self.addLeakTextureButton setTintColor:[UIColor whiteColor]];
    [self.addLeakTextureButton setTitle:@"leak a GL texture" forState:UIControlStateNormal];
    [self.addLeakTextureButton addTarget:self action:@selector(leakTextureEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addLeakTextureButton];
    self.addLeakTextureButton.frame = CGRectMake(200, 130, 150, 40);
    self.addLeakTextureButton.layer.cornerRadius = 40 / 2.0;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 380, self.view.frame.size.width, self.view.frame.size.height - 380) style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    self.exceptionDataSource = @[ @[ @"Using An Doesn't Exist Object", @"Using An Released Object" ], @[ @"Using An Object", @"Delete An Object" ] ];
}

- (void)addTextureEvent:(UIButton *)sender {
    GraphicsTextureGLKView *view = [self genrateTextureViewUsingShareGroup:nil];
    view.imageToRender = [UIImage imageNamed:@"graphics_texture"];
    view.frame = CGRectMake(20, 200, 150, 150);
    view.backgroundColor = [UIColor redColor];
    [self.view addSubview:view];

    static int count = 1;
    UILabel *countLabel = [self.view viewWithTag:1];
    if (!countLabel) {
        count = 1;
        countLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 350, 50, 20)];
        countLabel.tag = 1;
        [self.view addSubview:countLabel];
    }
    countLabel.text = [NSString stringWithFormat:@"%d", count++];
    [self.view bringSubviewToFront:countLabel];
}

- (void)leakTextureEvent:(UIButton *)sender {
    GraphicsTextureGLKView *view = [self genrateTextureViewUsingShareGroup:nil];
    view.imageToRender = [UIImage imageNamed:@"graphics_texture1"];
    view.frame = CGRectMake(200, 200, 150, 150);
    view.backgroundColor = [UIColor whiteColor];
    view.leakTexture = YES;
    [self.view addSubview:view];

    static int count = 1;
    UILabel *countLabel = [self.view viewWithTag:2];
    if (!countLabel) {
        countLabel = [[UILabel alloc] initWithFrame:CGRectMake(210, 350, 50, 20)];
        countLabel.tag = 2;
        [self.view addSubview:countLabel];
    }
    countLabel.text = [NSString stringWithFormat:@"%d", count++];
    [self.view bringSubviewToFront:countLabel];
}

- (GraphicsTextureGLKView *)genrateTextureViewUsingShareGroup:(EAGLSharegroup *)shareGroup {
    EAGLContext *contex = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
    GraphicsTextureGLKView *view = [[GraphicsTextureGLKView alloc] initWithFrame:CGRectZero context:contex];
    return view;
}

#pragma mark -
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"GL Objects belong to this context";
    }
    if (section == 1) {
        return @"GL Objects doesn't belong to this context";
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.exceptionDataSource.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.exceptionDataSource[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GraphicsCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"GraphicsCell"];
    }
    cell.textLabel.text = self.exceptionDataSource[indexPath.section][indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];

    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: {
                EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
                [EAGLContext setCurrentContext:context];
                // 没有glGenTexture不会把当前上下文加入进去
                glBindTexture(GL_TEXTURE_2D, 1);
                [EAGLContext setCurrentContext:nil];
                break;
            }

            case 1: {
                EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
                [EAGLContext setCurrentContext:context];
                GLESTextureInfo texture = [GLESTool texture:[UIImage imageNamed:@"graphics_texture"]];
                [GLESTool releaseTexture:texture];
                glBindTexture(GL_TEXTURE_2D, texture.texutreId);
                [EAGLContext setCurrentContext:nil];
                break;
            }
            default:
                break;
        }
    }

    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: {
                EAGLContext *context0 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
                EAGLContext *context1 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
                [EAGLContext setCurrentContext:context0];
                GLESTextureInfo texture = [GLESTool texture:[UIImage imageNamed:@"graphics_texture"]];

                // change to context1 , texture belong to contxt0
                // 会没有把 context1的上下文加入进去 应该是要hook setCurrentContext方法把shareGroup加进去
                [EAGLContext setCurrentContext:context1];
                //                GLuint fbo;
                //                glGenFramebuffers(1, &fbo);

                glBindTexture(GL_TEXTURE_2D, texture.texutreId);


                //                [EAGLContext setCurrentContext:context0];
                //                [GLESTool releaseTexture:texture]; // texture1 & texture0 id is same
                [EAGLContext setCurrentContext:nil];
                break;
            }

            case 1: {
                EAGLContext *context0 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
                EAGLContext *context1 = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

                [EAGLContext setCurrentContext:context0];
                GLESTextureInfo texture = [GLESTool texture:[UIImage imageNamed:@"graphics_texture"]];

                // change to context1 , texture belong to contxt0
                [EAGLContext setCurrentContext:context1];
                GLESTextureInfo texture1 = [GLESTool texture:[UIImage imageNamed:@"graphics_texture1"]];
                [GLESTool releaseTexture:texture]; // texture1 & texture0 id is same

                glBindTexture(GL_TEXTURE_2D, texture1.texutreId);

                // 防止提前释放context 导致
                [EAGLContext setCurrentContext:context0];
                [GLESTool releaseTexture:texture];
                [EAGLContext setCurrentContext:nil];
                break;
            }
            default:
                break;
        }
    }
}
@end
