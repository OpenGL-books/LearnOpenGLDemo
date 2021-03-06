//
//  bigSizeImageView.m
//  EX_appIOS
//
//  Created by mac_w on 2016/11/8.
//  Copyright © 2016年 aee. All rights reserved.
//

#import "bigSizeImageView.h"
#import <AVFoundation/AVFoundation.h>
#import "UIImage+WaterMark.h"
#import "KondonPhotoModel.h"
#import "UIImageView+VideoFirstImage.h"
#import "AppDelegate.h"
//#import <>

@interface bigSizeImageView ()

@end

@implementation bigSizeImageView

-(instancetype)initWithFrame:(CGRect)frame
{
    self=[super initWithFrame:frame];
    
    _tipsLabel=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, ScreenW, 44)];
    _tipsLabel.font=[UIFont systemFontOfSize:20];
    _tipsLabel.textColor=[UIColor whiteColor];
    _tipsLabel.textAlignment=NSTextAlignmentCenter;
    _tipsLabel.backgroundColor=[UIColor lightGrayColor];
    
    [self addSubview:_tipsLabel];
    
    _bigImage=[[UIImageView alloc]initWithFrame:CGRectMake(0,44*2, ScreenW, ScreenW*(432*1.00/768))];
    
    _bigImage.userInteractionEnabled=YES;
    
    [self addSubview:_bigImage];
    _bottonScrollerView=[[BottonScrollView alloc]initWithFrame:CGRectMake(0, frame.size.height-80, ScreenW, 80)];
    
    [self addSubview:_bottonScrollerView];
    _bottonScrollerView.userInteractionEnabled=YES;
    _bottonScrollerView.scrollEnabled=YES;
    _bottonScrollerView.showsHorizontalScrollIndicator=NO;
    _bottonScrollerView.showsVerticalScrollIndicator=NO;
    
    return self;
}

-(void)setSelectedmodel:(KondonPhotoModel *)selectedmodel
{
    _selectedmodel=selectedmodel;
    [self removePlayerLayer];
    if (selectedmodel.isVideo==YES) {
//        UIImage *logoimg=[UIImage imageNamed:@"EX_App_MAIN MENU_LOGO"];
        UIImage *img = [UIImage OriginImage:[UIImage imageNamed:@"Viewer_Logo"] scaleToSize:CGSizeMake(ScreenW, ScreenW*(432*1.00/768)) withLogoImage:[UIImage imageNamed:@"play"] scale:6];
      
        [_bigImage setCurrentImage:img withURL:selectedmodel.pathUrl withQueue:self.bigImagequeue withSize:CGSizeMake(ScreenW, ScreenW*(432*1.00/768)) withScale:6];
        [_bigImage addSubview:self.playButton];
        
    }else{
        [self.playButton removeFromSuperview];
        if ([selectedmodel.pathUrl.description hasPrefix:@"http"]) {
            
            [_bigImage sd_setImageWithURL:selectedmodel.pathUrl placeholderImage:[UIImage imageNamed:@"Viewer_Logo"]];
        }else{
            UIImage *img=[UIImage imageWithContentsOfFile:selectedmodel.pathUrl.description];
            _bigImage.image=img;
        }
        
    }

    
    
}


//如果是一个视频就可以点击播放
- (void)playVideos{
        _bigImage.image=nil;
    KondonPhotoModel *model=_selectedmodel;
//    NSString *path=model.pathUrl.description;
//    NSArray *desArr=[path componentsSeparatedByString:@"///"];
//    NSString *path0=desArr.lastObject;
//    NSURL *fileURL=[NSURL fileURLWithPath:path0];
//    NSLog(@"%@-------%@3333333",model.pathUrl.description,fileURL.description);
//
        _movieplayer=[[KondorMoviePlayerController alloc]initWithContentURL:model.pathUrl];
        
        
        _movieplayer.movieSourceType = MPMovieSourceTypeFile;
        //    _movieplayer.movieSourceType = MPMovieSourceTypeFile;// 播放本地视频时需要这句
        //    self.player.controlStyle = MPMovieControlStyleNone;// 不需要进度条
        _movieplayer.shouldAutoplay = YES;
        _movieplayer.controlStyle = MPMovieControlStyleDefault;
        _movieplayer.scalingMode = MPMovieScalingModeAspectFill;
        [_movieplayer prepareToPlay];
        _movieplayer.view.frame=_bigImage.bounds;
        
        [self.bigImage addSubview:_movieplayer.view];

        [_movieplayer play];
    
        [_movieplayer setFullscreen:YES animated:YES];
//    [self removePlayerLayer];
//    self.player=[[AVPlayer alloc]initWithURL:model.pathUrl];
//    self.playerlayer=[AVPlayerLayer playerLayerWithPlayer:self.player];
//    self.playerlayer.frame=CGRectMake(0, 0, _bigImage.bounds.size.width, _bigImage.bounds.size.height);
//    
//    [_bigImage.layer addSublayer:_playerlayer];
//    
//    [_player play];
}
-(void)removePlayerLayer{
    [self.movieplayer pause];
    [self.movieplayer.view removeFromSuperview];
    
    
    
    self.movieplayer=nil;
    
//    [_player pause];
//    [_playerlayer removeFromSuperlayer];
//    _player=nil;
//    _playerlayer=nil;
    
}
-(void)loadValuesAsynchronouslyForKeys:(NSArray *)keys completionHandler:(void (^)(void))handler
{
    NSLog(@"chucuole````````");
}

-(NSMutableArray *)imgArr
{
    if (_imgArr==nil) {
        _imgArr=[NSMutableArray array];
    }
    return _imgArr;
}

-(NSMutableArray *)scaledImgArr
{
    if (_scaledImgArr==nil) {
        _scaledImgArr=[NSMutableArray array];
    }
    return _scaledImgArr;
}

-(UIButton *)playButton
{
    if (_playButton==nil) {
        _playButton=[[UIButton alloc]init];
        _playButton.frame=CGRectMake((_bigImage.bounds.size.width-100)*0.5, (_bigImage.bounds.size.height-100)*0.5, 100, 100);
//        [_playButton setImage:ImgNamed(@"play") forState:UIControlStateNormal];
        [_playButton addTarget:self action:@selector(playVideos) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playButton;
}
//-(AVPlayerLayer *)playerlayer
//{
//    if (_playerlayer==nil) {360430196409010319    360430196408260324
//        _playerlayer=[[AVPlayerLayer alloc]init];
//        _playerlayer=[AVPlayerLayer playerLayerWithPlayer:self.player];
//        _playerlayer.frame=CGRectMake(0, 0, _bigImage.bounds.size.width, _bigImage.bounds.size.height);
//    }
//    
//    return _playerlayer;
//}
//-(AVPlayer *)player{
//    
//    if (_player==nil) {
//        
//        _player=[[AVPlayer alloc]initWithURL:model.pathUrl];
//    }
//    return _player;
//}



@end
