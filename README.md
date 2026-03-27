# OwO! FlightAssistant

[中文说明 (Chinese)](README.zh-CN.md)

![Flutter](https://img.shields.io/badge/Flutter-v3.9.2+-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20Web-blue)
![License](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)

OwO! FlightAssistant is a modular flight-companion app for desktop and mobile simulator workflows.
The current frontend integrates flight monitoring, checklist execution, map visualization, airport/METAR search, flight log analysis, and middleware health diagnostics for both **MSFS 2020/2024** and **X-Plane 11/12**.

---

## 1. 🚀 Feature Overview

### 1.1 Home Dashboard & Simulator Session

| General Info | Aircraft Info | Airport Info |
| --- | --- | --- |
| ![Home General](assets/images/home_page-general-info.png) | ![Home Aircraft](assets/images/home_page-aircraft-info.png) | ![Home Airport](assets/images/home_page-airport-info.png) |

- **Real-time Synchronization**: Seamlessly connect/disconnect simulator sessions (MSFS/X-Plane).
- **Unified Status**: Track key airborne/ground data, engine parameters, and transponder status in one dashboard.
- **Intelligent Context**: Automatic METAR fetching and translation for current origin/destination airports.

### 1.2 Airport Search & Operational Briefing

| Airport Search | Briefing Generator | Briefing Details |
| --- | --- | --- |
| ![Airport Search](assets/images/airport_search_page.png) | ![Briefing Generator](assets/images/briefing_page-generator.png) | ![Briefing Details](assets/images/briefing_page-details.png) |

- **Global Airport Database**: Search ICAO airports with smart suggestions and persistent favorites.
- **Deep Data Retrieval**: Load detailed runway configurations, frequencies, parking stands, and live METAR.
- **Flight Briefing**: Generate comprehensive operational briefing cards with fuel planning and view history records.

### 1.3 Checklist, Monitor, and Toolbox

| Checklist | Monitor (Charts) | Monitor (Landing Gear) | Toolbox |
| --- | --- | --- | --- |
| ![Checklist](assets/images/checklist_page.png) | ![Monitor Charts](assets/images/monitor_page-charts.png) | ![Monitor Landing Gear](assets/images/monitor_page-landing-gear.png) | ![Toolbox](assets/images/tool_box_page.png) |

- **SOP Checklists**: Execute multi-phase checklists for **A320**, **B737**, and Generic aircraft.
- **Phase Automation**: Intelligent flight phase derivation to automatically highlight relevant checklist sections.
- **Live Monitoring**: Real-time charts for speed/altitude, heading compass, and interactive landing gear status.
- **Aviation Toolbox**: Quick access to utility tools and reference cards for pilots.

### 1.4 Map Module (Layers, Weather, Airports)

| Layer Panel | Airport Types | Airport Info | Weather Radar |
| --- | --- | --- | --- |
| ![Map Layers](assets/images/map_page-layers.png) | ![Map Airport Types](assets/images/map_page-airport-types.png) | ![Map Airport Info](assets/images/map_page-airport-info.png) | ![Map Radar](assets/images/map_page-weather-radar.png) |

- **Interactive Layers**: Toggle between OSM, Esri World Imagery/Topo, and Carto map providers.
- **Taxiway Drawing**: Support for manual/automatic taxiway path drawing and route management.
- **Weather Radar**: Integrated RainViewer overlay with timeline playback and transparency control.
- **Airport Visualization**: Dynamic rendering of airports by category with clickable detail panels.

### 1.5 Flight Logs & Analysis

| Logs List | Track View | Quality Report | Danger Test |
| --- | --- | --- | --- |
| ![Flight Logs](assets/images/flight_logs_page.png) | ![Flight Track](assets/images/flight_logs_page-flight-track.png) | ![Flight Quality](assets/images/flight_logs_page-flight-quality-report.png) | ![Danger Test](assets/images/flight_logs_page-danger-test-flight.png) |

- **Black Box Replay**: Inspect high-frequency event data and system states for post-flight review.
- **Flight Quality Scoring**: Automated assessment of flight stability and safety performance.
- **Visual Track Analysis**: Replay flight tracks on an interactive map with altitude/speed profiles.
- **Safety Auditing**: Specialized "Danger Test" flight reports for identifying critical safety violations.

### 1.6 Settings & Middleware Diagnostics

| Middleware Settings | Map Module Settings | Global Settings |
| --- | --- | --- |
| ![Middleware Settings](assets/images/middleware_settings_page.png) | ![Map Module Settings](assets/images/map_module_settings_page.png) | ![Settings](assets/images/settings_page.png) |

- **Middleware Orchestration**: Configure HTTP/WebSocket endpoints with built-in health diagnostics.
- **Full I18n Support**: Switch between **English** and **Simplified Chinese** across the entire UI.
- **Customization**: Tune map behavior, theme preferences, and localized log storage settings.

---

## 2. 📱 Supported Devices, Platforms, and Simulators

### 2.1 Device Layout Support

- **Mobile layout**: width `< 650`
- **Tablet layout**: width `650 - 1241`
- **Desktop layout**: width `>= 1242`

### 2.2 Flutter Targets in This Repository

- **Windows desktop**: first-class experience and recommended for simulator operations
- **Android / iOS**: available targets for mobile companion usage
- **Web**: scaffolded and buildable for browser usage

### 2.3 Simulators

- **Microsoft Flight Simulator (2020 / 2024)**
- **X-Plane (11 / 12)**

---

## 3. 🏗️ Project Architecture (Frontend)

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

---

## 4. 🛠️ Installation & Usage

### 4.1 Download Release (Recommended)

For non-developers, the easiest way to get started is by downloading the pre-compiled packages:

1. Visit the [GitHub Releases](https://github.com/Tommy131/OwO-FlightAssistant/releases) page.
2. Download the latest compressed archive for your platform (e.g., `.zip` for Windows).
3. Extract the archive and run the executable.
4. For detailed configuration and setup instructions, please **check our [Wiki](https://github.com/Tommy131/OwO-FlightAssistant/wiki)**.

### 4.2 Build from Source Code

#### Prerequisites

- Flutter SDK `^3.9.2`
- A running middleware backend instance (default: `http://127.0.0.1:18080`)
- Optional simulator runtime: MSFS 2020/2024 or X-Plane 11/12

#### Install

```bash
git clone https://github.com/Tommy131/OwO-FlightAssistant.git
cd OwO-FlightAssistant
flutter pub get
```

#### Run (Recommended: Windows Desktop)

```bash
flutter run -d windows
```

#### Alternative targets

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

### 4.3 Basic Usage Flow

1. Open **Settings → Middleware Settings**, set backend host/port if not default.
2. Go to **Home**, connect simulator session.
3. Use **Checklist**, **Map**, **Monitor**, and **Airport Search** modules during flight.
4. Review post-flight insights in **Flight Logs**.

---

## 5. 📚 Open-Source Repositories / Packages Used

- **Core framework and state**: [Flutter](https://flutter.dev/), [provider](https://pub.dev/packages/provider)
- **Networking and simulator channels**: [http](https://pub.dev/packages/http), [web_socket_channel](https://pub.dev/packages/web_socket_channel)
- **Mapping and geo**: [flutter_map](https://pub.dev/packages/flutter_map), [latlong2](https://pub.dev/packages/latlong2)
- **Storage, files, and desktop runtime**: [shared_preferences](https://pub.dev/packages/shared_preferences), [sqlite3](https://pub.dev/packages/sqlite3), [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs), [file_picker](https://pub.dev/packages/file_picker), [window_manager](https://pub.dev/packages/window_manager)
- **UI and utilities**: [fl_chart](https://pub.dev/packages/fl_chart), [flex_color_picker](https://pub.dev/packages/flex_color_picker), [google_fonts](https://pub.dev/packages/google_fonts), [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications), [share_plus](https://pub.dev/packages/share_plus), [url_launcher](https://pub.dev/packages/url_launcher), [logger](https://pub.dev/packages/logger), [intl](https://pub.dev/packages/intl), [confetti](https://pub.dev/packages/confetti)

---

## 6. 📡 API Interfaces Used by Frontend

Default middleware endpoints:

- HTTP base URL: `http://127.0.0.1:18080`
- WebSocket base URL: `ws://127.0.0.1:18081/api/v1/simulator/ws`

Main API routes consumed:

- `GET /health`
- `GET /api/v1/airport/{icao}`, `GET /api/v1/airport-layout/{icao}`, `GET /api/v1/metar/{icao}`
- `GET /api/v1/airport-list`, `GET /api/v1/airport-suggest?q={query}`, `GET /api/v1/airports?min_lat=&...`
- `POST /api/v1/simulator/state`, `POST /api/v1/simulator/connect`, `POST /api/v1/simulator/data`, `POST /api/v1/simulator/disconnect`
- `GET /api/v1/simulator/ws`

---

## 7. 📄 Open-Source License

This project is licensed under:

- **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International**
- See [LICENSE](LICENSE) for full terms.

---

## 8. 👨‍💻 Developer Information

- Team: **OwOTeam-DGMT (OwOBlog)**
- Primary developer: **HanskiJay**
- Contact: **<support@owoblog.com>**
- GitHub: [Tommy131](https://github.com/Tommy131)
- Repository: [OwO-FlightAssistant](https://github.com/Tommy131/OwO-FlightAssistant)
- Telegram: [@HanskiJay](https://t.me/HanskiJay)

---

## 9. ⚠️ Disclaimer

This software is for simulator training, learning, and research purposes only.
Do not use it for real-world flight operations.
