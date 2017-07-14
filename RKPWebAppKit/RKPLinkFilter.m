//------------------------------------------------------------------------------
//
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

#import "RKPLinkFilter.h"

static NSArray<NSString *> *s_allowedHosts;
static NSArray<NSString *> *s_launchInNewWindowHosts;

@implementation RKPLinkFilter

+ (void)setAllowedHosts:(NSArray<NSString *> *)allowedHosts
{
    s_allowedHosts = [allowedHosts copy];
}

+ (BOOL)isAllowedURL:(NSString *)host
{
    __block BOOL ret = NO;
    [s_allowedHosts enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isEqualToString:host])
        {
            ret = YES;
            *stop = YES;
        }
        
        if ([host hasSuffix:obj])
        {
            ret = YES;
            *stop =YES;
        }
    }];
    
    return ret;
}

+ (BOOL)opensInNewWindow:(NSURL *)url
{
    return NO;
}

@end
