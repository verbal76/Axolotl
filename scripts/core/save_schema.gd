class_name SaveSchema
extends RefCounted
## SAVE COMPATIBILITY IDENTITY — format of persisted data (currently user://settings.cfg).
## Independent of GameVersion: bump only when the on-disk format changes. An OTA that writes
## SAVE_SCHEMA must still read everything from MIN_SAVE_SCHEMA upwards; before a migration,
## keep a pre-migration backup so a rollback to an older OTA stays possible.

const SAVE_SCHEMA := 1
const MIN_SAVE_SCHEMA := 1
