/* NotesTableView */
/*Copyright (c) 2010, Zachary Schneirov. All rights reserved.
    This file is part of Notational Velocity.

    Notational Velocity is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Notational Velocity is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Notational Velocity.  If not, see <http://www.gnu.org/licenses/>. */


#import <Cocoa/Cocoa.h>

@class HeaderViewWithMenu;
@class NoteAttributeColumn;
@class GlobalPrefs;

@interface NVViewLocationContext : NSObject

@property (nonatomic) BOOL pivotRowWasEdge;
@property (nonatomic, assign) id pivotObject;
@property (nonatomic) float verticalDistanceToPivotRow;

@end

@protocol NVLabelsListSource <NSObject>

- (NSArray*)labelTitlesPrefixedByString:(NSString*)prefixString indexOfSelectedItem:(NSInteger *)anIndex minusWordSet:(NSSet*)antiSet;

@end

@interface NotesTableView : NSTableView {
	NSTimer *modifierTimer;
	IBOutlet NSTextField *controlField;
	NSMutableArray *allColumns;
	NSMutableDictionary *allColsDict;
	
	NSInteger firstRowIndexBeforeSplitResize;
	
	BOOL viewMenusValid;
	BOOL hadHighlightInForeground, hadHighlightInBackground;
	BOOL shouldUseSecondaryHighlightColor, isActiveStyle;
	BOOL lastEventActivatedTagEdit, wasDeleting, isAutocompleting;
	
	GlobalPrefs *globalPrefs;
	NSMenuItem *dummyItem;
	HeaderViewWithMenu *headerView;
	NSView *cornerView;
	NSTextFieldCell *cachedCell;
	
	NSDictionary *loadStatusAttributes;
	float loadStatusStringWidth;
	NSString *loadStatusString;
	
	float tableFontHeight;

	int affinity;	

	NSUserDefaults *userDefaults;
}

- (void)noteFirstVisibleRow;
- (void)makeFirstPreviouslyVisibleRowVisibleIfNecessary;

@property (nonatomic, retain) NVViewLocationContext *viewingLocation;

- (double)distanceFromRow:(NSUInteger)aRow forVisibleArea:(NSRect)visibleRect;
- (void)scrollRowToVisible:(NSInteger)rowIndex withVerticalOffset:(float)offset;
- (void)selectRowAndScroll:(NSInteger)row;

- (float)tableFontHeight;

- (BOOL)isActiveStyle;
- (void)setShouldUseSecondaryHighlightColor:(BOOL)value;
- (void)_setActiveStyleState:(BOOL)activeStyle;
- (void)updateTitleDereferencorState;

- (void)reloadDataIfNotEditing;

- (void)restoreColumns;
- (void)_configureAttributesForCurrentLayout;
- (void)updateHeaderViewForColumns;
- (BOOL)eventIsTagEdit:(NSEvent*)event forColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex;
- (BOOL)lastEventActivatedTagEdit;
- (void)editRowAtColumnWithIdentifier:(id)identifier;
- (BOOL)addPermanentTableColumn:(NSTableColumn*)column;
- (IBAction)actionHideShowColumn:(id)sender;
- (IBAction)toggleNoteBodyPreviews:(id)sender;
- (void)setStatusForSortedColumn:(id)item;
- (void)setSortDirection:(BOOL)direction inTableColumn:(NSTableColumn*)tableColumn;
- (NSMenu *)defaultNoteCommandsMenuWithTarget:(id)target;
- (NSMenu *)menuForColumnSorting;
- (NSMenu *)menuForColumnConfiguration:(NSTableColumn *)inSelectedColumn;
- (NoteAttributeColumn*)noteAttributeColumnForIdentifier:(NSString*)identifier;

- (void)incrementNoteSelection:(id)sender;
- (void)_incrementNoteSelectionByTag:(NSInteger)tag;

@property (nonatomic, assign) id <NVLabelsListSource> labelsListSource;

- (NSArray *)labelCompletionsForString:(NSString *)fieldString index:(NSInteger)index;

- (SEL)attributeSetterForColumn:(NoteAttributeColumn*)col;


@end

@interface NSTableView (Private)
- (BOOL)_shouldUseSecondaryHighlightColor;
- (void)_sizeRowHeaderToFitIfNecessary;

//10.3 only
- (void)_sizeToFitIfNecessary;
@end

