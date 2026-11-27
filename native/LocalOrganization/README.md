# Local organization

This app-owned package stores birthdays, exact reminder approvals, organization rules, and named views. It is part of the MemoryOS app repository. It has no model, network client, or SwiftUI dependency. OS permission and delivery APIs stay in injected native adapters.

`OrganizationCore` contains the models and serialized `OrganizationUseCases` actor. It depends on `MemoryCore` for app-owned people and entries. `OrganizationPersistence` supplies `FileOrganizationRepository`; iOS writes are atomic, use complete file protection, and exclude the containing directory from backup. The app composition root injects the repository, personal-memory use cases, and a `BirthdayScheduling` adapter. Views call their ViewModel, which calls these use cases.

## Workflows

- Save known birthday components with `saveBirthday`; unknown components stay unknown. `previewSchedule` returns the exact person, date, delivery method, time, timezone, and recurrence to review. `approve` requires explicit approval of that current proposal.
- Persist schedule intent before OS writes. `reconcile` inspects approved or uncertain outcomes. `disableBirthday` records cancellation before removal. A failed removal stays pending; callers must not report a completed cancellation.
- Call `refreshReferences` after personal-memory changes. It follows explicit person merges, retains reversible filter/receipt provenance, prunes erased entry references, and cancels reminders for retired or missing people. It does not transfer reminder approval.
- Present the full `MergedBirthdayReview` and pass that same value to `resolveMergedBirthday` after an explicit date choice. A changed target, date choice, or revision requires a fresh review. Both birthday histories remain inspectable.
- Save and inspect rules, then call `testRule` and `applyRule` explicitly. A revision-bound preview cannot apply after relevant changes. `undoRule` checks expected entry metadata and refuses to overwrite a later manual edit.
- `saveView` and `entries(in:)` store a filter over current entries, not copied records. A missing-person filter stays restricted to its original ID and returns no matches. Editing it to another scope requires a user action.

## Persistence and recovery

The current organization format is 5. Valid formats 1–4 migrate without changing stable IDs or inventing missing history. A migration cannot reconstruct provenance already lost by an older writer. Unsupported, malformed, oversized, or conflicting data fails without resetting the store.

The bounded unavailable-profile ledger records inert references, not new person identities. Missing-person schedules must be disabled or awaiting cancellation; an OS reminder may still deliver until removal is verified. Operative rule-undo changes cannot reference a missing person. Removed references also leave the ledger. Restore validates these rules before normalization, so a malformed archive cannot use the ledger to broaden a filter or install a reminder.

Use `exportArchive` for organization data. Restore the corresponding personal-memory archive first, then use `restoreArchive` or the file-reader boundary `RestoreOrganizationArchive` into an empty organization store. Restore checks referenced IDs and preserves approval history with delivery disabled. It does not request permission or install schedules. A restored or reappearing person requires a new exact reminder approval.

Archives are limited to 8 MiB. A snapshot supports up to 2,000 birthdays, 2,000 schedules, 100 rules, 100 views, 50 rule applications, and 4,000 retained unavailable profile IDs. The model validates additional field and reference bounds. Surface typed `OrganizationError` values without discarding input; `stalePreview`, `approvalRequired`, `cancellationPending`, `missingReferences`, and `storage` require different recovery actions.

## Verification

From the repository root:

```sh
swift test --package-path native/LocalOrganization -c release
```

Package tests cover state transitions, migration, restore, explicit approval, failed OS outcomes, deletion/merge/undo propagation, stale reviews, and later manual edits. Native adapter tests separately exercise UserNotifications and EventKit. Simulator results do not establish physical delivery or locked-device behavior. Current results and remaining model/device gates are in the [groups 8–9 task record](../../docs/tasks/2026-11-18-understanding-organization.md).
