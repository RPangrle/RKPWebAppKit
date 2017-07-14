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

#import "RKPPageWindowController.h"

#import "RKPLinkFilter.h"
#import "RKPWebViewController.h"

#import "NSView+RKPLayoutConstraints.h"

@interface RKPPageWindowController () <NSWindowDelegate>

@end

static NSMutableDictionary *s_windows = nil;

@implementation RKPPageWindowController
{
    RKPWebViewController *_webController;
    
    NSURL *_startURL;
    
    NSString *_pageSummary;
}

static NSMutableDictionary<NSString *, NSString *>* DictionaryFromQIs(NSArray<NSURLQueryItem *> *QIs)
{
    if (!QIs || QIs.count == 0)
    {
        return [NSMutableDictionary new];
    }
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    
    for (NSURLQueryItem* QI in QIs)
    {
        dictionary[QI.name] = QI.value;
    }
    
    return dictionary;
}

+ (NSDictionary<NSString *, NSString *> *)ensureQPs
{
    return nil;
}

+ (NSString *)keyForURL:(NSURL *)url
{
    return [NSString stringWithFormat:@"%@/%@", url.host, url.path];
}

+ (NSDictionary *)currentWindows
{
    return s_windows;
}

+ (void)openWithURL:(NSURL *)url
{
    NSString *baseUrlStr = [self keyForURL:url];
    RKPPageWindowController *controller = [s_windows objectForKey:baseUrlStr];
    if (controller)
    {
        [[controller window] makeKeyAndOrderFront:nil];
        return;
    }
    
    RKPPageWindowController *window = [[self alloc] initWithURL:url];
    [window showWindow:nil];
}

+ (void)initialize
{
    s_windows = [NSMutableDictionary new];
    
}

#define WI_HEIGHT 900
#define WI_WIDTH 750

#define DEFAULT_HEIGHT 800
#define DEFAULT_WIDTH 1600

#define BOARD_WIDTH 1600

#define CASCADE_OFFSET 25

+ (NSRect)frameForURL:(NSURL *)url
{
    NSRect sf = [[NSScreen mainScreen] frame];
    
    CGFloat width = DEFAULT_WIDTH;
    CGFloat height = DEFAULT_HEIGHT;
    
    CGFloat x_offset = 10;
    CGFloat y_offset = 50;
    
    CGFloat cCascade = s_windows.count;
    
    return NSMakeRect(x_offset + (cCascade * CASCADE_OFFSET), sf.size.height - height - (cCascade * CASCADE_OFFSET) - y_offset, width, height);
}

- (id)initWithURL:(NSURL *)startURL
{
    if (!startURL)
    {
        return nil;
    }
    
    NSWindow *window =
    [[NSWindow alloc] initWithContentRect:[[self class] frameForURL:startURL]
                                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |NSWindowStyleMaskResizable
                                  backing:NSBackingStoreBuffered
                                    defer:NO];
    
    if (!(self = [super initWithWindow:window]))
    {
        return nil;
    }
    
    _pageSummary = startURL.path;
    window.title = _pageSummary;
    
    NSDictionary *ensureQPs = [[self class] ensureQPs];
    if (ensureQPs)
    {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:startURL resolvingAgainstBaseURL:NO];
        NSMutableDictionary *QIs = DictionaryFromQIs(urlComponents.queryItems);
        
        bool replaceQIs = false;
        for (NSString *key in ensureQPs)
        {
            id val = ensureQPs[key];
            if (![QIs doesContain:key] || ![QIs[key] isNotEqualTo:val])
            {
                replaceQIs = true;
                QIs[key] = val;
            }
        }
        
        if (replaceQIs)
        {
            NSMutableArray<NSURLQueryItem *> *qiArray = [NSMutableArray new];
            for (NSString *key in QIs)
            {
                [qiArray addObject:[NSURLQueryItem queryItemWithName:key value:QIs[key]]];
            }
            
            urlComponents.queryItems = qiArray;
            startURL = urlComponents.URL;
        }
    }
    
    _startURL = startURL;
    
    _webController = [[RKPWebViewController alloc] initWithURL:startURL
                                                         frame:window.frame];
    window.contentViewController = _webController;
    
    NSString *pageKey = [NSString stringWithFormat:@"%@/%@", startURL.host, startURL.path];
    [s_windows setObject:self forKey:pageKey];
    
    [_webController.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    (void)keyPath;
    (void)object;
    (void)change;
    (void)context;
    
    [self updateTitle:_webController.webView.title];
}

- (void)updateTitle:(NSString *)title
{
    self.window.title = title;
}

- (void)windowWillClose:(NSNotification *)notification
{
    [s_windows removeObjectForKey:[[self class] keyForURL:_startURL]];
}

- (IBAction)copyURL:(id)sender
{
    NSURL *currentURL = _webController.webView.URL;
    if (!currentURL)
        return;
    
    [[NSPasteboard generalPasteboard] writeObjects:@[currentURL]];
}

@end
