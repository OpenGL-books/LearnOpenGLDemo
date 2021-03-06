//
//  ViewController.m
//  ch6-1
//
//  Created by wutaotao on 2017/5/20.
//  Copyright © 2017年 wutaotao. All rights reserved.
//

#import "ViewController.h"
#import "SceneCarModel.h"
#import "SceneRinkModel.h"
#import "AGLKContext.h"
#import "SceneCar.h"


@interface ViewController (){
    NSMutableArray *cars;
}

@property (strong , nonatomic) GLKBaseEffect *baseEffect;
@property (strong , nonatomic) SceneModel *carModel;
@property (strong , nonatomic) SceneModel *rinkModel;
@property (nonatomic, assign) BOOL shouldUseFirstPersonPOV;
@property (nonatomic, assign) GLfloat pointOfViewAnimationCountdown;
@property (nonatomic, assign) GLKVector3 eyePosition;
@property (nonatomic,assign) GLKVector3 lookAtPositioon;
@property (nonatomic,assign) GLKVector3 targetEyePosition;
@property (nonatomic, assign) GLKVector3 targetLookAtPosition;

@property (nonatomic, assign, readwrite)
SceneAxisAllignedBoundingBox rinkBoundingBox;

@end

@implementation ViewController

static const int SceneNumberOfPOVAnimationSeconds = 2.0;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    cars = [[NSMutableArray alloc]init];
    
    GLKView *view = (GLKView *)self.view;
    
    NSAssert([view isKindOfClass:[GLKView class]], @"View controller's view is not a GLKView");
    
    view.drawableDepthFormat = GLKViewDrawableDepthFormat16;
    view.context = [[AGLKContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [AGLKContext setCurrentContext:view.context];
    
    self.baseEffect = [[GLKBaseEffect alloc]init];
    self.baseEffect.light0.enabled = GL_TRUE;
    self.baseEffect.light0.ambientColor = GLKVector4Make(0.6f, 0.6f, 0.6f, 1.0f);
    self.baseEffect.light0.position = GLKVector4Make(1.0f, 0.8f, 0.4f, 0.0f);
    
    ((AGLKContext *)view.context).clearColor = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
    [((AGLKContext *)view.context) enable:GL_DEPTH_TEST];
    [((AGLKContext *)view.context) enable:GL_BLEND];
    
    self.carModel = [[SceneCarModel alloc]init];
    self.rinkModel = [[SceneRinkModel alloc]init];
    
    self.rinkBoundingBox = self.rinkModel.axisAlignedBoundingBox;
    NSAssert(0 < (self.rinkBoundingBox.max.x - self.rinkBoundingBox.min.x)&& 0 < (self.rinkBoundingBox.max.z - self.rinkBoundingBox.min.z), @"Rink has no area");
    
    SceneCar *newCar = [[SceneCar alloc]initWithModel:self.carModel position:GLKVector3Make(1.0, 0.0, 1.0) velocity:GLKVector3Make(1.5, 0.0, 1.5) color:GLKVector4Make(0.0, 0.5, 0.0, 1.0)];
    [cars addObject:newCar];
    
    newCar = [[SceneCar alloc]initWithModel:self.carModel position:GLKVector3Make(-1.0, 0.0, 1.0) velocity:GLKVector3Make(-1.5, 0.0, 1.5) color:GLKVector4Make(0.5, 0.5, 0.0, 1.0)];
    [cars addObject:newCar];
    
    newCar = [[SceneCar alloc]initWithModel:self.carModel position:GLKVector3Make(1.0, 0.0, -1.0) velocity:GLKVector3Make(-1.5, 0.0, -1.5) color:GLKVector4Make(0.5, 0.0, 0.0, 1.0)];
    [cars addObject:newCar];
    
    newCar = [[SceneCar alloc]initWithModel:self.carModel position:GLKVector3Make(2.0, 0.0, -2.0) velocity:GLKVector3Make(-1.5, 0.0, -0.5) color:GLKVector4Make(0.3, 0.0, 0.3, 1.0)];
    [cars addObject:newCar];
    
    self.eyePosition = GLKVector3Make(10.5, 5.0, 0.0);
    self.lookAtPositioon = GLKVector3Make(0.0, 0.5, 0.0);
    
}

-(void)updatePointOfView{
    
    if (!self.shouldUseFirstPersonPOV) {
        self.eyePosition = GLKVector3Make(10.5, 5.0, 0.0);
        self.lookAtPositioon = GLKVector3Make(0.0, 0.5, 0.0);
    }else{
        
        SceneCar *viewCar = [cars lastObject];
        self.targetEyePosition = GLKVector3Make(viewCar.position.x, viewCar.position.y + 0.45f, viewCar.position.z);
        
        self.targetLookAtPosition = GLKVector3Add(_eyePosition, viewCar.velocity);
        
    }
}

-(void)update{
    
    if (0 < self.pointOfViewAnimationCountdown) {
        
        self.pointOfViewAnimationCountdown -= self.timeSinceLastUpdate;
        self.eyePosition = SceneVector3SlowLowPassFilter(self.timeSinceLastUpdate, self.targetEyePosition, self.eyePosition);
        
        self.lookAtPositioon = SceneVector3SlowLowPassFilter(self.timeSinceLastUpdate, self.targetLookAtPosition, self.lookAtPositioon)
        ;
    }else{
        
        self.eyePosition = SceneVector3FastLowPassFilter(self.timeSinceLastUpdate, self.targetEyePosition, self.eyePosition);
        
        self.lookAtPositioon = SceneVector3FastLowPassFilter(self.timeSinceLastUpdate, self.targetLookAtPosition, self.lookAtPositioon);
        
    }
    [cars makeObjectsPerformSelector:@selector(updateWithController:) withObject:self];
    
    [self updatePointOfView];
}

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    self.baseEffect.light0.diffuseColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
    
    [((AGLKContext *)view.context) clear:GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT];
    
    const GLfloat aspectRatio = (GLfloat)view.drawableWidth / (GLfloat)view.drawableHeight;
    
    self.baseEffect.transform.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(35.0f), aspectRatio, 0.1f, 25.0f);
    
    self.baseEffect.transform.modelviewMatrix = GLKMatrix4MakeLookAt(self.eyePosition.x, self.eyePosition.y, self.eyePosition.z, self.lookAtPositioon.x, self.lookAtPositioon.y, self.lookAtPositioon.z, 0, 1, 0);
    [self.baseEffect prepareToDraw];
    [self.rinkModel draw];
    
    [cars makeObjectsPerformSelector:@selector(drawWithBaseEffect:) withObject:self.baseEffect];
}

-(void)dealloc
{
//    [super dealloc];
    GLKView *view = (GLKView *)self.view;
    [AGLKContext setCurrentContext:view.context];
    
    ((GLKView *)self.view).context = nil;
    [EAGLContext setCurrentContext:nil];
    
    _baseEffect = nil;
    cars = nil;
    _carModel = nil;
    _rinkModel = nil;
    
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation!=UIInterfaceOrientationPortraitUpsideDown && toInterfaceOrientation != UIInterfaceOrientationPortrait);
}

-(NSArray *)cars{
    return cars;
}

- (IBAction)swithchmode:(UISwitch *)sender {
    
    self.shouldUseFirstPersonPOV = [sender isOn];
    
    _pointOfViewAnimationCountdown = SceneNumberOfPOVAnimationSeconds;
    
    
}




@end

















