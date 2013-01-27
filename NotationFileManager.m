//
//  NotationFileManager.m
//  Notation
//
//  Created by Zachary Schneirov on 4/9/06.

/*Copyright (c) 2010, Zachary Schneirov. All rights reserved.
  Redistribution and use in source and binary forms, with or without modification, are permitted 
  provided that the following conditions are met:
   - Redistributions of source code must retain the above copyright notice, this list of conditions 
     and the following disclaimer.
   - Redistributions in binary form must reproduce the above copyright notice, this list of 
	 conditions and the following disclaimer in the documentation and/or other materials provided with
     the distribution.
   - Neither the name of Notational Velocity nor the names of its contributors may be used to endorse 
     or promote products derived from this software without specific prior written permission. */


#import "NotationFileManager.h"
#import "NSString_NV.h"
#import "NSFileManager_NV.h"
#import "GlobalPrefs.h"
#import "NSData_transformations.h"
#import "NSURL+Notation.h"
#import "NoteCatalogEntry.h"
#include <sys/mount.h>

#import <CommonCrypto/CommonCrypto.h>

NSString *NotesDatabaseFileName = @"Notes & Settings";

@implementation NotationController (NotationFileManager)

static struct statfs *StatFSVolumeInfo(NotationController *controller);

OSStatus CreateDirectoryIfNotPresent(FSRef *parentRef, CFStringRef subDirectoryName, FSRef *childRef) {
	UniChar chars[256];

	OSStatus result;
	if ((result = FSRefMakeInDirectoryWithString(parentRef, childRef, subDirectoryName, chars))) {
		if (result == fnfErr) {
			result = FSCreateDirectoryUnicode(parentRef, CFStringGetLength(subDirectoryName),
					chars, kFSCatInfoNone, NULL, childRef, NULL, NULL);
		}
		return result;
	}

	return noErr;
}

+ (NSURL *)createDirectoryIfNotPresentWithName:(NSString *)subName inDirectory:(NSURL *)directory error:(out NSError **)outError {
	NSURL *URL = [directory URLByAppendingPathComponent: subName isDirectory: YES];
	if (![URL checkResourceIsReachableAndReturnError: NULL]) {
		NSError *error = nil;
		if ([[NSFileManager defaultManager] createDirectoryAtURL: URL withIntermediateDirectories: YES attributes: nil error: &error]) {
			return URL;
		} else {
			if (outError) *outError = error;
			return nil;
		}
	}
	return URL;
}

/*
 Read the UUID from a mounted volume, by calling getattrlist().
 Assumes the path is the mount point of an HFS volume.
 */
static BOOL GetVolumeUUIDAttr(const char *path, VolumeUUID *volumeUUIDPtr) {
	struct attrlist alist;
	struct FinderAttrBuf {
		u_int32_t info_length;
		u_int32_t finderinfo[8];
	} volFinderInfo;

	int result = -1;

	/* Set up the attrlist structure to get the volume's Finder Info */
	alist.bitmapcount = 5;
	alist.reserved = 0;
	alist.commonattr = ATTR_CMN_FNDRINFO;
	alist.volattr = ATTR_VOL_INFO;
	alist.dirattr = 0;
	alist.fileattr = 0;
	alist.forkattr = 0;

	/* Get the Finder Info */
	if ((result = getattrlist(path, &alist, &volFinderInfo, sizeof(volFinderInfo), 0))) {
		NSLog(@"GetVolumeUUIDAttr error: %d", result);
		return NO;
	}

	/* Copy the UUID from the Finder Into to caller's buffer */
	VolumeUUID *finderInfoUUIDPtr = (VolumeUUID *) (&volFinderInfo.finderinfo[6]);
	volumeUUIDPtr->v.high = CFSwapInt32BigToHost(finderInfoUUIDPtr->v.high);
	volumeUUIDPtr->v.low = CFSwapInt32BigToHost(finderInfoUUIDPtr->v.low);

	return YES;
}


// Create a version 3 UUID; derived using "name" via MD5 checksum.
static void uuid_create_md5_from_name(unsigned char result_uuid[16], const void *name, int namelen) {

	static unsigned char FSUUIDNamespaceSHA1[16] = {
			0xB3, 0xE2, 0x0F, 0x39, 0xF2, 0x92, 0x11, 0xD6,
			0x97, 0xA4, 0x00, 0x30, 0x65, 0x43, 0xEC, 0xAC
	};

	CC_MD5_CTX c;

	CC_MD5_Init(&c);
	CC_MD5_Update(&c, FSUUIDNamespaceSHA1, sizeof(FSUUIDNamespaceSHA1));
	CC_MD5_Update(&c, name, namelen);
	CC_MD5_Final(result_uuid, &c);

	result_uuid[6] = (result_uuid[6] & 0x0F) | 0x30;
	result_uuid[8] = (result_uuid[8] & 0x3F) | 0x80;
}


CFUUIDRef CopyHFSVolumeUUIDForMount(const char *mntonname) {
	VolumeUUID targetVolumeUUID;

	unsigned char rawUUID[8];

	if (!GetVolumeUUIDAttr(mntonname, &targetVolumeUUID))
		return NULL;

	((uint32_t *) rawUUID)[0] = CFSwapInt32HostToBig(targetVolumeUUID.v.high);
	((uint32_t *) rawUUID)[1] = CFSwapInt32HostToBig(targetVolumeUUID.v.low);

	CFUUIDBytes uuidBytes;
	uuid_create_md5_from_name((void *) &uuidBytes, rawUUID, sizeof(rawUUID));

	return CFUUIDCreateFromUUIDBytes(NULL, uuidBytes);
}

CFUUIDRef CopySyntheticUUIDForVolumeCreationDate(FSRef *fsRef);

CFUUIDRef CopySyntheticUUIDForVolumeCreationDate(FSRef *fsRef) {

	FSCatalogInfo fileInfo;
	if (FSGetCatalogInfo(fsRef, kFSCatInfoVolume, &fileInfo, NULL, NULL, NULL) == noErr) {

		FSVolumeInfo volInfo;
		OSStatus err = FSGetVolumeInfo(fileInfo.volume, 0, NULL, kFSVolInfoCreateDate, &volInfo, NULL, NULL);
		if (err == noErr) {
			volInfo.createDate.highSeconds = CFSwapInt16HostToBig(volInfo.createDate.highSeconds);
			volInfo.createDate.lowSeconds = CFSwapInt32HostToBig(volInfo.createDate.lowSeconds);
			volInfo.createDate.fraction = CFSwapInt16HostToBig(volInfo.createDate.fraction);

			CFUUIDBytes uuidBytes;
			uuid_create_md5_from_name((void *) &uuidBytes, (void *) &volInfo.createDate, sizeof(UTCDateTime));

			return CFUUIDCreateFromUUIDBytes(NULL, uuidBytes);
		} else {
			NSLog(@"can't even get the volume creation date -- what are you trying to do to me?");
		}
	}
	return NULL;
}

- (void)initializeDiskUUIDIfNecessary {
	//create a CFUUIDRef that identifies the volume this database sits on

	//don't bother unless we will be reading notes as separate files; otherwise there's no need to track the source of the attr mod dates
	//maybe disk UUIDs will be used in the future for something else; at that point this check should be altered

	if (!diskUUID && [self currentNoteStorageFormat] != SingleDatabaseFormat) {

		struct statfs *sfsb = StatFSVolumeInfo(self);
		//if this is not an hfs+ disk, then get the FSEvents UUID
		//if this is not Leopard or the FSEvents UUID is null,
		//then take MD5 sum of creation date + some other info?

		if (!strcmp(sfsb->f_fstypename, "hfs")) {
			//if this is an HFS volume, then use getattrlist to get finderinfo from the volume
			diskUUID = CopyHFSVolumeUUIDForMount(sfsb->f_mntonname);
		}

		//ah but what happens when a non-hfs disk is first mounted on leopard+, and then moves to a tiger machine?
		//or vise-versa; that calls for tracking how the UUIDs were generated, and grouping them together when others are found;
		//this is probably unnecessary for now
		if (!diskUUID) {
			//this is not an hfs disk, and this computer is new enough to have FSEvents
			diskUUID = FSEventsCopyUUIDForDevice(sfsb->f_fsid.val[0]);
		}

		if (!diskUUID) {
			//all other checks failed; just use the volume's creation date
			diskUUID = CopySyntheticUUIDForVolumeCreationDate(&noteDirectoryRef);
		}
		diskUUIDIndex = [notationPrefs tableIndexOfDiskUUID:diskUUID];
	}
}

static struct statfs *StatFSVolumeInfo(NotationController *controller) {
	if (!controller->statfsInfo) {
		OSStatus err = noErr;
		const UInt32 maxPathSize = 4 * 1024;
		UInt8 *convertedPath = (UInt8 *) malloc(maxPathSize * sizeof(UInt8));

		if ((err = FSRefMakePath(&(controller->noteDirectoryRef), convertedPath, maxPathSize)) == noErr) {

			controller->statfsInfo = calloc(1, sizeof(struct statfs));

			if (statfs((char *) convertedPath, controller->statfsInfo))
				NSLog(@"statfs: error %d\n", errno);
		} else
			NSLog(@"FSRefMakePath: error %d\n", err);

		free(convertedPath);
	}
	return controller->statfsInfo;
}

- (NSUInteger)diskUUIDIndex {
	return diskUUIDIndex;
}

NSUInteger diskUUIDIndexForNotation(NotationController *controller) {
	return controller->diskUUIDIndex;
}

long BlockSizeForNotation(NotationController *controller) {
	if (!controller->blockSize) {
		long iosize = 0;

		struct statfs *sfsb = StatFSVolumeInfo(controller);
		if (sfsb) iosize = sfsb->f_iosize;

		controller->blockSize = MAX(iosize, 16 * 1024);
	}

	return controller->blockSize;
}

- (OSStatus)refreshFileRefIfNecessary:(FSRef *)childRef withName:(NSString *)filename charsBuffer:(UniChar *)charsBuffer {
	BOOL isOwned = NO;
	if (IsZeros(childRef, sizeof(FSRef)) || [self fileInNotesDirectory:childRef isOwnedByUs:&isOwned hasCatalogInfo:NULL] != noErr || !isOwned) {
		OSStatus err = noErr;
		if ((err = FSRefMakeInDirectoryWithString(&noteDirectoryRef, childRef, (__bridge CFStringRef) filename, charsBuffer)) != noErr) {
			NSLog(@"Could not get an fsref for file with name %@: %d\n", filename, err);
			return err;
		}
	}
	return noErr;
}

- (NSURL *)refreshFileURLIfNecessary:(NSURL *)URL withName:(NSString *)filename error: (NSError **)err {
	if (!URL || ![self fileInNotesDirectoryIsOwnedByUs: URL]) {
		return [[self.noteDirectoryURL URLByAppendingPathComponent: filename] fileReferenceURL];
	}
	return URL;
}


- (BOOL)notesDirectoryIsTrashed {
	NSURL *trashURL = [[self trashFolderForURL: self.noteDirectoryURL error: NULL] URLByStandardizingPath];
	if (!trashURL) return NO;
	NSURL *stdNoteDirectory = self.noteDirectoryURL.URLByStandardizingPath;
	return [stdNoteDirectory.path hasPrefix: trashURL.path];
}

- (NSURL *)notesDirectoryContainsFile:(NSString *)filename {
	if (!filename) return NO;
	return [[self.noteDirectoryURL URLByAppendingPathComponent: filename] fileReferenceURL];
}

- (NSURL *)notesDirectoryContainsFile:(NSString *)filename returningFSRef:(FSRef *)childRef {
	NSURL *ret = [self notesDirectoryContainsFile: filename];
	if (childRef) [ret getFSRef: childRef];
	return ret;
}

- (OSStatus)renameAndForgetNoteDatabaseFile:(NSString *)newfilename {
	//this method does not move the note database file; for now it is used in cases of upgrading incompatible files

	UniChar chars[256];
	OSStatus err = noErr;
	CFRange range = {0, CFStringGetLength((CFStringRef) newfilename)};
	CFStringGetCharacters((CFStringRef) newfilename, range, chars);

	if ((err = FSRenameUnicode(&noteDatabaseRef, range.length, chars, kTextEncodingDefaultFormat, NULL)) != noErr) {
		NSLog(@"Error renaming notes database file to %@: %d", newfilename, err);
		return err;
	} else {
		_noteDatabaseURL = nil;
	}
	//reset the FSRef to ensure it doesn't point to the renamed file
	bzero(&noteDatabaseRef, sizeof(FSRef));
	return noErr;
}

- (BOOL)removeSpuriousDatabaseFileNotes {
	//remove any notes that might have been made out of the database or write-ahead-log files by accident
	//but leave the files intact; ensure only that they are also remotely unsynced
	//returns true if at least one note was removed, in which case allNotes should probably be refiltered

	NSUInteger i = 0;
	NoteObject *dbNote = nil, *walNote = nil;

	for (i = 0; i < [allNotes count]; i++) {
		NoteObject *obj = allNotes[i];

		if (!dbNote && [obj.filename isEqualToString:NotesDatabaseFileName])
			dbNote = obj;
		if (!walNote && [obj.filename isEqualToString:@"Interim Note-Changes"])
			walNote = obj;
	}
	if (dbNote) {
		[allNotes removeObjectIdenticalTo:dbNote];
		[self _addDeletedNote:dbNote];
	}
	if (walNote) {
		[allNotes removeObjectIdenticalTo:walNote];
		[self _addDeletedNote:walNote];
	}
	return walNote || dbNote;
}

- (void)relocateNotesDirectory {

	while (1) {
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setCanCreateDirectories:YES];
		[openPanel setCanChooseFiles:NO];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setResolvesAliases:YES];
		[openPanel setAllowsMultipleSelection:NO];
		[openPanel setTreatsFilePackagesAsDirectories:NO];
		[openPanel setTitle:NSLocalizedString(@"Select a folder", nil)];
		[openPanel setPrompt:NSLocalizedString(@"Select", nil)];
		[openPanel setMessage:NSLocalizedString(@"Select a new location for your Notational Velocity notes.", nil)];

		if ([openPanel runModal] == NSOKButton) {
			NSURL *newURL = openPanel.URL;
			
			NSString *filename = newURL.path;
			if (filename) {

				FSRef newParentRef;
				CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (__bridge CFStringRef) filename, kCFURLPOSIXPathStyle, true);
				if (!url || !CFURLGetFSRef(url, &newParentRef)) {
					NSRunAlertPanel(NSLocalizedString(@"Unable to create an FSRef from the chosen directory.", nil),
							NSLocalizedString(@"Your notes were not moved.", nil), NSLocalizedString(@"OK", nil), NULL, NULL);
					if (url) CFRelease(url);
					continue;
				}
				CFRelease(url);

				NSError *err = nil;
				if ([self.fileManager moveItemAtURL: self.noteDirectoryURL toURL: newURL error: &err]) {
					_noteDirectoryURL = [newURL fileReferenceURL];
				} else {
					NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"Couldn't move notes into the chosen folder because %@", nil), [err localizedDescription]], NSLocalizedString(@"Your notes were not moved.", nil), NSLocalizedString(@"OK", nil), NULL, NULL);
					continue;
				}

				FSRef newNotesDirectory;
				[_noteDirectoryURL getFSRef: &newNotesDirectory];

				if (FSCompareFSRefs(&noteDirectoryRef, &newNotesDirectory) != noErr) {
					NSData *aliasData = [NSData aliasDataForFSRef:&newNotesDirectory];
					if (aliasData) [[GlobalPrefs defaultPrefs] setAliasDataForDefaultDirectory:aliasData sender:self];
					//we must quit now, as notes will very likely be re-initialized in the same place
					goto terminate;
				}

				//directory move successful! //show the user where new notes are
				[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[ _noteDirectoryURL ]];

				break;
			} else {
				goto terminate;
			}
		} else {
			terminate:
					[NSApp terminate:nil];
			break;
		}
	}
}

+ (OSStatus)getDefaultNotesDirectoryRef:(FSRef *)notesDir {
	FSRef appSupportFoundRef;

	OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kCreateFolder, &appSupportFoundRef);
	if (err != noErr) {
		NSLog(@"Unable to locate or create an Application Support directory: %d", err);
		return err;
	} else {
		//now try to get Notational Database directory
		if ((err = CreateDirectoryIfNotPresent(&appSupportFoundRef, (CFStringRef) @"Notational Data", notesDir)) != noErr) {

			return err;
		}
	}
	return noErr;
}

+ (NSURL *)defaultNotesDirectoryURLReturningError:(out NSError **)outErr {
	NSError *err = nil;
	NSURL *appSupportURL = nil;
	NSURL *notesDirectoryURL = nil;

	if ((appSupportURL = [[NSFileManager defaultManager] URLForDirectory: NSApplicationSupportDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: YES error: &err])) {
		if ((notesDirectoryURL = [self createDirectoryIfNotPresentWithName: @"Notational Data" inDirectory: appSupportURL error: &err])) {
			return notesDirectoryURL;
		}
	}

	if (outErr) *outErr = err;

	return nil;
}

//whenever a note uses this method to change its filename, we will have to re-establish all the links to it
- (NSString *)uniqueFilenameForTitle:(NSString *)title fromNote:(NoteObject *)note {
	//generate a unique filename based on title, varying numbers
	__block BOOL isUnique = YES;
	__block NSString *uniqueFilename = title;

	//remove illegal characters
	NSMutableString *sanitizedName = [[uniqueFilename stringByReplacingOccurrencesOfString:@":" withString:@"-"] mutableCopy];
	if ([sanitizedName characterAtIndex:0] == (unichar) '.') [sanitizedName replaceCharactersInRange:NSMakeRange(0, 1) withString:@"_"];
	uniqueFilename = [sanitizedName copy];

	//use the note's current format if the current default format is for a database; get the "ideal" extension for that format
	NoteStorageFormat noteFormat = [notationPrefs notesStorageFormat] || !note ? [notationPrefs notesStorageFormat] : note.storageFormat;
	NSString *extension = [notationPrefs chosenPathExtensionForFormat:noteFormat];

	//if the note's current extension is compatible with the storage format above, then use the existing extension instead
	if (note && note.filename && [notationPrefs pathExtensionAllowed:note.filename.pathExtension forFormat:noteFormat])
		extension = note.filename.pathExtension;

	//assume that we won't have more than 999 notes with the exact same name and of more than 247 chars
	uniqueFilename = [uniqueFilename filenameExpectingAdditionalCharCount:3 + [extension length] + 2];

	__block NSUInteger iteration = 0;
	do {
		isUnique = YES;

		//this ought to just use an nsset, but then we'd have to maintain a parallel data structure for marginal benefit
		//also, it won't quite work right for filenames with no (real) extensions and periods in their names
		[allNotes enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NoteObject *aNote, NSUInteger idx, BOOL *stop) {
			NSString *basefilename = [aNote.filename stringByDeletingPathExtension];

			if (note != aNote && [basefilename caseInsensitiveCompare:uniqueFilename] == NSOrderedSame) {
				isUnique = NO;

				uniqueFilename = [uniqueFilename stringByDeletingPathExtension];
				NSString *numberPath = [@(++iteration) stringValue];
				uniqueFilename = [uniqueFilename stringByAppendingPathExtension:numberPath];
				*stop = YES;
			}
		}];
	} while (!isUnique);

	return [uniqueFilename stringByAppendingPathExtension:extension];
}

- (OSStatus)noteFileRenamed:(FSRef *)childRef fromName:(NSString *)oldName toName:(NSString *)newName {
	if (![self currentNoteStorageFormat])
		return noErr;

	UniChar chars[256];

	OSStatus err = [self refreshFileRefIfNecessary:childRef withName:oldName charsBuffer:chars];
	if (noErr != err) return err;

	CFRange range = {0, CFStringGetLength((CFStringRef) newName)};
	CFStringGetCharacters((CFStringRef) newName, range, chars);

	if ((err = FSRenameUnicode(childRef, range.length, chars, kTextEncodingDefaultFormat, childRef)) != noErr) {
		NSLog(@"Error renaming file %@ to %@: %d", oldName, newName, err);
		return err;
	}

	return noErr;
}

- (BOOL)fileInNotesDirectoryIsOwnedByUs:(NSURL *)URL {
	return [URL.URLByDeletingLastPathComponent isEqualToFileURL: self.noteDirectoryURL];
}

- (OSStatus)fileInNotesDirectory:(FSRef *)childRef isOwnedByUs:(BOOL *)owned hasCatalogInfo:(FSCatalogInfo *)info {
	FSRef parentRef;
	FSCatalogInfoBitmap whichInfo = kFSCatInfoNone;

	if (owned) *owned = NO;

	if (info) {
		whichInfo = kFSCatInfoContentMod | kFSCatInfoCreateDate | kFSCatInfoAttrMod | kFSCatInfoDataSizes;
		bzero(info, sizeof(FSCatalogInfo));
	}

	OSStatus err = noErr;

	if ((err = FSGetCatalogInfo(childRef, whichInfo, info, NULL, NULL, &parentRef)) != noErr)
		return err;

	if (owned) *owned = (FSCompareFSRefs(&parentRef, &noteDirectoryRef) == noErr);

	return noErr;
}

- (OSStatus)deleteFileInNotesDirectory:(FSRef *)childRef forFilename:(NSString *)filename {
	UniChar chars[256];
	OSStatus err = [self refreshFileRefIfNecessary:childRef withName:filename charsBuffer:chars];
	if (noErr != err) return err;

	if ((err = FSDeleteObject(childRef)) != noErr) {
		NSLog(@"Error deleting file: %d", err);
		return err;
	}

	return noErr;
}

- (NSMutableData *)dataFromFileInNotesDirectory:(FSRef *)childRef forCatalogEntry:(NoteCatalogEntry *)catEntry {
	return [self dataFromFileInNotesDirectory:childRef forFilename: (__bridge NSString *)catEntry.filename];
}

- (NSMutableData *)dataFromFileInNotesDirectory:(FSRef *)childRef forFilename:(NSString *)filename {
	UniChar chars[256];
	OSStatus err = [self refreshFileRefIfNecessary:childRef withName:filename charsBuffer:chars];
	if (noErr != err) return nil;

	NSError *nsErr = nil;
	NSURL *URL = [NSURL URLWithFSRef: childRef];
	NSMutableData *data = [NSMutableData dataWithContentsOfURL: URL options: NSDataReadingUncached error: &nsErr];
	if (!data) NSLog(@"%@: error %@", NSStringFromSelector(_cmd), nsErr);
	return data;
}

- (OSStatus)createFileIfNotPresentInNotesDirectory:(FSRef *)childRef forFilename:(NSString *)filename fileWasCreated:(BOOL *)created {

	return FSCreateFileIfNotPresentInDirectory(&noteDirectoryRef, childRef, (__bridge CFStringRef) filename, (Boolean *) created);
}

//either name or destRef must be valid; destRef is declared invalid by filling the struct with 0

- (NSURL *)writeDataToNotesDirectory:(NSData *)data withName:(NSString *)filename verifyUsingBlock:(BOOL(^)(NSURL *, NSError **))block error:(NSError **)outError {
	NSURL *notesDatabaseURL = [self.noteDirectoryURL URLByAppendingPathComponent: filename];

	NSError *error = nil;

	NSURL *temporaryDatabaseFolder = [self.fileManager URLForDirectory: NSItemReplacementDirectory inDomain: NSUserDomainMask appropriateForURL: notesDatabaseURL create: YES error:&error];
	if (!temporaryDatabaseFolder) {
		NSLog(@"Error securing temporary file: %@", error);
		if (outError) *outError = error;
		return nil;
	}

	NSURL *temporaryDatabaseURL = [temporaryDatabaseFolder URLByAppendingPathComponent: filename];
	
	// write data to temporary file
	if (![data writeToURL: temporaryDatabaseURL options:0 error: &error]) {
		NSLog(@"Error writing to temporary file: %@", error);
		if (outError) *outError = error;
		return nil;
	}

	// before we try to swap the data contents of this temp file with the (possibly even soon-to-be-created) Notes & Settings file,
	// try to read it back and see if it can be decrypted and decoded:
	if (block) {
		if (!block(temporaryDatabaseURL, &error)) {
			NSLog(@"couldn't verify written notes, so not continuing to save");
			[self.fileManager removeItemAtURL: temporaryDatabaseURL error: NULL];
			if (outError) *outError = error;
			return nil;
		}
	}

	// if it exists, swap; otherwise, just move
	if ([notesDatabaseURL checkResourceIsReachableAndReturnError: NULL]) {
		if (![self.fileManager replaceItemAtURL: notesDatabaseURL withItemAtURL: temporaryDatabaseURL backupItemName: nil options: 0 resultingItemURL: &notesDatabaseURL error: &error]) {
			NSLog(@"error exchanging contents of temporary file with destination file %@: %@", filename, error);
			if (outError) *outError = error;
			return nil;
		}
	} else {
		if (![self.fileManager moveItemAtURL: temporaryDatabaseURL toURL: notesDatabaseURL error: &error]) {
			NSLog(@"error moving temporary file to destination file %@: %@", filename, error);
			if (outError) *outError = error;
			return nil;
		}
	}
	
	return [notesDatabaseURL fileReferenceURL];
}

- (void)notifyOfChangedTrash {
	NSURL *sillyURL = [NSURL fileURLWithPath: [NSTemporaryDirectory() stringByAppendingPathComponent:(__bridge_transfer NSString *)CreateRandomizedFileName()]];
	[self.fileManager createDirectoryAtURL: sillyURL withIntermediateDirectories: YES attributes: nil error: NULL];
	[self.fileManager trashItemAtURL: sillyURL resultingItemURL: NULL error: NULL];
}

+ (OSStatus)trashFolderRef:(FSRef *)trashRef forChild:(FSRef *)childRef {
	FSVolumeRefNum volume = kOnAppropriateDisk;
	FSCatalogInfo info;
	// get the volume the file resides on and use this as the base for finding the trash folder
	// since each volume will contain its own trash folder...

	if (FSGetCatalogInfo(childRef, kFSCatInfoVolume, &info, NULL, NULL, NULL) == noErr)
		volume = info.volume;
	// go ahead and find the trash folder on that volume.
	// the trash folder for the current user may not yet exist on that volume, so ask to automatically create it

	return FSFindFolder(volume, kTrashFolderType, kCreateFolder, trashRef);
}

- (NSURL *)moveFileToTrash:(NSURL *)childURL forFilename:(NSString *)filename error:(out NSError **)outError {
	NSError *error = nil;

	if ((childURL = [self refreshFileURLIfNecessary: childURL withName: filename error: &error])) {
		NSURL *outURL = nil;
		if (([self.fileManager trashItemAtURL: childURL resultingItemURL: &outURL error: &error])) {

			if (![self.noteDirectoryURL setResourceValue: [NSDate date] forKey: NSURLContentModificationDateKey error: &error]) {
				NSLog(@"couldn't touch modification date of file's parent folder: error %@", error);
			}
			return outURL;
		}
	}

	if (outError) *outError = error;
	return nil;
}

- (long)blockSize {
	if (!blockSize) {
		long iosize = 0;

		struct statfs *sfsb = StatFSVolumeInfo(self);
		if (sfsb) iosize = sfsb->f_iosize;

		blockSize = MAX(iosize, 16 * 1024);
	}

	return blockSize;
}

- (NSURL *)trashFolderForURL:(NSURL *)URL error:(out NSError *__autoreleasing *)outError {
	return [self.fileManager URLForDirectory: NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL: URL create:YES error: outError];
}

@end
