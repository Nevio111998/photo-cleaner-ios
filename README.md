# Photo Cleaner for iOS

**Native iPhone photo-cleanup app built with SwiftUI, PhotoKit and Swift Concurrency.** Photo Cleaner helps identify exact duplicates and visually similar photos, compare them, and review potential deletions before anything is removed.

**Status:** Functional personal-use application, installed via Xcode and successfully used on a physical iPhone. In real-world use, the developer reviewed and removed **over 1,000 duplicate or similar photos**. This is a practical usage report, not a formal benchmark or a claim of broad device compatibility.

No accounts, ads, subscriptions, third-party Swift packages or paid APIs are required. Photo analysis takes place on-device; missing photo resources may be fetched from the owner's iCloud Photos library through Apple's PhotoKit. The app does not upload photos to a developer-operated server.

## Highlights

- **Two-stage duplicate detection:** Analyze lightweight 256px previews first, then stream and hash original resources with SHA-256 for potential byte-identical duplicates. Avoid unnecessary full-resolution downloads.
- **Similar-photo grouping:** Use local 64-bit difference hashes (dHash), an 8×8 brightness comparison, aspect ratio and a configurable Hamming-distance threshold (2–10; default 6). Comparisons are restricted to photos taken within 24 hours of the group representative.
- **Human-in-the-loop review:** Compare photos, use swipe gestures or buttons to keep or mark images, undo the most recent decision, and inspect a final deletion queue.
- **Deletion safeguards:** Revalidate the selected assets and request explicit confirmation before PhotoKit performs a deletion. No automatic photo deletion.
- **Local persistence:** Cache analysis features and review decisions, reuse unchanged results, and support interrupted scanning without maintaining a duplicate photo library.
- **Privacy-aware design:** No custom backend or photo uploads to third-party services.

## How it works

```text
PhotoKit library
      |
      v
256px preview analysis
      |                  \
      |                   -> Similarity grouping (dHash + brightness)
      v
Exact-duplicate candidates
      |
      v
SHA-256 verification of original resources
      |
      v
Groups and side-by-side review
      |
      v
User-selected deletion queue
      |
      v
Asset revalidation + explicit confirmation
      |
      v
PhotoKit deletion request
```

A photo marked *similar* is **not necessarily a duplicate**. Recommendations based on sharpness, resolution and exposure are heuristic and do not assess expressions, composition or artistic value. The user remains responsible for choosing what to delete.

## Technology and architecture

| Technology | Purpose |
| --- | --- |
| Swift / SwiftUI | Native iPhone user interface |
| Apple PhotoKit | Access to the photo library, iCloud-backed resources and confirmed deletion |
| Swift Concurrency / actors | Scanning, cancellation and progress reporting |
| SHA-256 | Verification of byte-identical original resources |
| dHash and image features | Local visual similarity matching |
| JSON / Application Support | Protected local cache and persisted decisions |
| XCTest / GitHub Actions | Test suite and prepared iOS build workflow |

| Component | Responsibility |
| --- | --- |
| `PhotoCleanerApp.swift` | Application entry point and lifecycle |
| `AppModel.swift` | UI state, review decisions and deletion confirmation |
| `Scanner.swift` | Sequential scan actor, cache reuse and progress reporting |
| `PhotoLibrary.swift` | PhotoKit access, thumbnails, resource streaming and image analysis |
| `Models.swift` | Data models, grouping and undo logic |
| `Persistence.swift` | Atomic local persistence and file protection |
| `Views.swift` | Scanning, grouping, swipe and review screens |
| `PhotoCleanerTests/` | Unit-test cases for grouping, undo and application data state |

## Real-device usage and testing

The app has been **installed and used on a real iPhone through Xcode**, including a successful personal cleanup of more than 1,000 duplicate or visually similar photos.

This demonstrates practical functionality on the tested device. It does **not** establish comprehensive testing across iOS versions, iPhone models, large photo libraries, every iCloud failure condition or all deletion edge cases. No device-wide performance benchmark is claimed.

The repository contains XCTest cases and a GitHub Actions workflow at `.github/workflows/ios.yml`. A passing automated CI run has **not been independently verified in this README**; inspect the repository's Actions tab for the current build and test status. See `docs/TESTING.md` for additional test scenarios, especially before working with important photos.

### Run the tests

In Xcode, open `PhotoCleaner.xcodeproj` and press **⌘U**. Alternatively, select an available simulator and run:

```sh
xcodebuild -list -project PhotoCleaner.xcodeproj
xcrun simctl list devices available
xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner \
  -destination 'platform=iOS Simulator,id=YOUR-SIMULATOR-UUID' \
  CODE_SIGNING_ALLOWED=NO
```

Optional static source validation (not a substitute for an Xcode build):

```sh
python3 -m pip install -r scripts/requirements-validation.txt
python3 scripts/validate_source.py
```

## Install on an iPhone

A **Mac with a compatible Xcode version**, an iPhone and an Apple Account are required. The GitHub repository alone cannot install the app.

1. Clone or download this repository, then open `PhotoCleaner.xcodeproj` in Xcode.
2. Under **Xcode → Settings → Accounts**, sign in with your Apple Account.
3. Select the **PhotoCleaner** target, enable **Automatically manage signing**, choose your team and set a unique bundle identifier.
4. Connect your iPhone, trust the computer and select the device as the run destination. Enable Developer Mode if iOS requests it.
5. Press **⌘R** to build and install.
6. Start with expendable test photos, verify the review and deletion workflow, and only then consider using it with your personal library.

A free Personal Team can be sufficient for testing on your own device, but its provisioning profiles have time limits and may require reinstalling or rebuilding the application.

## Privacy, limitations and safeguards

- **Exact duplicates:** “Exact” means identical resource bytes, not merely identical-looking content. Different metadata, edits or encodings can prevent an exact match.
- **Similar photos:** The current algorithm compares photos near one another in time; it is not a global semantic image search and does not perform face or expression recognition.
- **iCloud:** PhotoKit may download missing previews or original resources from the user's own iCloud library. Availability depends on connectivity and Apple services; system caching is possible.
- **Storage:** The application stores identifiers, metadata, hashes, image features and decisions—not its own copies of the original photographs. Undo history is limited to the current session.
- **Background execution:** Scanning is intended while the app is open. iOS may suspend the app in the background, and an in-progress resource request may complete before cancellation takes effect.
- **Performance:** Work is reduced using previews and time-window candidate filtering, but worst-case comparisons within dense time windows may still be quadratic; no universal speed or memory benchmark is claimed.
- **Deletion:** The app requires user review and confirmation. Deleted items normally enter Apple's *Recently Deleted* album, and iCloud Photos may synchronize deletions across devices. Always check your selection before confirming.

## Project scope

This project focuses deliberately on duplicate/similar-image detection and safe review. Additional categories such as videos, screenshots and large-file cleanup are potential future extensions, **not implemented features**.

Built as a practical personal software project showcasing native iOS development, image processing, resource-conscious algorithms, state management and cautious handling of destructive operations.
