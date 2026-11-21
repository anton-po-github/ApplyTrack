# apply_track

A new Flutter project.

## Follow-up reminders

A proposal with a follow-up date gets a phone reminder at 09:00 local time on
that date. There is no reminder when the status is Won or Lost, when there is
no date, or when 09:00 on that date has already passed.

Reminders work on Android and iOS only. The web version shows none.

## Known limits

- Reminders for proposals outside the first page of the list come back only
  when you save them again. The API has no `dueBy` filter, so the app cannot
  ask the server for all due proposals.
- On some Samsung phones reminders can be late until the app is opened again.
  Set the battery use of the app to Unrestricted (Settings > Apps >
  ApplyTrack > Battery) and take it out of Sleeping apps.
- After a new sign in, reminders outside the first page of the list are gone
  until you save those proposals again.
- If you move a follow-up date into the past on another device, the old
  reminder on this phone can still come once.
- A reminder that came stays on the phone until you swipe it away. Opening
  the app does not remove it.
- A reminder does not wake the screen. This depends on the phone settings
  (for example Always On Display or Edge lighting).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
