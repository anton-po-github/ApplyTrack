import 'dart:convert';

const int _offsetBasis = 0x811C9DC5;
const int _mask32 = 0xFFFFFFFF;
const int _mask31 = 0x7FFFFFFF;

/// A stable notification id for a proposal GUID.
///
/// Notification ids are `int`, but proposal ids are GUID strings. This is
/// FNV-1a (32 bit) over the lower-case UTF-8 bytes, cut to 31 bits so the id
/// is never negative. The same GUID always gives the same id, in every app
/// run and in any letter case. If the rule changes, old reminders can no
/// longer be cancelled, so do not change it.
///
/// `String.hashCode` is not used: it can differ between app runs.
///
/// Two GUIDs can share an id, but the chance is tiny (31 bits).
int notificationIdFor(String guid) {
  var hash = _offsetBasis;
  for (final byte in utf8.encode(guid.toLowerCase())) {
    hash ^= byte;
    // hash * 16777619 (the FNV prime), written as shifts and adds. Every
    // step stays below 2^35, so the result is exact on the web too.
    hash =
        (hash +
            (hash << 1) +
            (hash << 4) +
            (hash << 7) +
            (hash << 8) +
            (hash << 24)) &
        _mask32;
  }
  return hash & _mask31;
}
