# Local record storage

Implementation choice, 2026-11-14. The owner requested checklist group 3 Step 1. This choice selects storage for this implementation; independent verification and production readiness remain open.

## Selection and alternatives

Use the operating system's SQLite library behind an app-owned repository interface. SQLite supplies transactions, constraints and a portable format. MemoryOS owns source text, stable UUIDs, timestamps, corrections and links. External AI/search indexes will remain replaceable derived data.

| Option | Fit and tradeoff |
| --- | --- |
| System SQLite | Selected. Explicit schema, atomic transactions, foreign keys and independent core/adapter tests. The small C adapter needs careful binding, lifecycle and migration review. OS updates determine the SQLite revision; record its runtime version rather than claiming a separately pinned SDK. |
| SwiftData / Core Data | Valid native alternatives. Object graph support is useful, but the first storage contract benefits from explicit SQL constraints and portable app-owned archive tests. No claim that these frameworks cannot preserve data. |
| JSON files as canonical store | Useful portable archive format. Coordinating corrections, links, concurrent writes and transactional recovery would require additional custom storage rules. |
| Obsidian/Markdown vault | A future explicit import/export connection. A vault is not the only copy of these records. File access and conflict behavior remain unresolved. |

Sources checked on 2026-11-14: [SQLite atomic commit](https://www.sqlite.org/atomiccommit.html), [foreign keys](https://www.sqlite.org/foreignkeys.html), [schema version pragma](https://www.sqlite.org/pragma.html#pragma_user_version), [SQLite public-domain dedication](https://www.sqlite.org/copyright.html), [Apple application-support storage](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively), [complete file protection](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete), and [backup exclusion](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup). These explain library/platform behavior; they do not prove this app's implementation or commercial compliance.

## Ownership and schema

Canonical store: the private app sandbox at `Library/Application Support/LocalRecords/records.sqlite`. Keep records outside caches and outside derived provider indexes. `LocalStoreComposition` injects `LocalStoreProvider`, whose actor creates the directory with complete iOS Data Protection and excludes it from OS backup while cloud/automatic-backup policy remains undecided. The provider performs filesystem/database setup off the UI actor and caches only successful setup. The ViewModel calls the app-owned `LocalMemorySessionProvider` interface; Reload retries initial failure while preserving unsaved input. The app does not connect to a server. User-selected manual export can use an external Files location after an explicit notice.

The app-owned local package has `MemoryCore` and `MemorySQLite` targets. `CSQLite` links the SDK system library. No third-party package download, copied upstream implementation, custom engine repository or new runtime provider enters this step. Package.swift uses Swift 6, iOS 18+, and macOS 14+ for host contract tests. No remote dependency means no Package.resolved pin is needed. SQLite has no external transitive package dependency in this build.

Schema version 1 stores records (UUID, kind, original text, creation and optional deletion time), ordered append-only corrections, and undirected links with stable IDs and foreign-key endpoints. Current text comes from the newest correction, or the original. No AI interpretation or confirmed-fact inference occurs. User-entered person/project/idea text is a manual record. Sample catalog records remain separate and labeled; the app does not turn fictional demo data into owner data.

The Files picker forwards its selected URL to the ViewModel, which calls `RestoreArchiveFromFile`. That use case uses the app-owned `ArchiveDataReader` contract and the injected `LocalArchiveFileReader` adapter for security-scoped, bounded file reads before restoring through the repository. Views and ViewModels do not read the file or call SQLite.

The adapter enables foreign keys, a bounded busy timeout and FULL synchronization. Each operation owns its connection inside the actor and closes it after the operation. It initializes a new empty database transactionally. It rejects newer/unknown schemas and existing foreign tables instead of resetting data. Future version upgrades require explicit migrations and affected recovery tests. Version 0 to 1 is the only migration in this step.

## Editing, deletion and recovery

Creation preserves exact UTF-8 text, including leading/trailing whitespace. Whitespace-only and texts over 100,000 UTF-8 bytes fail. Corrections append history and retain immutable originals and IDs. Record/revision equality, correction no-op checks and archive consistency/conflict checks compare UTF-8 bytes, including canonically equivalent Arabic/Latin forms. The ViewModel also uses exact bytes before clearing a submitted draft. Link creation rejects a missing, identical or trashed endpoint; duplicate/reversed links keep one connection. Trashing keeps history and links; active browsing hides links to trashed records. Restore from Trash makes the same identity visible again.

Trash is reversible local removal, not permanent erasure. This step has no purge control, deletion propagation, provider-index cleanup or sync. A future permanent-deletion design must cover backups, derived indexes and applicable retention obligations before affected production release. Old manual backups retain their exported data. Uninstall removes sandbox records; export before uninstalling.

Manual backup/export is versioned JSON. It includes originals, corrections, stable IDs, links and Trash. It contains readable personal content without a separate encryption password; the UI explains this before a Files picker. Keep it in a trusted location. This is not an encrypted cloud backup or a key-recovery design.

Restore reads a user-selected archive, validates version, sizes, uniqueness, correction consistency and link endpoints, then merges missing records in a transaction. An identical restore is idempotent. A conflicting existing record/link rejects the whole restore and preserves current data; it does not replace later corrections or resurrect newer Trash. To recover an older conflicting state, retain the archive and obtain an explicit future conflict-resolution/export design. Reinstall plus restore into a fresh store remains possible after making a valid backup.

Limits: 10,000 records; 50,000 links; 1,000 corrections per record; 100,000 UTF-8 bytes per text; 50 MiB per JSON archive. Aggregate limits also cap retained original/correction text at 4 MiB and all corrections at 20,000, including Trash. The adapter checks aggregate counts and byte sizes before loading a snapshot and before committing writes. These prototype bounds prevent unrestricted memory growth; physical-device measurements still need to validate them. JSON escape overhead and metadata count toward the separate 50 MiB archive cap. Export partitioning/streaming and larger-store support remain future work. Imports need enough free memory and disk for validation plus the transaction. Disk-full, locked storage and corruption report errors; the app keeps input and does not silently switch to temporary storage.

## Verification boundary

Contract tests cover reopen, multilingual text, corrections, links, transactional failure and archive recovery. App tests cover feature state and the connected UI. Physical passcode/lock protection, process interruption under real device conditions, supported-device performance and backup recovery on the owner's iPhone remain required verification. A simulator or an unsigned build cannot establish them. The task record owns exact source and test results. Step 2 closed Unicode-preservation and initial-open retry defects. Local host/simulator checks pass; physical protection/performance, minimum-OS runtime and unresolved accessibility checks still block passage.
