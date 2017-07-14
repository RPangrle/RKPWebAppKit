//------------------------------------------------------------------------------
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <WebKit/WebKit.h>
#import "NSView+RKPLayoutConstraints.h"

#import "RKPWebViewController.h"

#import "RKPLinkFilter.h"
#import "RKPPageWindowController.h"

@interface RKPPageWindowJSLogger : NSObject <WKScriptMessageHandler>

@end

@implementation RKPPageWindowJSLogger

+ (instancetype)sharedLogger
{
    static RKPPageWindowJSLogger *s_logger;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        s_logger = [RKPPageWindowJSLogger new];
    });
    
    return s_logger;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSLog(@"%@", message.body);
}

@end

@interface RKPWebViewController () <WKNavigationDelegate, WKScriptMessageHandler>

@end

@implementation RKPWebViewController
{
    NSURL *_startURL;
    NSProgressIndicator *_spinner;
    
    NSString *_pageSummary;
}

+ (NSString *)onLoadJS
{
    static NSString *s_onLoadJs = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        NSString *onLoadPath = [[NSBundle bundleForClass:self] pathForResource:@"onload" ofType:@"js"];
        
        s_onLoadJs = [NSString stringWithContentsOfFile:onLoadPath encoding:NSUTF8StringEncoding error:nil];
    });
    
    return s_onLoadJs;
}

- (id)initWithURL:(NSURL *)url
            frame:(NSRect)frame
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
    _spinner.hidden = YES;
    _spinner.style = NSProgressIndicatorSpinningStyle;
    _spinner.translatesAutoresizingMaskIntoConstraints = NO;
    
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    [self injectJSBridge:configuration];
    [configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
    
    _webView = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
    _webView.navigationDelegate = self;
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSView *overView = [[NSView alloc] initWithFrame:frame];
    overView.translatesAutoresizingMaskIntoConstraints = NO;
    [overView addSubview:_webView];
    [overView addEqualConstraint:NSLayoutAttributeWidth withItem:_webView];
    [overView addEqualConstraint:NSLayoutAttributeHeight withItem:_webView];
    [overView addEqualConstraint:NSLayoutAttributeCenterX withItem:_webView];
    [overView addEqualConstraint:NSLayoutAttributeCenterY withItem:_webView];
    
    [overView addSubview:_spinner];
    [overView addEqualConstraint:NSLayoutAttributeCenterX withItem:_spinner];
    [overView addEqualConstraint:NSLayoutAttributeCenterY withItem:_spinner];
    
    _pageSummary = url.path;
    _startURL = url;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request];
    
    self.view = overView;
    
    return self;
}

- (BOOL)handleLink:(NSURL *)url
{
    NSString *host = url.host;
    if ([host isEqual:_startURL.host] && [url.path isEqualToString:_startURL.path])
    {
        return YES;
    }
    
    if(![RKPLinkFilter isAllowedURL:host])
    {
        LSOpenCFURLRef((__bridge CFURLRef)url, NULL);
        return NO;
    }
    
    if ([RKPLinkFilter opensInNewWindow:url])
    {
        NSLog(@"[%@] Launching %@ in new window", _pageSummary, url);
        [RKPPageWindowController openWithURL:url];
        return NO;
    }
    
    return YES;
}

- (void)injectJSBridge:(WKWebViewConfiguration *)configuration
{
    [configuration.userContentController addScriptMessageHandler:self name:@"linkIntercept"];
    [configuration.userContentController addScriptMessageHandler:[RKPPageWindowJSLogger sharedLogger] name:@"logMessage"];
    
    WKUserScript *onloadScript = [[WKUserScript alloc] initWithSource:[RKPWebViewController onLoadJS] injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [configuration.userContentController addUserScript:onloadScript];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *requestURL = navigationAction.request.URL;
    BOOL handled = [self handleLink:requestURL];
    NSLog(@"[%@] %@ %@", _pageSummary, requestURL, handled ? @"allowed" : @"cancelled");
    decisionHandler(handled ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    _spinner.hidden = NO;
    NSLog(@"[%@] started navigation", _pageSummary);
    [_spinner startAnimation:self];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    // TODO error reporting?
    
    NSLog(@"webview failed to navigate with error: %@", error);
    
    _spinner.hidden = YES;
    [_spinner stopAnimation:self];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    _spinner.hidden = YES;
    [_spinner stopAnimation:self];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    (void)userContentController;
    (void)message;
    
    if ([message.name isEqualToString:@"linkIntercept"])
    {
        NSURL *url = [NSURL URLWithString:message.body];
        if (!url)
            return;
        
        BOOL linkHandled = [self handleLink:url];
        NSLog(@"[%@] %@ %@", _pageSummary, url, linkHandled ? @"reject" : @"resolve");
        [_webView evaluateJavaScript:linkHandled ? @"this.waiting_promise.reject()" : @"this.waiting_promise.resolve()"
                   completionHandler:^(id _Nullable result, NSError * _Nullable error)
         {
             // completion handler
             if (error)
             {
                 NSLog(@"error in link handler js: %@", error);
             }
         }];
    }
}

@end
