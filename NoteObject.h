//
//  NoteObject.h
//  Notation
//
//  Created by Zachary Schneirov on 12/19/05.

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
#import "NotationController.h"
#import "BufferUtils.h"
#import "SynchronizedNoteProtocol.h"
#import "NotationTypes.h"

@class LabelObject;
@class WALStorageController;
@class NotesTableView;
@class ExternalEditor;

typedef struct _NoteFilterContext {
	char* needle;
	BOOL useCachedPositions;
} NoteFilterContext;

@interface NoteObject : NSObject <NSCoding, SynchronizedNote> {
	NSAttributedString *tableTitleString;
	
	//caching/searching purposes only -- created at runtime
	char *cTitle, *cContents, *cLabels;
	NSMutableSet *labelSet;
	BOOL contentCacheNeedsUpdate;
	//if this note's title is "Chicken Shack menu listing", its prefix parent might have the title "Chicken Shack"
	
//	NSString *wordCountString;
	NSString *dateModifiedString, *dateCreatedString;
	
	__weak id delegate; //the notes controller
	
	//for syncing to text file
	NSUInteger perDiskInfoGroupCount;
	BOOL shouldWriteToFile, didUnarchive;
	
	//not determined until it's time to read to or write from a text file
	FSRef *noteFileRef;
	
	//more metadata
	NSRange selectedRange;
	
	//each note has its own undo manager--isn't that nice?
	NSUndoManager *undoManager;
}

@property (nonatomic) CFAbsoluteTime modifiedDate;
@property (nonatomic) CFAbsoluteTime createdDate;
@property (nonatomic, readonly) BOOL contentsWere7Bit;
@property (nonatomic, readonly) NVDatabaseFormat currentFormatID;
@property (nonatomic, readonly) UInt32 logicalSize;
@property (nonatomic, readonly) UInt32 nodeID;

@property (nonatomic, readonly) UTCDateTime fileModifiedDate;

@property (nonatomic, copy) NSAttributedString *contentString;
@property (nonatomic, copy, readonly) NSString *filename;
@property (nonatomic, copy) NSString *titleString;
@property (nonatomic, copy) NSString *labelString;

@property (nonatomic, assign) UTCDateTime *attrsModifiedDate;
@property (nonatomic, strong) NSMutableArray *prefixParentNotes;

#define DefColAttrAccessor(__FName, __IVar) force_inline id __FName(NotesTableView *tv, NoteObject *note, NSInteger row) { return note->__IVar; }

	//return types are NSString or NSAttributedString, satisifying NSTableDataSource protocol otherwise
	id titleOfNote2(NotesTableView *tv, NoteObject *note, NSInteger row);
	id tableTitleOfNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id properlyHighlightingTableTitleOfNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id unifiedCellSingleLineForNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id unifiedCellForNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id labelColumnCellForNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id dateCreatedStringOfNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id dateModifiedStringOfNote(NotesTableView *tv, NoteObject *note, NSInteger row);
	id wordCountOfNote(NotesTableView *tv, NoteObject *note, NSInteger row);

	BOOL noteTitleHasPrefixOfUTF8String(NoteObject *note, const char* fullString, size_t stringLen);
	BOOL noteTitleIsAPrefixOfOtherNoteTitle(NoteObject *longerNote, NoteObject *shorterNote);

@property (nonatomic, weak) id delegate;

- (id)initWithNoteBody:(NSAttributedString *)bodyText title:(NSString *)aNoteTitle
              delegate:(id)aDelegate format:(NVDatabaseFormat)formatID labels:(NSString*)aLabelString;
- (id)initWithCatalogEntry:(NoteCatalogEntry*)entry delegate:(id)aDelegate;

- (NSSet*)labelSet;
- (void)replaceMatchingLabelSet:(NSSet*)aLabelSet;
- (void)replaceMatchingLabel:(LabelObject*)label;
- (void)updateLabelConnectionsAfterDecoding;
- (void)updateLabelConnections;
- (void)disconnectLabels;
- (BOOL)_setLabelString:(NSString*)newLabelString;
- (NSMutableSet*)labelSetFromCurrentString;
- (NSArray*)orderedLabelTitles;
- (NSSize)sizeOfLabelBlocks;
- (void)_drawLabelBlocksInRect:(NSRect)aRect rightAlign:(BOOL)onRight highlighted:(BOOL)isHighlighted getSizeOnly:(NSSize*)reqSize;
- (void)drawLabelBlocksInRect:(NSRect)aRect rightAlign:(BOOL)onRight highlighted:(BOOL)isHighlighted;

- (void)setSyncObjectAndKeyMD:(NSDictionary*)aDict forService:(NSString*)serviceName;
- (void)removeAllSyncMDForService:(NSString*)serviceName;
//- (void)removeKey:(NSString*)aKey forService:(NSString*)serviceName;
- (void)updateWithSyncBody:(NSString*)newBody andTitle:(NSString*)newTitle;
- (void)registerModificationWithOwnedServices;

@property (nonatomic, readonly) NSStringEncoding fileEncoding;
- (OSStatus)writeCurrentFileEncodingToFSRef:(FSRef*)fsRef;
- (void)_setFileEncoding:(NSStringEncoding)encoding;
- (BOOL)setFileEncodingAndReinterpret:(NSStringEncoding)encoding;
- (BOOL)upgradeToUTF8IfUsingSystemEncoding;
- (BOOL)upgradeEncodingToUTF8;
- (BOOL)updateFromFile;
- (BOOL)updateFromCatalogEntry:(NoteCatalogEntry*)catEntry;
- (BOOL)updateFromData:(NSMutableData *)data inFormat:(NVDatabaseFormat)fmt;

- (OSStatus)writeFileDatesAndUpdateTrackingInfo;

- (NSURL*)uniqueNoteLink;
- (NSString*)noteFilePath;
- (void)invalidateFSRef;

- (BOOL)writeUsingJournal:(WALStorageController*)wal;

- (BOOL)writeUsingCurrentFileFormatIfNecessary;
- (BOOL)writeUsingCurrentFileFormatIfNonExistingOrChanged;
- (BOOL)writeUsingCurrentFileFormat;
- (void)makeNoteDirtyUpdateTime:(BOOL)updateTime updateFile:(BOOL)updateFile;

- (void)moveFileToTrash;
- (void)removeFileFromDirectory;
- (BOOL)removeUsingJournal:(WALStorageController*)wal;

- (OSStatus)exportToDirectoryRef:(FSRef *)directoryRef withFilename:(NSString *)userFilename usingFormat:(NVDatabaseFormat)storageFormat overwrite:(BOOL)overwrite;
- (NSRange)nextRangeForWords:(NSArray*)words options:(unsigned)opts range:(NSRange)inRange;
- (void)editExternallyUsingEditor:(ExternalEditor*)ed;
- (void)abortEditingInExternalEditor;

- (void)setFilenameFromTitle;
- (void)setFilename:(NSString*)aString withExternalTrigger:(BOOL)externalTrigger;
- (BOOL)_setTitleString:(NSString*)aNewTitle;
- (void)setTitleString:(NSString*)aNewTitle;
- (void)updateTablePreviewString;
- (void)initContentCacheCString;
- (void)updateContentCacheCStringIfNecessary;
- (NSAttributedString*)printableStringRelativeToBodyFont:(NSFont*)bodyFont;
- (NSString*)combinedContentWithContextSeparator:(NSString*)sepWContext;
- (void)setForegroundTextColorOnly:(NSColor*)aColor;
- (void)_resanitizeContent;
- (void)updateUnstyledTextWithBaseFont:(NSFont*)baseFont;
- (void)updateDateStrings;
- (void)setDateModified:(CFAbsoluteTime)newTime;
- (void)setDateAdded:(CFAbsoluteTime)newTime;
- (void)setSelectedRange:(NSRange)newRange;
- (NSRange)lastSelectedRange;
- (void)addPrefixParentNote:(NoteObject*)aNote;
- (void)removeAllPrefixParentNotes;
- (void)previewUsingMarked;

- (NSUndoManager*)undoManager;
- (void)_undoManagerDidChange:(NSNotification *)notification;

#pragma mark - Comparators

- (NSComparisonResult)compare:(NoteObject *)other;
- (NSComparisonResult)compareCreatedDate:(NoteObject *)other;
- (NSComparisonResult)compareModifiedDate:(NoteObject *)other;
- (NSComparisonResult)compareUniqueNoteID:(NoteObject *)other;

@end

@interface NSObject (NoteObjectDelegate)
- (void)note:(NoteObject*)note didAddLabelSet:(NSSet*)labelSet;
- (void)note:(NoteObject*)note didRemoveLabelSet:(NSSet*)labelSet;
- (void)note:(NoteObject*)note attributeChanged:(NSString*)attribute;
@end

