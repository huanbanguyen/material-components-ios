// Copyright 2019-present the Material Components for iOS authors. All Rights Reserved.
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

#import "MDCTextControlStyleOutlined.h"

#include "MaterialAvailability.h"
#import "MDCTextControlLabelBehavior.h"
#import "MDCTextControlState.h"
#import "MDCTextControlVerticalPositioningReferenceOutlined.h"
#import "MDCTextControl.h"
#import "MDCTextControlHorizontalPositioningReference.h"
#import "MDCTextControlLabelSupport.h"
#import "UIBezierPath+MDCTextControlStyle.h"

static const CGFloat kDefaultOutlinedContainerStyleCornerRadius = (CGFloat)4.0;
static const CGFloat kFloatingLabelOutlineSidePadding = (CGFloat)5.0;
static const CGFloat kFilledFloatingLabelScaleFactor = (CGFloat)0.75;

@interface MDCTextControlStyleOutlined ()

@property(strong, nonatomic) CAShapeLayer *outlinedSublayer;
@property(strong, nonatomic) NSMutableDictionary<NSNumber *, UIColor *> *outlineColors;
@property(strong, nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *outlineLineWidths;

@end

@implementation MDCTextControlStyleOutlined

#pragma mark Object Lifecycle

- (instancetype)init {
  self = [super init];
  if (self) {
    [self commonMDCTextControlStyleOutlinedInit];
  }
  return self;
}

#pragma mark Setup

- (void)commonMDCTextControlStyleOutlinedInit {
  self.outlineCornerRadius = kDefaultOutlinedContainerStyleCornerRadius;
  [self setUpOutlineColors];
  [self setUpOutlineLineWidths];
  [self setUpOutlineSublayer];
}

- (void)setUpOutlineColors {
  self.outlineColors = [NSMutableDictionary new];
  UIColor *outlineColor = [UIColor blackColor];
#if MDC_AVAILABLE_SDK_IOS(13_0)
  if (@available(iOS 13.0, *)) {
    outlineColor = [UIColor labelColor];
  }
#endif  // MDC_AVAILABLE_SDK_IOS(13_0)
  self.outlineColors[@(MDCTextControlStateNormal)] = outlineColor;
  self.outlineColors[@(MDCTextControlStateEditing)] = outlineColor;
  self.outlineColors[@(MDCTextControlStateDisabled)] =
      [outlineColor colorWithAlphaComponent:(CGFloat)0.60];
}

- (void)setUpOutlineLineWidths {
  self.outlineLineWidths = [NSMutableDictionary new];
  self.outlineLineWidths[@(MDCTextControlStateNormal)] = @(1);
  self.outlineLineWidths[@(MDCTextControlStateEditing)] = @(2);
  self.outlineLineWidths[@(MDCTextControlStateDisabled)] = @(1);
}

- (void)setUpOutlineSublayer {
  self.outlinedSublayer = [[CAShapeLayer alloc] init];
  self.outlinedSublayer.fillColor = [UIColor clearColor].CGColor;
  self.outlinedSublayer.lineWidth =
      (CGFloat)[self.outlineLineWidths[@(MDCTextControlStateNormal)] doubleValue];
}

#pragma mark Accessors

- (UIColor *)outlineColorForState:(MDCTextControlState)state {
  return self.outlineColors[@(state)];
}

- (void)setOutlineColor:(nonnull UIColor *)outlineColor forState:(MDCTextControlState)state {
  self.outlineColors[@(state)] = outlineColor;
}

#pragma mark MDCTextControlStyle

- (void)applyStyleToTextControl:(UIView<MDCTextControl> *)textControl
              animationDuration:(NSTimeInterval)animationDuration {
  CGRect normalLabelFrame = textControl.normalLabelFrame;
  CGRect floatingLabelFrame = textControl.floatingLabelFrame;
  CGFloat containerHeight = CGRectGetHeight(textControl.containerFrame);
  CGFloat lineWidth = (CGFloat)self.outlineLineWidths[@(textControl.textControlState)].doubleValue;
  UIBezierPath *outlinePath =
      [MDCTextControlStyleOutlined outlinePathWithViewBounds:textControl.bounds
                                            normalLabelFrame:normalLabelFrame
                                          floatingLabelFrame:floatingLabelFrame
                                             containerHeight:containerHeight
                                                   lineWidth:lineWidth
                                                cornerRadius:self.outlineCornerRadius
                                               labelBehavior:textControl.labelBehavior
                                               labelPosition:textControl.labelPosition];
  [self applyOutlineTo:textControl outlinePath:outlinePath outlineLineWidth:lineWidth];
  self.outlinedSublayer.strokeColor =
      ((UIColor *)self.outlineColors[@(textControl.textControlState)]).CGColor;
}

- (UIFont *)floatingFontWithNormalFont:(UIFont *)font {
  CGFloat scaleFactor = kFilledFloatingLabelScaleFactor;
  CGFloat floatingFontSize = font.pointSize * scaleFactor;
  return [font fontWithSize:floatingFontSize];
}

- (void)removeStyleFrom:(id<MDCTextControl>)TextControl {
  [self.outlinedSublayer removeFromSuperlayer];
}

- (id<MDCTextControlVerticalPositioningReference>)
    positioningReferenceWithFloatingFontLineHeight:(CGFloat)floatingLabelHeight
                              normalFontLineHeight:(CGFloat)normalFontLineHeight
                                     textRowHeight:(CGFloat)textRowHeight
                                  numberOfTextRows:(CGFloat)numberOfTextRows
                                           density:(CGFloat)density
                          preferredContainerHeight:(CGFloat)preferredContainerHeight
                            isMultilineTextControl:(BOOL)isMultilineTextControl {
  return [[MDCTextControlVerticalPositioningReferenceOutlined alloc]
      initWithFloatingFontLineHeight:floatingLabelHeight
                normalFontLineHeight:normalFontLineHeight
                       textRowHeight:textRowHeight
                    numberOfTextRows:numberOfTextRows
                             density:density
            preferredContainerHeight:preferredContainerHeight
              isMultilineTextControl:isMultilineTextControl];
}

- (MDCTextControlHorizontalPositioningReference *)horizontalPositioningReference {
  return [[MDCTextControlHorizontalPositioningReference alloc] init];
}

#pragma mark Internal Styling Methods

- (void)applyOutlineTo:(UIView *)view
           outlinePath:(UIBezierPath *)outlinePath
      outlineLineWidth:(CGFloat)outlineLineWidth {
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  self.outlinedSublayer.path = outlinePath.CGPath;
  self.outlinedSublayer.lineWidth = outlineLineWidth;
  [CATransaction commit];

  if (self.outlinedSublayer.superlayer != view.layer) {
    [view.layer insertSublayer:self.outlinedSublayer atIndex:0];
  }
}

+ (UIBezierPath *)outlinePathWithViewBounds:(CGRect)viewBounds
                           normalLabelFrame:(CGRect)normalLabelFrame
                         floatingLabelFrame:(CGRect)floatingLabelFrame
                            containerHeight:(CGFloat)containerHeight
                                  lineWidth:(CGFloat)lineWidth
                               cornerRadius:(CGFloat)radius
                              labelBehavior:(MDCTextControlLabelBehavior)labelBehavior
                              labelPosition:(MDCTextControlLabelPosition)labelPosition {
  UIBezierPath *path = [[UIBezierPath alloc] init];
  CGFloat textFieldWidth = CGRectGetWidth(viewBounds);
  CGFloat halfOfFloatingLabelHeight = CGRectGetHeight(floatingLabelFrame) * 0.5f;
  CGFloat sublayerMinY = halfOfFloatingLabelHeight;
  CGFloat sublayerMaxY = containerHeight;
  if (labelBehavior == MDCTextControlLabelBehaviorDisappears ||
      labelPosition == MDCTextControlLabelPositionNone) {
    sublayerMinY = 0.0f;
  }

  CGPoint startingPoint = CGPointMake(radius, sublayerMinY);
  CGPoint topRightCornerPoint1 = CGPointMake(textFieldWidth - radius, sublayerMinY);
  [path moveToPoint:startingPoint];
  if (labelPosition == MDCTextControlLabelPositionFloating) {
    CGFloat leftLineBreak = CGRectGetMinX(floatingLabelFrame) - kFloatingLabelOutlineSidePadding;
    CGFloat rightLineBreak = CGRectGetMaxX(floatingLabelFrame) + kFloatingLabelOutlineSidePadding;
    [path addLineToPoint:CGPointMake(leftLineBreak, sublayerMinY)];
    [path moveToPoint:CGPointMake(rightLineBreak, sublayerMinY)];
    [path addLineToPoint:CGPointMake(rightLineBreak, sublayerMinY)];
  } else {
    [path addLineToPoint:topRightCornerPoint1];
  }

  CGPoint topRightCornerPoint2 = CGPointMake(textFieldWidth, sublayerMinY + radius);
  [path mdc_addTopRightCornerFromPoint:topRightCornerPoint1
                               toPoint:topRightCornerPoint2
                            withRadius:radius];

  CGPoint bottomRightCornerPoint1 = CGPointMake(textFieldWidth, sublayerMaxY - radius);
  CGPoint bottomRightCornerPoint2 = CGPointMake(textFieldWidth - radius, sublayerMaxY);
  [path addLineToPoint:bottomRightCornerPoint1];
  [path mdc_addBottomRightCornerFromPoint:bottomRightCornerPoint1
                                  toPoint:bottomRightCornerPoint2
                               withRadius:radius];

  CGPoint bottomLeftCornerPoint1 = CGPointMake(radius, sublayerMaxY);
  CGPoint bottomLeftCornerPoint2 = CGPointMake(0, sublayerMaxY - radius);
  [path addLineToPoint:bottomLeftCornerPoint1];
  [path mdc_addBottomLeftCornerFromPoint:bottomLeftCornerPoint1
                                 toPoint:bottomLeftCornerPoint2
                              withRadius:radius];

  CGPoint topLeftCornerPoint1 = CGPointMake(0, sublayerMinY + radius);
  CGPoint topLeftCornerPoint2 = CGPointMake(radius, sublayerMinY);
  [path addLineToPoint:topLeftCornerPoint1];
  [path mdc_addTopLeftCornerFromPoint:topLeftCornerPoint1
                              toPoint:topLeftCornerPoint2
                           withRadius:radius];

  return path;
}

@end
