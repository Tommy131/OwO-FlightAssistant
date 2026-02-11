# X-Plane Database Path Resolution Fix

## Issue Description

**Date:** 2026-02-11
**Severity:** High (Blocking X-Plane 12 Database Loading)
**Status:** Fixed

### Symptoms

- Users selecting the X-Plane 12 root directory or `CIFP` directory experienced database loading failures.
- Logs indicated the parser was attempting to read `KAPT.dat` inside the `CIFP` folder instead of the standard `apt.dat` or `earth_nav.dat`.
- X-Plane 11 loading remained unaffected (as it typically doesn't use the new CIFP structure in the same way or lacks the conflicting file).

### Root Cause Analysis

The `XPlaneAptDatParser._findFileRecursively` method used a loose string matching condition:

```dart
entity.path.toLowerCase().endsWith(fileName.toLowerCase())
```

When searching for `apt.dat`, this condition incorrectly matched `KAPT.dat` (common in X-Plane 12 CIFP data). Since `KAPT.dat` is not a full airport database file, the validation failed.

## Implementation Details

### 1. Strict Filename Matching

Modified `_findFileRecursively` in `lib/apps/data/xplane_apt_dat_parser.dart` to use exact filename matching:

```dart
// Old
entity.path.toLowerCase().endsWith(fileName.toLowerCase())

// New
final name = entity.uri.pathSegments.last;
if (name.toLowerCase() == fileName.toLowerCase()) { ... }
```

### 2. Expanded Search Candidates

Added support for X-Plane 12's new global scenery path structure in `_findAptDatInRoot`:

- Added: `Global Scenery/Global Airports/Earth nav data`

## Verification

- **Test Case 1 (Negative):** Verified `KAPT.dat` is ignored during recursive search.
- **Test Case 2 (Positive):** Verified `apt.dat` is correctly located in standard X-Plane 11 and 12 directories.
- **Outcome:** Database loading now consistently targets the correct `apt.dat` file regardless of the input path provided (root folder or subdirectories).

## Appendix: X-Plane 11 vs X-Plane 12 Navigation Data Structure

| Feature | X-Plane 11 | X-Plane 12 | Core Reason |
| :--- | :--- | :--- | :--- |
| **Default Airport Data Location** | `Resources/default scenery/default apt dat/Earth nav data/apt.dat` | Also exists, but relies more on `Global Scenery/Global Airports` | **Modular Updates**: XP12 separated global airport data into the `Global Airports` module, allowing independent updates via Steam/Installer without touching core resources. |
| **Third-Party Data (CIFP)** | Usually overwrites default data or manually placed in `Custom Data` | **Native CIFP Support**: `Custom Data/CIFP/` is standard | **Realism**: XP12 natively supports ARINC 424 formatted CIFP data, moving away from relying solely on old apt.dat/nav.dat overrides. |
| **File Structure** | Primarily `apt.dat` (airports) and `earth_nav.dat` (navaids) | `CIFP` folder contains many subdivided files (`earth_nav.dat`, `earth_fix.dat`, etc.) | **Data Granularity**: XP12 requires finer-grained data to support new GPS/FMS systems, leading to a more complex CIFP folder structure (which caused the KAPT.dat false positive). |

**Summary:**
X-Plane 12 modularized and subdivided the data structure to support modern avionics and flexible online updates.

- **XP11 Era**: Monolithic files (`apt.dat` contains everything).
- **XP12 Era**: Hierarchical folder structures (`CIFP` folder), which caused the old search logic to get lost in complex directories (e.g., misreading `KAPT.dat`).
