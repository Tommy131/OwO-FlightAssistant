# OwO! FlightAssistant

[中文说明 (Chinese)](README.zh-CN.md)

![Flutter](https://img.shields.io/badge/Flutter-v3.9.2+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20Web-blue)
![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)

OwO! FlightAssistant is a modular flight-companion app for desktop and mobile simulator workflows.
The current frontend integrates flight monitoring, checklist execution, map visualization, airport/METAR search, flight log analysis, and middleware health diagnostics for both **MSFS 2020/2024** and **X-Plane 11/12**.

## Feature Overview

### 1) Home Dashboard & Simulator Session

| General Info | Aircraft Info | Airport Info |
| --- | --- | --- |
| ![Home General](assets/images/home_page-general-info.png) | ![Home Aircraft](assets/images/home_page-aircraft-info.png) | ![Home Airport](assets/images/home_page-airport-info.png) |

- Connect/disconnect simulator sessions from the home workflow.
- Track key airborne and ground data in a compact status dashboard.
- Display airport and aircraft context in one unified entry page.

### 2) Airport Search & Operational Briefing

| Airport Search | Briefing Generator | Briefing Details |
| --- | --- | --- |
| ![Airport Search](assets/images/airport_search_page.png) | ![Briefing Generator](assets/images/briefing_page-generator.png) | ![Briefing Details](assets/images/briefing_page-details.png) |

- Search ICAO airports with suggestion support and favorites persistence.
- Load airport details + METAR through the middleware API.
- Generate and review operation briefing cards and history records.

### 3) Checklist, Monitor, and Toolbox

| Checklist | Monitor (Charts) | Monitor (Landing Gear) | Toolbox |
| --- | --- | --- | --- |
| ![Checklist](assets/images/checklist_page.png) | ![Monitor Charts](assets/images/monitor_page-charts.png) | ![Monitor Landing Gear](assets/images/monitor_page-landing-gear.png) | ![Toolbox](assets/images/tool_box_page.png) |

- Execute multi-phase SOP checklists (A320/B737/Generic).
- Observe live monitor panels (charts, heading, systems, landing gear).
- Use utility tools and aviation reference cards from Toolbox.

### 4) Map Module (Layers, Weather, Airports)

| Layer Panel | Airport Types | Airport Info | Weather Radar |
| --- | --- | --- | --- |
| ![Map Layers](assets/images/map_page-layers.png) | ![Map Airport Types](assets/images/map_page-airport-types.png) | ![Map Airport Info](assets/images/map_page-airport-info.png) | ![Map Radar](assets/images/map_page-weather-radar.png) |

- Multi-provider map backgrounds (OpenStreetMap, Esri, Carto variants).
- Airport rendering by category and airport detail panels.
- RainViewer weather radar overlay timeline support.

### 5) Flight Logs & Analysis

| Logs List | Track View | Quality Report | Danger Test |
| --- | --- | --- | --- |
| ![Flight Logs](assets/images/flight_logs_page.png) | ![Flight Track](assets/images/flight_logs_page-flight-track.png) | ![Flight Quality](assets/images/flight_logs_page-flight-quality-report.png) | ![Danger Test](assets/images/flight_logs_page-danger-test-flight.png) |

| Black Box | Black Box (Danger Alert) |
| --- | --- |
| ![Black Box](assets/images/flight_logs_page_black-box-data-1.png) | ![Black Box Danger](assets/images/flight_logs_page_black-box-data-with-danger-alert.png) |

- Store and replay flight sessions with timeline and track analysis.
- Provide quality scoring and safety-oriented danger testing.
- Inspect black-box style event data for post-flight review.

### 6) Settings & Middleware Diagnostics

| Middleware Settings | Map Module Settings | Global Settings |
| --- | --- | --- |
| ![Middleware Settings](assets/images/middleware_settings_page.png) | ![Map Module Settings](assets/images/map_module_settings_page.png) | ![Settings](assets/images/settings_page.png) |

- Configure HTTP and WebSocket middleware endpoints.
- Run integrated connectivity diagnosis (backend / websocket / simulator state).
- Tune map module data behaviors and app-level preferences.

## Supported Devices, Platforms, and Simulators

### Device Layout Support

- **Mobile layout**: width `< 650`
- **Tablet layout**: width `650 - 1241`
- **Desktop layout**: width `>= 1242`

### Flutter Targets in This Repository

- **Windows desktop**: first-class experience and recommended for simulator operations
- **Android / iOS**: available targets for mobile companion usage
- **Web**: scaffolded and buildable for browser usage

### Simulators

- **Microsoft Flight Simulator (2020 / 2024)**
- **X-Plane (11 / 12)**

## Project Architecture (Frontend)

```text
lib/
├── core/                    # App shell, localization, theme, module registry
├── modules/
│   ├── home/                # Home dashboard + simulator controls
│   ├── checklist/           # SOP checklist module
│   ├── map/                 # Interactive map + layers + weather
│   ├── airport_search/      # ICAO search, airport details, METAR
│   ├── monitor/             # Live monitor widgets and charts
│   ├── briefing/            # Flight briefing generation and history
│   ├── flight_logs/         # Flight logs and analysis views
│   ├── toolbox/             # Utility toolbox
│   └── http/                # Middleware endpoint settings + diagnostics
└── main.dart
```

Module registration entry: `lib/modules/modules_register_entry.dart`.

## Installation & Usage

### Prerequisites

- Flutter SDK `^3.9.2`
- A running middleware backend instance (default: `http://127.0.0.1:18080`)
- Optional simulator runtime:
  - MSFS 2020/2024
  - X-Plane 11/12

### Install

```bash
git clone <your-fork-or-repo-url>
cd owo_flight_assistant
flutter pub get
```

### Run (Recommended: Windows Desktop)

```bash
flutter run -d windows
```

Alternative targets:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### Basic Usage Flow

1. Open **Settings → Middleware Settings**, set backend host/port if not default.
2. Go to **Home**, connect simulator session.
3. Use **Checklist**, **Map**, **Monitor**, and **Airport Search** modules during flight.
4. Review post-flight insights in **Flight Logs**.

## Open-Source Repositories / Packages Used

Core framework and state:

- [Flutter](https://flutter.dev/)
- [provider](https://pub.dev/packages/provider)

Networking and simulator channels:

- [http](https://pub.dev/packages/http)
- [web_socket_channel](https://pub.dev/packages/web_socket_channel)

Mapping and geo:

- [flutter_map](https://pub.dev/packages/flutter_map)
- [latlong2](https://pub.dev/packages/latlong2)

Storage, files, and desktop runtime:

- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [sqlite3](https://pub.dev/packages/sqlite3)
- [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs)
- [file_picker](https://pub.dev/packages/file_picker)
- [window_manager](https://pub.dev/packages/window_manager)

UI and utilities:

- [fl_chart](https://pub.dev/packages/fl_chart)
- [flex_color_picker](https://pub.dev/packages/flex_color_picker)
- [google_fonts](https://pub.dev/packages/google_fonts)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [share_plus](https://pub.dev/packages/share_plus)
- [url_launcher](https://pub.dev/packages/url_launcher)
- [logger](https://pub.dev/packages/logger)
- [intl](https://pub.dev/packages/intl)
- [confetti](https://pub.dev/packages/confetti)

## API Interfaces Used by Frontend

Default middleware endpoints:

- HTTP base URL: `http://127.0.0.1:18080`
- WebSocket base URL: `ws://127.0.0.1:18081/api/v1/simulator/ws`

Main API routes consumed:

- `GET /health`
- `GET /api/v1/version`
- `GET /api/v1/airport/{icao}`
- `GET /api/v1/airport-layout/{icao}`
- `GET /api/v1/metar/{icao}`
- `GET /api/v1/airport-list`
- `GET /api/v1/airport-suggest?q={query}&limit={n}`
- `GET /api/v1/airports?min_lat=&max_lat=&min_lon=&max_lon=&limit=`
- `POST /api/v1/simulator/state`
- `POST /api/v1/simulator/connect`
- `POST /api/v1/simulator/data`
- `POST /api/v1/simulator/disconnect`
- `GET /api/v1/simulator/ws`

Third-party map/weather data services:

- [OpenStreetMap Tile](https://tile.openstreetmap.org/)
- [Esri World Imagery](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer)
- [Esri World Topo](https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer)
- [Carto Basemaps](https://carto.com/basemaps)
- [RainViewer Weather Maps](https://www.rainviewer.com/api.html)

## Open-Source License

This project is licensed under:

- **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International**
- See [LICENSE](LICENSE) for full terms.

## Developer Information

- Team: **OwOTeam-DGMT (OwOBlog)**
- Primary developer: **HanskiJay**
- Contact: **<support@owoblog.com>**
- GitHub: [Tommy131](https://github.com/Tommy131)
- Repository: [OwO-FlightAssistant](https://github.com/Tommy131/OwO-FlightAssistant)
- Telegram: [@HanskiJay](https://t.me/HanskiJay)

## Disclaimer

This software is for simulator training, learning, and research purposes only.
Do not use it for real-world flight operations.
