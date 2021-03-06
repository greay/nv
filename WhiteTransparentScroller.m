//
//  WhiteTransparentScroller.m
//
//  Created by Brett Terpstra on 12/8/10.
//  Copyright 2010 Circle Six Design. All rights reserved.
//

#import "WhiteTransparentScroller.h"

// Vertical scroller
static NSImage *knobTop, *knobVerticalFill, *knobBottom, *slotTop, *slotVerticalFill, *slotBottom;
static float verticalPaddingLeft = 2.0;
static float verticalPaddingRight = 2.0;
static float verticalPaddingTop = 8.0;
static float verticalPaddingBottom = 8.0;
static float minKnobHeight;

// Horizontal scroller
static NSImage *knobLeft, *knobHorizontalFill, *knobRight, *slotLeft, *slotHorizontalFill, *slotRight;
static float horizontalPaddingLeft = 2.0;
static float horizontalPaddingRight = 2.0;
static float horizontalPaddingTop = 0.0;
static float horizontalPaddingBottom = 1.0;
static float minKnobWidth;

static NSColor *backgroundColor;

@interface BTTransparentScroller (BWTSPrivate)
- (void)drawKnobSlot;
@end

@interface NSScroller (BWTSPrivate)
- (NSRect)_drawingRectForPart:(NSScrollerPart)aPart;
@end

@implementation WhiteTransparentScroller

+ (void)initialize
{
	NSBundle *bundle = [NSBundle mainBundle];
	
	// Vertical scroller
	knobTop				= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"greyscrollerverttop2.tiff"]];
	knobVerticalFill	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"greyscrollervertfill2.tiff"]];
	knobBottom			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"greyscrollervertbottom2.tiff"]];
	slotTop				= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerSlotTop.tif"]];
	slotVerticalFill	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"scrollbarblue.tif"]];
	slotBottom			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerSlotBottom.tif"]];
	
	// Horizontal scroller
	knobLeft			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerKnobLeft.tif"]];
	knobHorizontalFill	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerKnobHorizontalFill.tif"]];
	knobRight			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerKnobRight.tif"]];
	slotLeft			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerSlotLeft.tif"]];
	slotHorizontalFill	= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerSlotHorizontalFill.tif"]];
	slotRight			= [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"BTransparentScrollerSlotRight.tif"]];
	
	backgroundColor		= [[NSColor colorWithCalibratedWhite:1.000 alpha:1.000] retain];
	minKnobHeight = knobTop.size.height + knobVerticalFill.size.height + knobBottom.size.height + 40;
	minKnobWidth = knobLeft.size.width + knobHorizontalFill.size.width + knobRight.size.width + 10;
}

- (void)setBackgroundColor:(NSColor*)bgcolor;
{
	[backgroundColor release];
	backgroundColor = [bgcolor retain];
}

- (id)initWithFrame:(NSRect)frameRect;
{
	if ((self = [super initWithFrame:frameRect]))
	{
		[self setArrowsPosition:NSScrollerArrowsNone];
		
		if ([self bounds].size.width / [self bounds].size.height < 1)
			isVertical = YES;
		else
			isVertical = NO;
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder;
{
	if ((self = [super initWithCoder:decoder]))
	{
		[self setArrowsPosition:NSScrollerArrowsNone];	
		
		if ([self bounds].size.width / [self bounds].size.height < 1)
			isVertical = YES;
		else
			isVertical = NO;
	}
	
	return self;
}

+ (CGFloat)scrollerWidth
{
	return slotVerticalFill.size.width + verticalPaddingLeft + verticalPaddingRight;
}

+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize 
{
	return slotVerticalFill.size.width + verticalPaddingLeft + verticalPaddingRight;
}

- (void)drawRect:(NSRect)aRect;
{
	[backgroundColor set];
	NSRectFill([self bounds]);
	
	// Only draw if the slot is larger than the knob
	if (isVertical && ([self bounds].size.height - verticalPaddingTop - verticalPaddingBottom + 1) > minKnobHeight)
	{
		[self drawKnobSlot];
		
		if ([self knobProportion] > 0.0)	
			[self drawKnob];
	}
	else if (!isVertical && ([self bounds].size.width - horizontalPaddingLeft - horizontalPaddingRight + 1) > minKnobWidth)
	{
		[self drawKnobSlot];
		
		if ([self knobProportion] > 0.0)	
			[self drawKnob];
	}
}

- (void)drawKnobSlot;
{
	//	NSRect slotRect = [self rectForPart:NSScrollerKnobSlot];
	
	//	if (isVertical)
	//		NSDrawThreePartImage(slotRect, slotTop, slotVerticalFill, slotBottom, YES, NSCompositeSourceOver, 1, NO);
	//	else
	//		NSDrawThreePartImage(slotRect, slotLeft, slotHorizontalFill, slotRight, NO, NSCompositeSourceOver, 1, NO);
}

- (void)drawKnob;
{
	NSRect knobRect = [self rectForPart:NSScrollerKnob];
	
	if (isVertical)
		NSDrawThreePartImage(knobRect, knobTop, knobVerticalFill, knobBottom, YES, NSCompositeSourceOver, 1, NO);
	else
		NSDrawThreePartImage(knobRect, knobLeft, knobHorizontalFill, knobRight, NO, NSCompositeSourceOver, 1, NO);
}

- (NSRect)_drawingRectForPart:(NSScrollerPart)aPart;
{
	// Call super even though we're not using its value (has some side effects we need)
	[super _drawingRectForPart:aPart];
	
	// Return our own rects rather than use the default behavior
	return [self rectForPart:aPart];
}

- (NSRect)rectForPart:(NSScrollerPart)aPart;
{
	switch (aPart)
	{
		case NSScrollerNoPart:
			return [self bounds];
			break;
		case NSScrollerKnob:
		{
			NSRect knobRect;
			NSRect slotRect = [self rectForPart:NSScrollerKnobSlot];			
			
			if (isVertical)
			{
				float knobHeight = roundf(slotRect.size.height * [self knobProportion]);
				
				if (knobHeight < minKnobHeight)
					knobHeight = minKnobHeight;
				
				float knobY = slotRect.origin.y + roundf((slotRect.size.height - knobHeight) * [self floatValue]);
				knobRect = NSMakeRect(verticalPaddingLeft, knobY, slotRect.size.width, knobHeight);
			}
			else
			{
				float knobWidth = roundf(slotRect.size.width * [self knobProportion]);
				
				if (knobWidth < minKnobWidth)
					knobWidth = minKnobWidth;
				
				float knobX = slotRect.origin.x + roundf((slotRect.size.width - knobWidth) * [self floatValue]);
				knobRect = NSMakeRect(knobX, horizontalPaddingTop, knobWidth, slotRect.size.height);
			}
			
			return knobRect;
		}
			break;	
		case NSScrollerKnobSlot:
		{
			NSRect slotRect;
			
			if (isVertical)
				slotRect = NSMakeRect(verticalPaddingLeft, verticalPaddingTop, [self bounds].size.width - verticalPaddingLeft - verticalPaddingRight, [self bounds].size.height - verticalPaddingTop - verticalPaddingBottom);
			else
				slotRect = NSMakeRect(horizontalPaddingLeft, horizontalPaddingTop, [self bounds].size.width - horizontalPaddingLeft - horizontalPaddingRight, [self bounds].size.height - horizontalPaddingTop - horizontalPaddingBottom);
			
			return slotRect;
		}
			break;
		case NSScrollerIncrementLine:
			return NSZeroRect;
			break;
		case NSScrollerDecrementLine:
			return NSZeroRect;
			break;
		case NSScrollerIncrementPage:
		{
			NSRect incrementPageRect;
			NSRect knobRect = [self rectForPart:NSScrollerKnob];
			NSRect slotRect = [self rectForPart:NSScrollerKnobSlot];
			NSRect decPageRect = [self rectForPart:NSScrollerDecrementPage];
			
			if (isVertical)
			{
				float knobY = knobRect.origin.y + knobRect.size.height;	
				incrementPageRect = NSMakeRect(verticalPaddingLeft, knobY, knobRect.size.width, slotRect.size.height - knobRect.size.height - decPageRect.size.height);
			}
			else
			{
				float knobX = knobRect.origin.x + knobRect.size.width;
				incrementPageRect = NSMakeRect(knobX, horizontalPaddingTop, (slotRect.size.width + horizontalPaddingLeft) - knobX, knobRect.size.height);
			}
			
			return incrementPageRect;
		}
			break;
		case NSScrollerDecrementPage:
		{
			NSRect decrementPageRect;
			NSRect knobRect = [self rectForPart:NSScrollerKnob];
			
			if (isVertical)
				decrementPageRect = NSMakeRect(verticalPaddingLeft, verticalPaddingTop, knobRect.size.width, knobRect.origin.y - verticalPaddingTop);
			else
				decrementPageRect = NSMakeRect(horizontalPaddingLeft, horizontalPaddingTop, knobRect.origin.x - horizontalPaddingLeft, knobRect.size.height);
			
			return decrementPageRect;
		}
			break;
		default:
			break;
	}
	
	return NSZeroRect;
}

@end
