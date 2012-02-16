#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#include <substrate.h>
#include <pthread.h>

enum {
   kCFUserNotificationStopAlertLevel = 0,
   kCFUserNotificationNoteAlertLevel = 1,
   kCFUserNotificationCautionAlertLevel = 2,
   kCFUserNotificationPlainAlertLevel= 3
};

enum {
   kCFUserNotificationDefaultResponse = 0,
   kCFUserNotificationAlternateResponse = 1,
   kCFUserNotificationOtherResponse = 2,
   kCFUserNotificationCancelResponse = 3
};

SInt32 CFUserNotificationDisplayAlert (
   CFTimeInterval timeout,
   CFOptionFlags flags,
   CFURLRef iconURL,
   CFURLRef soundURL,
   CFURLRef localizationURL,
   CFStringRef alertHeader,
   CFStringRef alertMessage,
   CFStringRef defaultButtonTitle,
   CFStringRef alternateButtonTitle,
   CFStringRef otherButtonTitle,
   CFOptionFlags *responseFlags
);

typedef enum {
	AddressBookPermittedStatusUnknown,
	AddressBookPermittedStatusNo,
	AddressBookPermittedStatusYes,
} AddressBookPermittedStatus;

static AddressBookPermittedStatus status;
static CFErrorRef blockedError;
static CFArrayRef emptyArray;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

static bool IsAllowed()
{
	if (status == AddressBookPermittedStatusUnknown) {
		pthread_mutex_lock(&mutex);
		if (status == AddressBookPermittedStatusUnknown) {
			CFBundleRef mainBundle = CFBundleGetMainBundle();
			CFStringRef displayName = CFBundleGetValueForInfoDictionaryKey(mainBundle, CFSTR("CFBundleDisplayName")) ?: CFBundleGetValueForInfoDictionaryKey(mainBundle, CFSTR("CFBundleName")) ?: CFSTR("Unknown");
			CFStringRef title = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("“%@” Would Like To Access Your Contacts"), displayName);
			CFOptionFlags alertResult = kCFUserNotificationDefaultResponse;
			CFUserNotificationDisplayAlert(0.0, kCFUserNotificationNoteAlertLevel, NULL, NULL, NULL, title, CFSTR("Not all apps recover successfully from having their Contacts access revoked."), CFSTR("OK"), CFSTR("Don't Allow"), NULL, &alertResult);
			CFRelease(title);
			switch (alertResult) {
				case kCFUserNotificationAlternateResponse:
					status = AddressBookPermittedStatusNo;
					break;
				case kCFUserNotificationDefaultResponse:
					status = AddressBookPermittedStatusYes;
					break;
				default:
					break;
			}
		}
		pthread_mutex_unlock(&mutex);
	}
	return status == AddressBookPermittedStatusYes;
}

MSHook(ABAddressBookRef, ABAddressBookCreate, void)
{
	NSLog(@"ContactPrivacy: ABAddressBookCreate");
	IsAllowed();
	return _ABAddressBookCreate();
}

MSHook(bool, ABAddressBookAddRecord, ABAddressBookRef addressBook, ABRecordRef record, CFErrorRef *error)
{
	NSLog(@"ContactPrivacy: ABAddressBookAddRecord");
	if (IsAllowed())
		return _ABAddressBookAddRecord(addressBook, record, error);
	if (error)
		*error = (CFErrorRef)CFRetain(blockedError);
	return false;
}

MSHook(bool, ABAddressBookHasUnsavedChanges, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookHasUnsavedChanges");
	if (IsAllowed())
		return _ABAddressBookHasUnsavedChanges(addressBook);
	return false;
}

MSHook(void, ABAddressBookRegisterExternalChangeCallback, ABAddressBookRef addressBook, ABExternalChangeCallback callback, void *context)
{
NSLog(@"ContactPrivacy: ABAddressBookRegisterExternalChangeCallback");
	if (IsAllowed())
		_ABAddressBookRegisterExternalChangeCallback(addressBook, callback, context);
}

MSHook(bool, ABAddressBookRemoveRecord, ABAddressBookRef addressBook, ABRecordRef record, CFErrorRef *error)
{
NSLog(@"ContactPrivacy: ABAddressBookRemoveRecord");
	if (IsAllowed())
		return _ABAddressBookRemoveRecord(addressBook, record, error);
	if (error)
		*error = (CFErrorRef)CFRetain(blockedError);
	return false;
}

MSHook(void, ABAddressBookRevert, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookRevert");
	if (IsAllowed())
		_ABAddressBookRevert(addressBook);
}

MSHook(bool, ABAddressBookSave, ABAddressBookRef addressBook, CFErrorRef *error)
{
NSLog(@"ContactPrivacy: ABAddressBookSave");
	if (IsAllowed())
		return _ABAddressBookSave(addressBook, error);
	if (error)
		*error = (CFErrorRef)CFRetain(blockedError);
	return false;
}

MSHook(void, ABAddressBookUnregisterExternalChangeCallback, ABAddressBookRef addressBook, ABExternalChangeCallback callback, void *context)
{
NSLog(@"ContactPrivacy: ABAddressBookUnregisterExternalChangeCallback");
	if (IsAllowed())
		_ABAddressBookUnregisterExternalChangeCallback(addressBook, callback, context);
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllGroups, ABAddressBookRef addressBook)
{
	NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllGroups");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllGroups(addressBook);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllGroupsInSource, ABAddressBookRef addressBook, ABRecordRef source)
{
	NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllGroupsInSource");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllGroupsInSource(addressBook, source);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFIndex, ABAddressBookGetGroupCount, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookGetGroupCount");
	if (IsAllowed())
		return _ABAddressBookGetGroupCount(addressBook);
	return 0;
}

MSHook(ABRecordRef, ABAddressBookGetGroupWithRecordID, ABAddressBookRef addressBook, ABRecordID recordID)
{
NSLog(@"ContactPrivacy: ABAddressBookGetGroupWithRecordID");
	if (IsAllowed())
		return _ABAddressBookGetGroupWithRecordID(addressBook, recordID);
	return NULL;
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllPeople, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllPeople");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllPeople(addressBook);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllPeopleInSource, ABAddressBookRef addressBook, ABRecordRef source)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllPeopleInSource");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllPeopleInSource(addressBook, source);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering, ABAddressBookRef addressBook, ABRecordRef source, ABPersonSortOrdering sortOrdering)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, source, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFArrayRef, ABAddressBookCopyPeopleWithName, ABAddressBookRef addressBook, CFStringRef name)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyPeopleWithName");
	if (IsAllowed())
		return _ABAddressBookCopyPeopleWithName(addressBook, name);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFIndex, ABAddressBookGetPersonCount, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookGetPersonCount");
	if (IsAllowed())
		return _ABAddressBookGetPersonCount(addressBook);
	return 0;
}

MSHook(ABRecordRef, ABAddressBookGetPersonWithRecordID, ABAddressBookRef addressBook, ABRecordID recordID)
{
NSLog(@"ContactPrivacy: ABAddressBookGetPersonWithRecordID");
	if (IsAllowed())
		return _ABAddressBookGetPersonWithRecordID(addressBook, recordID);
	return NULL;
}

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllSources, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllSources");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllSources(addressBook);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(ABRecordRef, ABAddressBookCopyDefaultSource, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyDefaultSource");
	if (IsAllowed())
		return _ABAddressBookCopyDefaultSource(addressBook);
	return NULL;
}

MSHook(ABRecordRef, ABAddressBookGetSourceWithRecordID, ABAddressBookRef addressBook, ABRecordID sourceID)
{
	NSLog(@"ContactPrivacy: ABAddressBookGetSourceWithRecordID");
	if (IsAllowed())
		return _ABAddressBookGetSourceWithRecordID(addressBook, sourceID);
	return NULL;
}

MSHook(bool, ABGroupAddMember, ABRecordRef group, ABRecordRef member, CFErrorRef *error)
{
	NSLog(@"ContactPrivacy: ABGroupAddMember");
	if (IsAllowed())
		return _ABGroupAddMember(group, member, error);
	if (error)
		*error = (CFErrorRef)CFRetain(blockedError);
	return false;
}

MSHook(bool, ABGroupRemoveMember, ABRecordRef group, ABRecordRef member, CFErrorRef *error)
{
	NSLog(@"ContactPrivacy: ABGroupRemoveMember");
	if (IsAllowed())
		return _ABGroupRemoveMember(group, member, error);
	if (error)
		*error = (CFErrorRef)CFRetain(blockedError);
	return false;
}

MSHook(CFArrayRef, ABGroupCopyArrayOfAllMembers, ABRecordRef group)
{
	NSLog(@"ContactPrivacy: ABGroupCopyArrayOfAllMembers");
	if (IsAllowed())
		return _ABGroupCopyArrayOfAllMembers(group);
	return (CFArrayRef)CFRetain(emptyArray);
}

MSHook(CFArrayRef, ABGroupCopyArrayOfAllMembersWithSortOrdering, ABRecordRef group, ABPersonSortOrdering sortOrdering)
{
	NSLog(@"ContactPrivacy: ABGroupCopyArrayOfAllMembersWithSortOrdering");
	if (IsAllowed())
		return _ABGroupCopyArrayOfAllMembersWithSortOrdering(group, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

// Private APIs

extern CFArrayRef ABAddressBookCopyArrayOfAllPeopleInAccountWithSortOrdering(ABAddressBookRef addressBook, void *account, ABPersonSortOrdering sortOrdering);

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllPeopleInAccountWithSortOrdering, ABAddressBookRef addressBook, void *account, ABPersonSortOrdering sortOrdering)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllPeopleInAccountWithSortOrdering");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllPeopleInAccountWithSortOrdering(addressBook, account, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABAddressBookCopyArrayOfAllPeopleShowingLinksWithSortOrdering(ABAddressBookRef addressBook, int showingLinks, ABPersonSortOrdering sortOrdering);

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllPeopleShowingLinksWithSortOrdering, ABAddressBookRef addressBook, int showingLinks, ABPersonSortOrdering sortOrdering)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllPeopleShowingLinksWithSortOrdering");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllPeopleShowingLinksWithSortOrdering(addressBook, showingLinks, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABAddressBookCopyArrayOfAllSourcesWithAccountIdentifier(ABAddressBookRef addressBook, int accountIdentifier);

MSHook(CFArrayRef, ABAddressBookCopyArrayOfAllSourcesWithAccountIdentifier, ABAddressBookRef addressBook, int accountIdentifier)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyArrayOfAllSourcesWithAccountIdentifier");
	if (IsAllowed())
		return _ABAddressBookCopyArrayOfAllSourcesWithAccountIdentifier(addressBook, accountIdentifier);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern ABRecordRef ABAddressBookCopyLocalSource(ABAddressBookRef addressBook);

MSHook(ABRecordRef, ABAddressBookCopyLocalSource, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyLocalSource");
	if (IsAllowed())
		return _ABAddressBookCopyLocalSource(addressBook);
	return NULL;
}

extern ABRecordRef ABAddressBookCopyMe(ABAddressBookRef addressBook);

MSHook(ABRecordRef, ABAddressBookCopyMe, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABAddressBookCopyMe");
	if (IsAllowed())
		return _ABAddressBookCopyMe(addressBook);
	return NULL;
}

extern CFTypeRef ABAddressBookCopySourceWithAccountAndExternalIdentifiers(ABAddressBookRef addressBook, CFTypeRef source, CFTypeRef externalIdentifiers);

MSHook(CFTypeRef, ABAddressBookCopySourceWithAccountAndExternalIdentifiers, ABAddressBookRef addressBook, CFTypeRef source, CFTypeRef externalIdentifiers)
{
NSLog(@"ContactPrivacy: ABAddressBookCopySourceWithAccountAndExternalIdentifiers");
	if (IsAllowed())
		return _ABAddressBookCopySourceWithAccountAndExternalIdentifiers(addressBook, source, externalIdentifiers);
	return NULL;
}

extern ABAddressBookRef ABAddressBookCreateWithDatabaseDirectory(CFStringRef databaseDirectory);

MSHook(ABAddressBookRef, ABAddressBookCreateWithDatabaseDirectory, CFStringRef databaseDirectory)
{
	NSLog(@"ContactPrivacy: ABAddressBookCreateWithDatabaseDirectory");
	IsAllowed();
	return _ABAddressBookCreateWithDatabaseDirectory(databaseDirectory);
}

extern CFIndex ABCGetGroupCount(ABAddressBookRef addressBook);

MSHook(CFIndex, ABCGetGroupCount, ABAddressBookRef addressBook)
{
NSLog(@"ContactPrivacy: ABCGetGroupCount");
	if (IsAllowed())
		return _ABCGetGroupCount(addressBook);
	return 0;
}

extern CFArrayRef ABCCopyArrayOfAllGroupsInSource(ABAddressBookRef addressBook, ABRecordRef source);

MSHook(CFArrayRef, ABCCopyArrayOfAllGroupsInSource, ABAddressBookRef addressBook, ABRecordRef source)
{
	NSLog(@"ContactPrivacy: ABCCopyArrayOfAllGroupsInSource");
	if (IsAllowed())
		return _ABCCopyArrayOfAllGroupsInSource(addressBook, source);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCCopyArrayOfAllPeopleInSourceWithSortOrdering(ABAddressBookRef addressBook, ABRecordRef source, ABPersonSortOrdering sortOrdering);

MSHook(CFArrayRef, ABCCopyArrayOfAllPeopleInSourceWithSortOrdering, ABAddressBookRef addressBook, ABRecordRef source, ABPersonSortOrdering sortOrdering)
{
NSLog(@"ContactPrivacy: ABCCopyArrayOfAllPeopleInSourceWithSortOrdering");
	if (IsAllowed())
		return _ABCCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, source, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFIndex ABCGetPersonCountInSourceShowingLinks(ABAddressBookRef addressBook, ABRecordRef source, int showingLinks);

MSHook(CFIndex, ABCGetPersonCountInSourceShowingLinks, ABAddressBookRef addressBook, ABRecordRef source, int showingLinks)
{
	NSLog(@"ContactPrivacy: ABCGetPersonCountInSourceShowingLinks");
	if (IsAllowed())
		return _ABCGetPersonCountInSourceShowingLinks(addressBook, source, showingLinks);
	return 0;
}

extern ABRecordRef ABCPersonGetRecordForUniqueID(ABAddressBookRef addressBook, ABRecordID recordID);

MSHook(ABRecordRef, ABCPersonGetRecordForUniqueID, ABAddressBookRef addressBook, ABRecordID recordID)
{
	NSLog(@"ContactPrivacy: ABCPersonGetRecordForUniqueID");
	if (IsAllowed())
		return _ABCPersonGetRecordForUniqueID(addressBook, recordID);
	return NULL;
}

extern CFArrayRef ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources(ABAddressBookRef addressBook, bool includingDisabled);

MSHook(CFArrayRef, ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources, ABAddressBookRef addressBook, bool includingDisabled)
{
NSLog(@"ContactPrivacy: ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources");
	if (IsAllowed())
		return _ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources(addressBook, includingDisabled);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern ABRecordRef ABCSourceGetRecordForUniqueID(ABAddressBookRef addressBook, ABRecordID sourceID);

MSHook(ABRecordRef, ABCSourceGetRecordForUniqueID, ABAddressBookRef addressBook, ABRecordID sourceID)
{
	NSLog(@"ContactPrivacy: ABCSourceGetRecordForUniqueID");
	if (IsAllowed())
		return _ABCSourceGetRecordForUniqueID(addressBook, sourceID);
	return NULL;
}

extern CFArrayRef ABCGroupCopyArrayFromProperty(ABRecordRef group, CFStringRef property);

MSHook(CFArrayRef, ABCGroupCopyArrayFromProperty, ABRecordRef group, CFStringRef property)
{
	NSLog(@"ContactPrivacy: ABCGroupCopyArrayFromProperty");
	if (IsAllowed())
		return _ABCGroupCopyArrayFromProperty(group, property);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCGroupCopyArrayOfAllMembers(ABRecordRef group, CFStringRef property);

MSHook(CFArrayRef, ABCGroupCopyArrayOfAllMembers, ABRecordRef group, CFStringRef property)
{
	NSLog(@"ContactPrivacy: ABCGroupCopyArrayOfAllMembers");
	if (IsAllowed())
		return _ABCGroupCopyArrayOfAllMembers(group, property);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCGroupCopyArrayOfAllMembersWithSortOrdering(ABRecordRef group, CFStringRef property, ABPersonSortOrdering sortOrdering);

MSHook(CFArrayRef, ABCGroupCopyArrayOfAllMembersWithSortOrdering, ABRecordRef group, CFStringRef property, ABPersonSortOrdering sortOrdering)
{
	NSLog(@"ContactPrivacy: ABCGroupCopyArrayOfAllMembersWithSortOrdering");
	if (IsAllowed())
		return _ABCGroupCopyArrayOfAllMembersWithSortOrdering(group, property, sortOrdering);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks(ABAddressBookRef addressBook, ABPersonSortOrdering sortOrdering, bool showingPersonLinks);

MSHook(CFArrayRef, ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks, ABAddressBookRef addressBook, ABPersonSortOrdering sortOrdering, bool showingPersonLinks)
{
	NSLog(@"ContactPrivacy: ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks");
	if (IsAllowed())
		return _ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks(addressBook, sortOrdering, showingPersonLinks);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCCopyArrayOfPeopleInSourceAtOffset(ABRecordRef source, CFIndex offset, CFIndex length);

MSHook(CFArrayRef, ABCCopyArrayOfPeopleInSourceAtOffset, ABRecordRef source, CFIndex offset, CFIndex length)
{
	NSLog(@"ContactPrivacy: ABCCopyArrayOfPeopleInSourceAtOffset");
	if (IsAllowed())
		return _ABCCopyArrayOfPeopleInSourceAtOffset(source, offset, length);
	return (CFArrayRef)CFRetain(emptyArray);
}

extern CFArrayRef ABCCopyArrayOfPeopleShowingLinksAtOffset(ABRecordRef source, bool showingLinks, CFIndex offset, CFIndex length);

MSHook(CFArrayRef, ABCCopyArrayOfPeopleShowingLinksAtOffset, ABRecordRef source, bool showingLinks, CFIndex offset, CFIndex length)
{
	NSLog(@"ContactPrivacy: ABCCopyArrayOfPeopleShowingLinksAtOffset");
	if (IsAllowed())
		return _ABCCopyArrayOfPeopleShowingLinksAtOffset(source, showingLinks, offset, length);
	return (CFArrayRef)CFRetain(emptyArray);
}

#define HOOK(name) MSHookFunction(&name, $##name, (void **)&_##name)

%ctor {
	if (dlopen("/System/Library/CoreServices/SpringBoard.app/SpringBoard", RTLD_NOLOAD)) {
	} else {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		if ([[[NSBundle mainBundle] bundlePath] hasPrefix:@"/var/mobile/Applications/"]) {
			blockedError = CFErrorCreate(kCFAllocatorDefault, CFSTR("com.rpetrich.contactprivacy"), 0, NULL);
			const void *value = NULL;
			emptyArray = CFArrayCreate(kCFAllocatorDefault, &value, 0, &kCFTypeArrayCallBacks);
			/*HOOK(ABAddressBookCreate);*/
			//HOOK(ABAddressBookAddRecord);
			//HOOK(ABAddressBookHasUnsavedChanges);
			//HOOK(ABAddressBookRegisterExternalChangeCallback);
			//HOOK(ABAddressBookRemoveRecord);
			//HOOK(ABAddressBookRevert);
			HOOK(ABAddressBookSave);
			//HOOK(ABAddressBookUnregisterExternalChangeCallback);
			//HOOK(ABAddressBookCopyArrayOfAllGroups); // Actually implemented by ABCCopyArrayOfAllGroups
			//HOOK(ABAddressBookCopyArrayOfAllGroupsInSource); // Actually implemented by ABCCopyArrayOfAllGroupsInSource
			//HOOK(ABAddressBookGetGroupCount); // Actually implemented by ABCGetGroupCount
			HOOK(ABAddressBookGetGroupWithRecordID);
			//HOOK(ABAddressBookCopyArrayOfAllPeople); // Actually implemented by ABCCopyArrayOfAllPeople
			//HOOK(ABAddressBookCopyArrayOfAllPeopleInSource); // Actually implemented by ABCCopyArrayOfAllPeopleInSource
			//HOOK(ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering); // Actually implemented by ABCCopyArrayOfAllPeopleInSourceWithSortOrdering
			HOOK(ABAddressBookCopyPeopleWithName);
			//HOOK(ABAddressBookGetPersonCount); // Actually implemented by ABCGetPersonCountInSourceShowingLinks
			//HOOK(ABAddressBookGetPersonWithRecordID); // Actually implemented by ABCPersonGetRecordForUniqueID
			//HOOK(ABAddressBookCopyArrayOfAllSources); // Actually implemented by ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources
			HOOK(ABAddressBookCopyDefaultSource);
			//HOOK(ABAddressBookGetSourceWithRecordID); // Actually implemented by ABCSourceGetRecordForUniqueID
			//HOOK(ABGroupAddMember);
			//HOOK(ABGroupRemoveMember);
			//HOOK(ABGroupCopyArrayOfAllMembers); // Actually implemented by ABCGroupCopyArrayFromProperty
			//HOOK(ABGroupCopyArrayOfAllMembersWithSortOrdering); // Actually implemented by ABCGroupCopyArrayFromPropertyWithSortOrdering
			// Private APIs
			HOOK(ABAddressBookCopyArrayOfAllPeopleInAccountWithSortOrdering);
			//HOOK(ABAddressBookCopyArrayOfAllPeopleShowingLinksWithSortOrdering); // Actually implemented by ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks
			HOOK(ABAddressBookCopyArrayOfAllSourcesWithAccountIdentifier);
			//HOOK(ABAddressBookCopyLocalSource); // Actually implemented by ABCSourceCopyLocalSource
			//HOOK(ABAddressBookCopyMe); // Triggered by any text input
			//HOOK(ABAddressBookCopySourceWithAccountAndExternalIdentifiers); // Actually implemented by ABCSourceCopySourceWithAccountAndExternalIdentifiers
			//HOOK(ABAddressBookCreateWithDatabaseDirectory);
			HOOK(ABCGetGroupCount);
			HOOK(ABCCopyArrayOfAllGroupsInSource);
			HOOK(ABCCopyArrayOfAllPeopleInSourceWithSortOrdering);
			HOOK(ABCGetPersonCountInSourceShowingLinks);
			//HOOK(ABCPersonGetRecordForUniqueID); // Triggered by any text input
			HOOK(ABCSourceCopyArrayOfAllSourcesIncludingDisabledSources);
			//HOOK(ABCSourceGetRecordForUniqueID); // Triggered by any text input
			HOOK(ABCGroupCopyArrayFromProperty);
			HOOK(ABCGroupCopyArrayOfAllMembers);
			HOOK(ABCGroupCopyArrayOfAllMembersWithSortOrdering);
			HOOK(ABCCopyArrayOfAllPeopleWithSortOrderingShowingPersonLinks);
			HOOK(ABCCopyArrayOfPeopleInSourceAtOffset);
			HOOK(ABCCopyArrayOfPeopleShowingLinksAtOffset);
		}
		[pool drain];
	}
}
