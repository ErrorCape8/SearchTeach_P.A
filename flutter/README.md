# SearchTeach Flutter

## Run web and Windows together

From the project root, double-click `start-searchteach.bat` in File Explorer.
Alternatively, open the project in VS Code, select **SearchTeach (Web + Windows)**
in **Run and Debug**, and press F5.

You can also run the script from PowerShell:

```powershell
.\start-searchteach.ps1
```

This starts the backend with Docker Compose, opens Flutter Web in Chrome at
`http://localhost:5001`, and launches the Windows desktop app. Flutter
dependencies must be installed first with `flutter pub get` from this directory.
For the Windows target, enable Windows Developer Mode so Flutter can create the
required symlinks. The backend image is rebuilt on each launch while reusing
Docker's build cache, so source changes do not require manually clearing caches.
The Android Gradle configuration also limits build memory and reuses its build
cache.

The backend uses `MONGO_URI` from the project-root `.env` when provided; include
the target database in the URI path (for example, `/searchteach`). Without it,
the backend uses the local Compose MongoDB database.

To start only one frontend, use `.\start-searchteach.ps1 -Frontend web` or
`.\start-searchteach.ps1 -Frontend windows`. The backend API is at
`http://localhost:8081`.

## Virtual and hybrid tutoring rooms

Virtual and hybrid group sessions use LiveKit for audio, video, and in-room
chat. Configure `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` in
the root `.env` for local Docker Compose, or set the same environment variables
on the API service in production. The URL is the LiveKit WebSocket URL (usually
`wss://...` for a hosted deployment). Keep the API secret on the backend; the
Flutter app receives only a short-lived room token after the backend confirms
the user is the session teacher or an enrolled student. The room opens 15
minutes before its scheduled start and closes to new tokens one hour after its
scheduled end. Chat messages are exchanged live through LiveKit data packets
and are not stored as chat history.

## Program-leader menu and account data

The program-leader panel provides **Inicio**, **Calidad**, **Pronóstico**,
**Proyectos**, and **Perfil**. Its dashboard metrics are loaded from the
backend's MongoDB tutoring data. Before a program leader can register, add their
identification as `_id` in the `program_leaders` collection of the `Searchteach`
database. The backend creates this collection on startup and supports existing
accounts in the legacy `coordinators` collection.

Group tutoring sessions are stored separately in `sesiones_tutoria`, preserving
the existing one-student `tutorias` request workflow. Each session contains a
coordinator-assigned `docenteId`, one to five `estudianteIds`, `fechaInicio`,
`fechaFin`, `tecnologia`, and `semestre`. Its `asistencias` array stores one
entry per student with `asistio` set to `true`, `false`, or `null` until it is
recorded. The backend creates the collection on startup.

A coordinator creates a collective tutoring cohort through
`POST /api/coordinacion/tutorias-colectivas`, selecting one lead teacher, five
support teachers, a career, and a semester. Students in that career can create
a project by name or join an existing project with the same name in the cohort;
the backend assigns a support teacher at random and limits each project to four
students. Coordinators can delete cohorts, including their projects,
enrollments, and progress reports. Individual tutor schedules can also be
deleted; previously created tutoring sessions are retained. Each tutor may be
assigned up to two subjects total, including subjects shared across careers,
and students select only from those configured subjects. Support teachers
submit periodic 0–100 progress scores and notes with
`POST /api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/informes`.
The program leader reads the reports and project trends from
`GET /api/direccion/tutorias-colectivas`. The trend is estimated with linear
regression over the mean score recorded per report date; it reports insufficient
data until there are three distinct report dates, then forecasts four weeks
ahead. A projected four-week change of at least 2 points is marked as
improvement or regression; a smaller change is stable. Reports should use the
same 0–100 progress rubric so the trend is comparable. It indicates progress
trends, not proof that tutoring caused a change.
These endpoints are protected by coordinator, assigned-teacher, and program
leader access checks, respectively.
The coordinator-entered leader and support-teacher identifiers must already
exist in the `users` collection so those teachers can authenticate to submit
their reports.

After signing in, coordinator accounts open the tutor schedule manager,
students open a responsive student dashboard, and program-leader accounts keep
the institutional dashboard with a **Proyectos** tab for collective reports
and their trend. A user whose academic role includes both student and teacher
opens the student dashboard and can switch to the teacher reports view from
their profile.

Coordinator accounts open **Horarios de tutores** after signing in. The screen
searches the active teacher directory by name or identification, filters saved
availability by career and semester, and separates the teacher directory from
the **Horarios creados** list. Assigning a schedule creates a persistent record;
the same teacher's action then changes to **Editar**. Career and semester are
captured with each schedule, and the dashboard uses a navigation rail and a
wider content area on desktop while retaining bottom navigation on mobile.
Collective tutoring setup remains available from the coordinator schedule
screen.

The Flutter schedule feature is split by responsibility: its page owns loading
and filtering state, `coordinacion_horarios_form.dart` owns create/edit input,
`coordinacion_horarios_widgets.dart` contains the responsive filters and cards,
and `coordinacion_horarios_models.dart` parses the API data. Subject choices
come from the official six-semester curriculum for the selected technology.
Shared subjects are automatically associated with every technology whose
curriculum includes them; coordination no longer selects sharing careers
manually. Each teacher can still be assigned up to two subjects.

The student dashboard uses the authenticated user's profile from
`GET /api/usuarios/perfil`, tutor availability from
`GET /api/tutorias/disponibles`, and the existing personal tutoring endpoints.
Students can search available tutors by name or ID, filter by career and
semester, and submit a tutoring request with **Inscribirse**. Profile responses
contain only the signed-in user's ID, name, email, phone, and academic role.
The dashboard separates its responsive page/shell, home/profile views, tutoring
views, and API models.

The **Pronóstico** view reports distinct enrolled students and recorded/
confirmed attendance by subject, using tutoring records from MongoDB. It fits a
linear regression separately for each subject over up to 10 completed weeks,
and displays one-week and four-week demand estimates, a 95% predictive interval,
and the demand trend. A subject needs requests in at least four completed weeks
to receive a forecast; missing weeks after its first request are treated as
zero.

## Run on a phone

First start the backend from the project root with `docker compose up -d app`.
Connect an Android phone over USB with USB debugging enabled, or start an Android
emulator from Android Studio. Run `flutter devices` to find its device ID.

From this directory, start the app on an emulator:

```powershell
flutter run -d <device-id>
```

The default API address `http://10.0.2.2:8081` points from the Android emulator
to the backend on the development PC. The Android debug manifest permits local
HTTP traffic for development only.

For a physical phone, connect the phone and PC to the same Wi-Fi, allow inbound
connections to port 8081 through the PC firewall, then pass the PC's LAN address:

```powershell
$flutterPath = (Get-Command flutter).Source
$fileSystem = New-Object -ComObject Scripting.FileSystemObject
$flutterPath = $fileSystem.GetFile($flutterPath).ShortPath
& $flutterPath run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:8081
```

Replace the example address with the PC's actual LAN IP. Keep the backend running
on the PC; the phone talks to its API, while the backend connects to Atlas and
cloud Redis. For iOS, use the Mac's LAN IP and run Flutter from macOS.
