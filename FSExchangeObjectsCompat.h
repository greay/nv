/*
 *  FSExchangeObjectsCompat.h
 *  Notation
 *
 */

#include <Carbon/Carbon.h>

extern uint32_t volumeCapabilities(const char *path);

OSErr FSExchangeObjectsEmulate(const FSRef *sourceRef, const FSRef *destRef, FSRef *newSourceRef, FSRef *newDestRef);

Boolean VolumeOfFSRefSupportsExchangeObjects(const FSRef *fsRef);
