TWEAK_NAME = ContactPrivacy
ContactPrivacy_FILES = Tweak.x
ContactPrivacy_FRAMEWORKS = Foundation CoreFoundation AddressBook
ContactPrivacy_PRIVATE_FRAMEWORKS = AppSupport
ContactPrivacy_LDFLAGS = -lsubstrate

ADDITIONAL_CFLAGS = -std=c99
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 3.0

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
