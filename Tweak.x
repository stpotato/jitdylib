#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <unistd.h>

#define CS_DEBUGGED 0x10000000
int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

BOOL isJITEnabled() {
  unsigned int csflags;
  int result = csops(getpid(), 0, &csflags, sizeof(csflags));
  return (result == 0) ? ((csflags & CS_DEBUGGED) != 0) : NO;
}

@interface WebViewDelegate : NSObject <WKNavigationDelegate>
@property(nonatomic, assign) BOOL didFailLoad;
@end

@implementation WebViewDelegate
- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  self.didFailLoad = YES;
}
@end

void addWebView() {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIWindowScene *scene = 
        (UIWindowScene *)[[UIApplication sharedApplication].connectedScenes allObjects].firstObject;
    
    if (![scene isKindOfClass:[UIWindowScene class]]) return;

    UIWindow *window = scene.windows.firstObject;
    if (!window) return;

    CGFloat height = 80;
    CGFloat margin = 50;

    // html webview
    UIEdgeInsets safeAreaInsets = window.safeAreaInsets;

    NSString *baseHTML =
       @"<html><body><div class=child></div><div class=content><div id=content>%@</div></div>"
       @"<style>*{-webkit-user-select:none;margin:0;padding:0;box-sizing:border-box}"
       @"html,body{width:100vw;height:100vh;display:flex;justify-content:center;align-items:center;"
       @"background:conic-gradient(#a5ab9d 0deg,#2dc0f5 45deg,#9572ed 135deg,#db3a76 225deg,#b06452 315deg,#a5ab9d 360deg)}"
       @".child{backdrop-filter:blur(10px);position:absolute;width:97vw;height:97vh;background:black;filter:blur(35px)}"
       @".content{position:absolute;color:white;font-size:calc(2.275rem + .3vw);font-family:monospace}"
       @"#content{width:75vw;margin-left:3vw}</style>"
       @"<script>let a=0;setInterval(()=>{a+=.9;a>=360&&(a=0);"
       @"document.body.style.background=`conic-gradient(from ${a}deg,#a5ab9d,#2dc0f5 45deg,#9572ed 135deg,#db3a76 225deg,#b06452 315deg,#a5ab9d)`},10);"
       @"document.addEventListener('dblclick',e=>e.preventDefault(),{passive:!1});"
       @"document.addEventListener('touchstart',e=>{if(e.touches.length>1)e.preventDefault()},{passive:!1});</script></body></html>";

    NSString *contentString;

    if (isJITEnabled()) {
      contentString = @"JIT Enabled!";
    } else {
      NSString *appID = [[NSBundle mainBundle] bundleIdentifier];
      contentString = [NSString
          stringWithFormat:
              @"Connecting to JIT server...<script>"
            @"fetch('http://[fd00::]:9172/launch_app/%@')"
            @".then(r=>r.text()).then(d=>{let j=JSON.parse(d);if(j.mount)window.location='http://[fd00::]:9172/mount_status';"
            @"else if(!j.error)document.getElementById('content').innerHTML=`Streaming JIT...<br>You are in position ${j.position}`;"
            @"else document.getElementById('content').innerHTML='Error enabling JIT: '+j.error;})"
            @".catch(e=>document.getElementById('content').innerHTML='Error contacting server: '+e);</script>",
              appID];
    }

    NSString *htmlTemplate =
        [NSString stringWithFormat:baseHTML, contentString];
    NSString *dataURL = [NSString
        stringWithFormat:@"data:text/html;base64,%@",
                         [[htmlTemplate dataUsingEncoding:NSUTF8StringEncoding]
                             base64EncodedStringWithOptions:0]];

    WKWebView *webView = [[WKWebView alloc]
        initWithFrame:CGRectMake(15, safeAreaInsets.top + margin,
                                 window.frame.size.width - 30, height)];
    webView.layer.cornerRadius = 23;
    webView.layer.masksToBounds = YES;
    webView.alpha = 0.45;
    webView.scrollView.scrollEnabled = NO;

    [webView loadRequest:[NSURLRequest
                             requestWithURL:[NSURL URLWithString:dataURL]]];
    [window.rootViewController.view addSubview:webView];

    // blur
    UIBlurEffect *blurEffect =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurEffectView =
        [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurEffectView.frame = webView.frame;
    blurEffectView.layer.cornerRadius = 23;
    blurEffectView.layer.masksToBounds = YES;
    [window.rootViewController.view insertSubview:blurEffectView
                                     belowSubview:webView];

    WebViewDelegate *webDelegate = [[WebViewDelegate alloc] init];
    webView.navigationDelegate = webDelegate;

    if (isJITEnabled()) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                     dispatch_get_main_queue(), ^{
                       [UIView animateWithDuration:0.3
                           animations:^{
                             blurEffectView.alpha = 0;
                             webView.alpha = 0;
                           }
                           completion:^(BOOL finished) {
                             [blurEffectView removeFromSuperview];
                             [webView removeFromSuperview];
                           }];
                     });
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC),
                     dispatch_get_main_queue(), ^{
                       [UIView animateWithDuration:0.3
                           animations:^{
                             blurEffectView.alpha = 0;
                             webView.alpha = 0;
                           }
                           completion:^(BOOL finished) {
                             [blurEffectView removeFromSuperview];
                             [webView removeFromSuperview];
                           }];
                     });
    }
  });
}

%ctor {
  addWebView();
}
