// Copyright 2016-present the Material Components for iOS authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "MDCButtonBar.h"

#import <MDFInternationalization/MDFInternationalization.h>

#import "MaterialAvailability.h"
#import "MDCButtonBarDelegate.h"
#import "MDCAppBarButtonBarBuilder.h"
#import "MaterialButtons.h"
#import "MaterialApplication.h"

static const CGFloat kButtonBarMaxHeight = 56;
static const CGFloat kButtonBarMinHeight = 24;

// KVO contexts
static char *const kKVOContextMDCButtonBar = "kKVOContextMDCButtonBar";

// This is required because @selector(enabled) throws a compiler warning of unrecognized selector.
static NSString *const kEnabledSelector = @"enabled";

@implementation MDCButtonBar {
  id _buttonItemsLock;
  NSArray<UIView *> *_buttonViews;
  UIColor *_inkColor;
  MDCAppBarButtonBarBuilder *_defaultBuilder;
}

- (void)dealloc {
  self.items = nil;
}

- (void)commonMDCButtonBarInit {
  _uppercasesButtonTitles = YES;
  _buttonItemsLock = [[NSObject alloc] init];
  _layoutPosition = MDCButtonBarLayoutPositionNone;

  _defaultBuilder = [[MDCAppBarButtonBarBuilder alloc] init];

#if MDC_AVAILABLE_SDK_IOS(13_0)
  if (@available(iOS 13, *)) {
    // If clients report conflicting gesture recognizers please see proposed solution in the
    // internal document: go/mdc-ios-bottomnavigation-largecontentvieweritem
    [self addInteraction:[[UILargeContentViewerInteraction alloc] initWithDelegate:self]];
  }
#endif  // MDC_AVAILABLE_SDK_IOS(13_0)
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonMDCButtonBarInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    [self commonMDCButtonBarInit];
  }
  return self;
}

- (void)alignButtonBaseline:(UIButton *)button {
  CGRect contentRect = [button contentRectForBounds:button.bounds];
  CGRect titleRect = [button titleRectForContentRect:contentRect];

  // Calculate baseline information based on frame that the title text appears in.
  CGFloat baseline = CGRectGetMaxY(titleRect) + button.titleLabel.font.descender;
  CGFloat buttonBaseline = button.frame.origin.y + baseline;

  // When modifying insets, be sure to add/subtract equal amounts on opposite sides.
  UIEdgeInsets insets = button.titleEdgeInsets;
  CGFloat baselineOffset = _buttonTitleBaseline - buttonBaseline;

  insets.top += baselineOffset;
  insets.bottom -= baselineOffset;
  button.titleEdgeInsets = insets;
}

- (CGSize)sizeThatFits:(CGSize)size shouldLayout:(BOOL)shouldLayout {
  CGFloat totalWidth = 0;

  CGFloat edge;
  switch (self.effectiveUserInterfaceLayoutDirection) {
    case UIUserInterfaceLayoutDirectionLeftToRight:
      edge = 0;
      break;
    case UIUserInterfaceLayoutDirectionRightToLeft:
      edge = size.width;
      break;
  }

  BOOL shouldAlignBaselines = _buttonTitleBaseline > 0;

  NSEnumerator<__kindof UIView *> *positionedButtonViews =
      self.layoutPosition == MDCButtonBarLayoutPositionTrailing
          ? [_buttonViews reverseObjectEnumerator]
          : [_buttonViews objectEnumerator];

  for (UIView *view in positionedButtonViews) {
    CGFloat width = view.frame.size.width;

    // There's a finite number of buttons that can reasonably be shown in a button bar, so this
    // linear-time lookup cost is minimal.
    NSUInteger index = [_buttonViews indexOfObject:view];
    if (index < [_items count]) {
      UIBarButtonItem *item = _items[index];
      if (item.width > 0) {
        width = item.width;
      } else {
        width = [view sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width;
      }
    }

    switch (self.effectiveUserInterfaceLayoutDirection) {
      case UIUserInterfaceLayoutDirectionLeftToRight:
        break;
      case UIUserInterfaceLayoutDirectionRightToLeft:
        edge -= width;
        break;
    }
    if (shouldLayout) {
      view.frame = CGRectMake(edge, 0, width, size.height);

      if (shouldAlignBaselines && [view isKindOfClass:[UIButton class]]) {
        if ([(UIButton *)view titleForState:UIControlStateNormal].length > 0) {
          [self alignButtonBaseline:(UIButton *)view];
        }
      }
    }
    switch (self.effectiveUserInterfaceLayoutDirection) {
      case UIUserInterfaceLayoutDirectionLeftToRight:
        edge += width;
        break;
      case UIUserInterfaceLayoutDirectionRightToLeft:
        break;
    }
    totalWidth += width;
  }

  CGFloat maxHeight = kButtonBarMaxHeight;
  CGFloat minHeight = kButtonBarMinHeight;
  CGFloat height = MIN(MAX(size.height, minHeight), maxHeight);
  return CGSizeMake(totalWidth, height);
}

- (CGSize)sizeThatFits:(CGSize)size {
  return [self sizeThatFits:size shouldLayout:NO];
}

- (CGSize)intrinsicContentSize {
  return [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) shouldLayout:NO];
}

- (void)layoutSubviews {
  [super layoutSubviews];

  [self sizeThatFits:self.bounds.size shouldLayout:YES];
}

- (void)tintColorDidChange {
  [super tintColorDidChange];

  _defaultBuilder.buttonTitleColor = self.tintColor;
  [self updateButtonTitleColors];
}

// If the horizontal size class changes, check if reloading button views is needed since their
// horizontal padding may need to change
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];

  const BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
  if (isPad &&
      self.traitCollection.horizontalSizeClass != previousTraitCollection.horizontalSizeClass) {
    [self reloadButtonViews];
  }

  if (self.traitCollectionDidChangeBlock) {
    self.traitCollectionDidChangeBlock(self, previousTraitCollection);
  }
}

- (void)invalidateIntrinsicContentSize {
  [super invalidateIntrinsicContentSize];

  if ([self.delegate respondsToSelector:@selector(buttonBarDidInvalidateIntrinsicContentSize:)]) {
    [self.delegate buttonBarDidInvalidateIntrinsicContentSize:self];
  }
}

#pragma mark - Private

- (void)updateButtonTitleColors {
  for (NSUInteger i = 0; i < [_buttonViews count]; ++i) {
    UIView *viewObj = _buttonViews[i];
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *button = (MDCButton *)viewObj;

      if (i >= [_items count]) {
        continue;
      }
      UIBarButtonItem *item = _items[i];
      [_defaultBuilder updateTitleColorForButton:button withItem:item];
    }
  }
}

- (void)updateButtonsWithInkColor:(UIColor *)inkColor {
  for (UIView *viewObj in _buttonViews) {
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *buttonView = (MDCButton *)viewObj;
      buttonView.inkColor = inkColor;
    }
  }
}

- (NSArray<UIView *> *)viewsForItems:(NSArray<UIBarButtonItem *> *)barButtonItems {
  if (![barButtonItems count]) {
    return nil;
  }

  NSMutableArray<UIView *> *views = [NSMutableArray array];
  [barButtonItems
      enumerateObjectsUsingBlock:^(UIBarButtonItem *item, NSUInteger idx, __unused BOOL *stop) {
        MDCBarButtonItemLayoutHints hints = MDCBarButtonItemLayoutHintsNone;
        if (idx == 0) {
          hints |= MDCBarButtonItemLayoutHintsIsFirstButton;
        }
        if (idx == [barButtonItems count] - 1) {
          hints |= MDCBarButtonItemLayoutHintsIsLastButton;
        }
        UIView *view = [self->_defaultBuilder buttonBar:self viewForItem:item layoutHints:hints];
        if (!view) {
          return;
        }

        [view sizeToFit];
        if (item.width > 0) {
          CGRect frame = view.frame;
          frame.size.width = item.width;
          view.frame = frame;
        }

        [self addSubview:view];
        [views addObject:view];
      }];
  return views;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kKVOContextMDCButtonBar) {
    void (^mainThreadWork)(void) = ^{
      @synchronized(self->_buttonItemsLock) {
        NSUInteger itemIndex = [self.items indexOfObject:object];
        if (itemIndex == NSNotFound || itemIndex > [self->_buttonViews count]) {
          return;
        }
        UIView *buttonView = self->_buttonViews[itemIndex];

        id newValue = [object valueForKey:keyPath];
        if (newValue == [NSNull null]) {
          newValue = nil;
        }

        if ([keyPath isEqualToString:kEnabledSelector]) {
          if ([buttonView respondsToSelector:@selector(setEnabled:)]) {
            [buttonView setValue:newValue forKey:keyPath];
          }

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(accessibilityHint))]) {
          buttonView.accessibilityHint = newValue;

        } else if ([keyPath
                       isEqualToString:NSStringFromSelector(@selector(accessibilityIdentifier))]) {
          buttonView.accessibilityIdentifier = newValue;

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(accessibilityLabel))]) {
          buttonView.accessibilityLabel = newValue;

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(accessibilityValue))]) {
          buttonView.accessibilityValue = newValue;

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(image))]) {
          if ([buttonView isKindOfClass:[UIButton class]]) {
            [((UIButton *)buttonView) setImage:newValue forState:UIControlStateNormal];
            [self invalidateIntrinsicContentSize];
          }

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(tag))]) {
          buttonView.tag = [newValue integerValue];

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(tintColor))]) {
          buttonView.tintColor = newValue;
          if ([buttonView isKindOfClass:[UIButton class]]) {
            [self->_defaultBuilder updateTitleColorForButton:((UIButton *)buttonView)
                                                    withItem:object];
          }

        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(title))]) {
          if ([buttonView isKindOfClass:[UIButton class]]) {
            [((UIButton *)buttonView) setTitle:newValue forState:UIControlStateNormal];
            [self invalidateIntrinsicContentSize];
          }

        }
#if MDC_AVAILABLE_SDK_IOS(14_0)
        else if ([keyPath isEqualToString:NSStringFromSelector(@selector(menu))]) {
          if (@available(iOS 14.0, *)) {
            if ([buttonView isKindOfClass:[UIButton class]]) {
              ((UIButton *)buttonView).menu = newValue;
              if (!self.items[itemIndex].primaryAction) {
                ((UIButton *)buttonView).showsMenuAsPrimaryAction = YES;
              }
            }
          }
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(primaryAction))]) {
          if (@available(iOS 14.0, *)) {
            // As of iOS 14.0 there is no public API to change the primary action of a button.
            // It's only possible to provide the action upon initialization of the view, so all
            // views get reloaded.
            [self reloadButtonViews];
          }
        }
#endif
#if MDC_AVAILABLE_SDK_IOS(13_0)
        else if ([keyPath isEqualToString:NSStringFromSelector(@selector(largeContentSizeImage))]) {
          if (@available(iOS 13.0, *)) {
            buttonView.largeContentImage = newValue;
          }
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector
                                                                 (largeContentSizeImageInsets))]) {
          if (@available(iOS 13.0, *)) {
            buttonView.largeContentImageInsets = [newValue UIEdgeInsetsValue];
          }
        }
#endif  // MDC_AVAILABLE_SDK_IOS(13_0)
        else {
          NSLog(@"Unknown key path notification received by %@ for %@.",
                NSStringFromClass([self class]), keyPath);
        }
      }
    };

    // Ensure that UIKit modifications occur on the main thread.
    if ([NSThread isMainThread]) {
      mainThreadWork();
    } else {
      [[NSOperationQueue mainQueue] addOperationWithBlock:mainThreadWork];
    }

  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - Button target selector

- (void)didTapButton:(UIButton *)button event:(UIEvent *)event {
  NSUInteger buttonIndex = [_buttonViews indexOfObject:button];
  if (buttonIndex == NSNotFound || buttonIndex > [self.buttonItems count]) {
    return;
  }

  UIBarButtonItem *item = self.buttonItems[buttonIndex];

  if (item.action == nil) {
    return;
  }

  id target = item.target;

  // As per Apple's documentation on UIBarButtonItem:
  // https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIBarButtonItem_Class/#//apple_ref/occ/instp/UIBarButtonItem/action
  // "If nil, the action message is passed up the responder chain where it may be handled by any
  // object implementing a method corresponding to the selector held by the action property."
  if (target == nil) {
    target = [self targetForAction:item.action withSender:self];
  }

  // If we ultimately couldn't find a target, bail out.
  if (!target) {
    return;
  }

  if (![target respondsToSelector:item.action]) {
    return;
  }

  if (![target respondsToSelector:@selector(methodSignatureForSelector:)]) {
    UIApplication *application = [UIApplication mdc_safeSharedApplication];
    NSAssert(application != nil,
             @"No UIApplication is available to send an event from; it will be lost.");
    [application sendAction:item.action to:target from:item forEvent:event];
    return;
  }

  NSMethodSignature *signature = [target methodSignatureForSelector:item.action];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
  invocation.selector = item.action;

  if ([invocation.methodSignature numberOfArguments] > 2) {
    [invocation setArgument:&item atIndex:2];
  }
  if ([invocation.methodSignature numberOfArguments] > 3) {
    [invocation setArgument:&event atIndex:3];
  }

  // UIKit methods that present from a UIBarButtonItem will not work with our items because we
  // can't set the necessary private ivars that associate the item with the button. So we pass the
  // button as well so that clients can present from the button's frame instead.
  // This is not part of the standard UIKit method signature.
  if ([invocation.methodSignature numberOfArguments] > 4) {
    [invocation setArgument:&button atIndex:4];
  }

  [invocation invokeWithTarget:target];
}

#pragma mark - Public

- (NSArray<UIBarButtonItem *> *)buttonItems {
  return self.items;
}

- (void)setButtonItems:(NSArray<UIBarButtonItem *> *)buttonItems {
  self.items = buttonItems;
}

- (void)setItems:(NSArray<UIBarButtonItem *> *)items {
  @synchronized(_buttonItemsLock) {
    if (_items == items || [_items isEqualToArray:items]) {
      return;
    }

    NSArray<NSString *> *keyPaths = @[
      NSStringFromSelector(@selector(accessibilityHint)),
      NSStringFromSelector(@selector(accessibilityIdentifier)),
      NSStringFromSelector(@selector(accessibilityLabel)),
      NSStringFromSelector(@selector(accessibilityValue)), kEnabledSelector,
      NSStringFromSelector(@selector(image)), NSStringFromSelector(@selector(tag)),
      NSStringFromSelector(@selector(tintColor)), NSStringFromSelector(@selector(title)),
      NSStringFromSelector(@selector(largeContentSizeImage)),
      NSStringFromSelector(@selector(largeContentSizeImageInsets))
    ];
#if MDC_AVAILABLE_SDK_IOS(14_0)
    if (@available(iOS 14.0, *)) {
      NSMutableArray<NSString *> *mutableKeyPaths = [keyPaths mutableCopy];
      [mutableKeyPaths addObject:NSStringFromSelector(@selector(menu))];
      [mutableKeyPaths addObject:NSStringFromSelector(@selector(primaryAction))];
      keyPaths = mutableKeyPaths;
    }
#endif

    // Remove old observers
    for (UIBarButtonItem *item in _items) {
      for (NSString *keyPath in keyPaths) {
        [item removeObserver:self forKeyPath:keyPath context:kKVOContextMDCButtonBar];
      }
    }

    _items = [items copy];

    // Register new observers
    for (UIBarButtonItem *item in _items) {
      for (NSString *keyPath in keyPaths) {
        [item addObserver:self
               forKeyPath:keyPath
                  options:NSKeyValueObservingOptionNew
                  context:kKVOContextMDCButtonBar];
      }
    }

    [self reloadButtonViews];
  }
}

- (CGRect)rectForItem:(nonnull UIBarButtonItem *)item
    inCoordinateSpace:(nonnull id<UICoordinateSpace>)coordinateSpace {
  NSUInteger itemIndex = [self.items indexOfObject:item];
  UIView *buttonView = _buttonViews[itemIndex];
  return [buttonView convertRect:buttonView.bounds toCoordinateSpace:coordinateSpace];
}

- (void)setUppercasesButtonTitles:(BOOL)uppercasesButtonTitles {
  _uppercasesButtonTitles = uppercasesButtonTitles;

  for (NSUInteger i = 0; i < [_buttonViews count]; ++i) {
    UIView *viewObj = _buttonViews[i];
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *button = (MDCButton *)viewObj;
      button.uppercaseTitle = uppercasesButtonTitles;
    }
  }
}

- (void)setButtonsTitleFont:(UIFont *)font forState:(UIControlState)state {
  [_defaultBuilder setTitleFont:font forState:state];

  for (NSUInteger i = 0; i < [_buttonViews count]; ++i) {
    UIView *viewObj = _buttonViews[i];
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *button = (MDCButton *)viewObj;
      [button setTitleFont:font forState:state];

      if (i < [_items count]) {
        UIBarButtonItem *item = _items[i];

        CGRect frame = button.frame;
        if (item.width > 0) {
          frame.size.width = item.width;
        } else {
          frame.size.width = [button sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width;
        }
        button.frame = frame;

        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout];
      }
    }
  }
}

- (nullable UIFont *)buttonsTitleFontForState:(UIControlState)state {
  return [_defaultBuilder titleFontForState:state];
}

- (void)setButtonsTitleColor:(nullable UIColor *)color forState:(UIControlState)state {
  [_defaultBuilder setTitleColor:color forState:state];

  for (UIView *viewObj in _buttonViews) {
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *button = (MDCButton *)viewObj;
      [button setTitleColor:color forState:state];
    }
  }
}

- (UIColor *)buttonsTitleColorForState:(UIControlState)state {
  return [_defaultBuilder titleColorForState:state];
}

// UISemanticContentAttribute was added in iOS SDK 9.0 but is available on devices running earlier
// version of iOS. We ignore the partial-availability warning that gets thrown on our use of this
// symbol.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
- (void)mdf_setSemanticContentAttribute:(UISemanticContentAttribute)semanticContentAttribute {
  [super mdf_setSemanticContentAttribute:semanticContentAttribute];
  [self reloadButtonViews];
}
#pragma clang diagnostic pop

- (void)setButtonTitleBaseline:(CGFloat)buttonTitleBaseline {
  _buttonTitleBaseline = buttonTitleBaseline;

  [self setNeedsLayout];
}

- (UIColor *)inkColor {
  return _inkColor;
}

- (void)setInkColor:(UIColor *)inkColor {
  if (_inkColor == inkColor) {
    return;
  }
  _inkColor = inkColor;
  [self updateButtonsWithInkColor:_inkColor];
}

- (void)setRippleColor:(UIColor *)rippleColor {
  if (_rippleColor == rippleColor || [_rippleColor isEqual:rippleColor]) {
    return;
  }
  _rippleColor = rippleColor;
  [self updateButtonsWithInkColor:_rippleColor];
}

- (void)setEnableRippleBehavior:(BOOL)enableRippleBehavior {
  if (_enableRippleBehavior == enableRippleBehavior) {
    return;
  }
  _enableRippleBehavior = enableRippleBehavior;

  for (UIView *viewObj in _buttonViews) {
    if ([viewObj isKindOfClass:[MDCButton class]]) {
      MDCButton *buttonView = (MDCButton *)viewObj;
      buttonView.enableRippleBehavior = enableRippleBehavior;
    }
  }
}

- (void)reloadButtonViews {
  // TODO(featherless): Recycle buttons.
  for (UIView *view in _buttonViews) {
    [view removeFromSuperview];
  }
  _buttonViews = [self viewsForItems:_items];

  [self invalidateIntrinsicContentSize];
  [self setNeedsLayout];
}

#ifdef __IPHONE_13_4
- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction
                        styleForRegion:(UIPointerRegion *)region API_AVAILABLE(ios(13.4)) {
  UIPointerStyle *pointerStyle = nil;
  if (interaction.view) {
    UITargetedPreview *targetedPreview = [[UITargetedPreview alloc] initWithView:interaction.view];
    UIPointerEffect *highlightEffect = [UIPointerHighlightEffect effectWithPreview:targetedPreview];
    pointerStyle = [UIPointerStyle styleWithEffect:highlightEffect shape:nil];
  }
  return pointerStyle;
}
#endif

#pragma mark - UILargeContentViewerInteractionDelegate

/**
 Returns the item view at the given point. Nil if there is no view at the given point.

 point is assumed to be in the coordinate space of the button bar's bounds.
 */
- (UIView *)buttonItemForPoint:(CGPoint)point {
  for (NSUInteger i = 0; i < self.items.count; i++) {
    UIBarButtonItem *barButtonItem = self.items[i];
    UIView *buttonView = _buttonViews[i];
    CGRect rect = [self rectForItem:barButtonItem inCoordinateSpace:self];
    if (CGRectContainsPoint(rect, point)) {
      return buttonView;
    }
  }
  return nil;
}

#if MDC_AVAILABLE_SDK_IOS(13_0)
- (id<UILargeContentViewerItem>)largeContentViewerInteraction:
                                    (UILargeContentViewerInteraction *)interaction
                                                  itemAtPoint:(CGPoint)point
    NS_AVAILABLE_IOS(13_0) {
  if (!CGRectContainsPoint(self.bounds, point)) {
    // The touch has wandered outside of the view. Do not display the content viewer.
    return nil;
  }

  return [self buttonItemForPoint:point];
}
#endif  // MDC_AVAILABLE_SDK_IOS(13_0)

@end
