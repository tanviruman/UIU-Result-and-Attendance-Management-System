# URAMS — UIU Result & Academic Management System

<p align="center">
  <b>A role-based academic result management system for universities</b><br/>
  Admins manage academic structure, teachers enter marks and attendance, students view results/transcripts, and parents monitor academic progress.
</p>

<p align="center">
  <img alt="PHP" src="https://img.shields.io/badge/PHP-8.x-777BB4?style=for-the-badge&logo=php&logoColor=white">
  <img alt="MySQL" src="https://img.shields.io/badge/MySQL%2FMariaDB-Database-4479A1?style=for-the-badge&logo=mysql&logoColor=white">
  <img alt="JavaScript" src="https://img.shields.io/badge/JavaScript-Frontend-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black">
  <img alt="XAMPP" src="https://img.shields.io/badge/XAMPP-Local%20Server-FB7A24?style=for-the-badge&logo=xampp&logoColor=white">
</p>

---

## Table of Contents

- [Project Overview](#project-overview)
- [Core Objectives](#core-objectives)
- [Key Features](#key-features)
- [User Roles](#user-roles)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [C4 Architecture Diagrams](#c4-architecture-diagrams)
- [Project Workflow](#project-workflow)
- [Database Design](#database-design)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [UML Diagrams](#uml-diagrams)
- [Dependency Graphs](#dependency-graphs)
- [Code Visualization](#code-visualization)
- [Core Backend Endpoints](#core-backend-endpoints)
- [Installation Guide](#installation-guide)
- [Default Credentials](#default-credentials)
- [Common SQL Queries](#common-sql-queries)
- [Testing Checklist](#testing-checklist)
- [Troubleshooting](#troubleshooting)
- [Future Improvements](#future-improvements)
- [Security Notes](#security-notes)
- [License](#license)

---

## Project Overview

**URAMS** stands for **University Result and Academic Management System**.

It is a PHP and MySQL based academic management platform designed to manage the complete result-processing workflow of a university. The system supports academic setup, teacher assignment, student enrollment, prerequisite checking, marks entry, attendance, result submission, admin approval, transcript generation, and parent/student result monitoring.

---

## Core Objectives

- Centralize academic result processing.
- Reduce manual result calculation errors.
- Allow teachers to enter marks component-wise.
- Support course, section, trimester, and curriculum-based academic setup.
- Ensure only approved results are visible to students and parents.
- Maintain transparency using audit logs and approval workflow.
- Provide transcript and GPA/CGPA generation.

---

## Key Features

### Admin Module

- Admin dashboard with academic overview.
- Teacher management.
- Student management.
- Academic setup.
- Course section creation.
- Teacher assignment.
- Student enrollment.
- Prerequisite checking.
- Result approval/rejection.
- Grade rules management.
- Audit log and notifications.

### Teacher Module

- Teacher dashboard.
- Assigned section view.
- Marks entry and update.
- Assessment component configuration.
- Grace marks processing.
- CT average calculation.
- Attendance management.
- Result submission.
- PDF/report generation.
- Excel/CSV marks sheet download and upload.

### Student Module

- Student dashboard.
- Approved result view.
- Trimester-wise result history.
- GPA/CGPA view.
- Transcript generation.
- Attendance summary.
- Student profile.

### Parent Module

- Parent dashboard.
- Linked child academic result view.
- Read-only child performance analytics.
- Academic progress monitoring.

---

## User Roles

| Role | Main Responsibility |
|---|---|
| Admin | Controls academic setup, users, approvals, rules, and audit logs |
| Teacher | Manages marks, attendance, and result submission |
| Student | Views approved result, GPA, CGPA, and transcript |
| Parent | Views linked child result and academic progress |

---

## Technology Stack

| Layer | Technology |
|---|---|
| Frontend | HTML, CSS, JavaScript |
| Backend | PHP |
| Database | MySQL / MariaDB |
| Local Server | XAMPP |
| UI Assets | Custom CSS, icons |
| Reporting | Browser print/PDF, PHP-generated reports |
| Version Control | Git and GitHub |

---

## System Architecture

URAMS follows a traditional **client-server web architecture**.

```mermaid
flowchart LR
    U[User Browser] --> UI[HTML CSS JavaScript UI]
    UI --> PHP[PHP Backend Endpoints]
    PHP --> DB[(MySQL / MariaDB Database)]
    PHP --> AUTH[Session Based Authentication]
    PHP --> PDF[PDF / Report Generation]
    DB --> PHP
    PHP --> UI
```

### Architecture Explanation

1. User interacts with the browser interface.
2. JavaScript sends requests to PHP backend files.
3. PHP validates session, role, and input.
4. PHP performs database operations using MySQL/MariaDB.
5. Backend returns JSON response or renders PHP pages.
6. Frontend updates dashboard, tables, forms, and charts.

---

## C4 Architecture Diagrams

### C4 Level 1 — System Context Diagram

```mermaid
flowchart LR
    Admin[Admin] --> URAMS[URAMS System]
    Teacher[Teacher] --> URAMS
    Student[Student] --> URAMS
    Parent[Parent] --> URAMS
    URAMS --> DB[(MySQL Database)]

    Admin -. manages users, academic setup, approvals .-> URAMS
    Teacher -. enters marks, attendance, submits result .-> URAMS
    Student -. views result and transcript .-> URAMS
    Parent -. monitors child progress .-> URAMS
```

### C4 Level 2 — Container Diagram

```mermaid
flowchart TB
    User[Users: Admin / Teacher / Student / Parent]

    subgraph WebApp[URAMS Web Application]
        Frontend[Frontend Container\nHTML, CSS, JavaScript]
        Backend[Backend Container\nPHP]
        Report[Report Container\nPDF / Print / Transcript]
    end

    Database[(Database Container\nMySQL / MariaDB)]

    User --> Frontend
    Frontend --> Backend
    Backend --> Database
    Backend --> Report
    Report --> Frontend
```

### C4 Level 3 — Component Diagram

```mermaid
flowchart TB
    subgraph Frontend[Frontend Components]
        AdminUI[Admin Dashboard UI]
        TeacherUI[Teacher Dashboard UI]
        StudentUI[Student Dashboard UI]
        ParentUI[Parent Dashboard UI]
        JS[script.js / academic_admin.js]
    end

    subgraph Backend[PHP Backend Components]
        Auth[Authentication & Session]
        AdminAPI[Admin APIs]
        TeacherAPI[Teacher APIs]
        StudentAPI[Student APIs]
        ResultEngine[Result Calculation Engine]
        AttendanceEngine[Attendance Engine]
        TranscriptEngine[Transcript Engine]
        Audit[Audit Logger]
    end

    subgraph Database[Database Tables]
        Users[(users)]
        Courses[(courses)]
        Sections[(course_sections)]
        Enrollments[(enrollments)]
        Components[(assessment_components)]
        Marks[(component_marks)]
        Results[(results)]
        Submissions[(result_submissions)]
        Logs[(audit_logs)]
    end

    AdminUI --> JS
    TeacherUI --> JS
    StudentUI --> JS
    ParentUI --> JS

    JS --> Auth
    JS --> AdminAPI
    JS --> TeacherAPI
    JS --> StudentAPI

    AdminAPI --> Users
    AdminAPI --> Courses
    AdminAPI --> Sections
    AdminAPI --> Enrollments

    TeacherAPI --> Components
    TeacherAPI --> Marks
    TeacherAPI --> AttendanceEngine
    TeacherAPI --> ResultEngine

    ResultEngine --> Results
    ResultEngine --> Submissions
    TranscriptEngine --> Results
    Audit --> Logs
```

---

## Project Workflow

### Full Academic Result Workflow

```mermaid
flowchart TD
    A[Admin creates program and curriculum] --> B[Admin creates trimester]
    B --> C[Admin creates course section]
    C --> D[Admin assigns teacher]
    D --> E[Admin enrolls students]
    E --> F{Prerequisite satisfied?}
    F -- Yes --> G[Enrollment approved]
    F -- No --> H[Block enrollment or force enroll]
    G --> I[Teacher enters marks]
    H --> I
    I --> J[Teacher manages attendance]
    J --> K[System calculates total and grade]
    K --> L[Teacher submits result]
    L --> M[Admin reviews result]
    M --> N{Approve result?}
    N -- Yes --> O[Result becomes approved]
    N -- No --> P[Result returned or rejected]
    O --> Q[Student views result]
    O --> R[Parent views result]
    O --> S[Transcript generated]
    P --> I
```

### Login and Role Routing Flow

```mermaid
flowchart TD
    A[User opens login page] --> B[Enter username and password]
    B --> C[PHP validates credentials]
    C --> D{Valid user?}
    D -- No --> E[Show login error]
    D -- Yes --> F[Create session]
    F --> G{Check role}
    G -- Admin --> H[Admin Dashboard]
    G -- Teacher --> I[Teacher Dashboard]
    G -- Student --> J[Student Dashboard]
    G -- Parent --> K[Parent Dashboard]
```

---

## Database Design

### Main Database Tables

| Table | Purpose |
|---|---|
| `users` | Stores admin, teacher, student, and parent accounts |
| `programs` | Stores academic programs such as BBA, CSE, EEE, Pharmacy |
| `curriculum_versions` | Stores curriculum versions for programs |
| `courses` | Stores course catalog |
| `curriculum_courses` | Maps courses with curriculum versions |
| `course_prerequisites` | Stores prerequisite course rules |
| `trimesters` | Stores academic trimester/session information |
| `course_sections` | Stores course sections and teacher assignment |
| `enrollments` | Stores student enrollment in sections |
| `assessment_components` | Stores marks components such as CT, Assignment, Mid, Final |
| `component_marks` | Stores component-wise student marks |
| `attendance_records` | Stores attendance records |
| `results` | Stores calculated final result per enrollment |
| `student_section_results` | Stores section-wise finalized result |
| `result_submissions` | Stores teacher submission and admin approval status |
| `grade_rules` | Stores grading scale |
| `audit_logs` | Stores important system activities |
| `notifications` | Stores system notifications |

---

## Entity Relationship Diagram

```mermaid
erDiagram
    USERS {
        int id PK
        string identifier
        string full_name
        string email
        string role
        string password
        string status
        int program_id FK
        int curriculum_version_id FK
    }

    PROGRAMS {
        int id PK
        string program_code
        string program_name
    }

    CURRICULUM_VERSIONS {
        int id PK
        int program_id FK
        string version_code
        string title
        string effective_from
    }

    COURSES {
        int id PK
        string course_code
        string course_name
        decimal credit
        int program_id FK
        string course_type
        int level_no
    }

    CURRICULUM_COURSES {
        int id PK
        int curriculum_version_id FK
        int course_id FK
        int semester_no
    }

    COURSE_PREREQUISITES {
        int id PK
        int course_id FK
        int prerequisite_course_id FK
    }

    TRIMESTERS {
        int id PK
        string name
        date start_date
        date end_date
        string status
    }

    COURSE_SECTIONS {
        int id PK
        int course_id FK
        int trimester_id FK
        int teacher_id FK
        string section_name
        int capacity
        string status
    }

    ENROLLMENTS {
        int id PK
        int student_id FK
        int section_id FK
        int parent_user_id FK
        string status
        datetime enrolled_at
    }

    ASSESSMENT_COMPONENTS {
        int id PK
        int section_id FK
        string component_name
        decimal marks_out_of
        decimal convert_to
        string component_type
    }

    COMPONENT_MARKS {
        int id PK
        int enrollment_id FK
        int component_id FK
        decimal raw_marks
        decimal converted_marks
    }

    RESULTS {
        int id PK
        int enrollment_id FK
        decimal total_marks
        string grade
        decimal grade_point
        string status
    }

    RESULT_SUBMISSIONS {
        int id PK
        int section_id FK
        int submitted_by FK
        string status
        datetime submitted_at
        datetime approved_at
    }

    USERS ||--o{ COURSE_SECTIONS : teaches
    USERS ||--o{ ENROLLMENTS : student
    USERS ||--o{ ENROLLMENTS : parent
    PROGRAMS ||--o{ CURRICULUM_VERSIONS : has
    PROGRAMS ||--o{ USERS : assigned
    PROGRAMS ||--o{ COURSES : offers
    CURRICULUM_VERSIONS ||--o{ CURRICULUM_COURSES : includes
    COURSES ||--o{ CURRICULUM_COURSES : mapped
    COURSES ||--o{ COURSE_PREREQUISITES : requires
    COURSES ||--o{ COURSE_SECTIONS : has
    TRIMESTERS ||--o{ COURSE_SECTIONS : contains
    COURSE_SECTIONS ||--o{ ENROLLMENTS : has
    COURSE_SECTIONS ||--o{ ASSESSMENT_COMPONENTS : has
    COURSE_SECTIONS ||--o{ RESULT_SUBMISSIONS : submitted
    ENROLLMENTS ||--o{ COMPONENT_MARKS : receives
    ENROLLMENTS ||--o{ RESULTS : produces
    ASSESSMENT_COMPONENTS ||--o{ COMPONENT_MARKS : contains
```

---

## UML Diagrams

### UML Use Case Diagram

```mermaid
flowchart LR
    Admin((Admin))
    Teacher((Teacher))
    Student((Student))
    Parent((Parent))

    subgraph URAMS[URAMS Use Cases]
        UC1[Manage Teachers]
        UC2[Manage Students]
        UC3[Create Course Section]
        UC4[Enroll Student]
        UC5[Approve Result]
        UC6[Enter Marks]
        UC7[Manage Attendance]
        UC8[Submit Result]
        UC9[View Result]
        UC10[Generate Transcript]
        UC11[View Child Progress]
        UC12[View Audit Log]
    end

    Admin --> UC1
    Admin --> UC2
    Admin --> UC3
    Admin --> UC4
    Admin --> UC5
    Admin --> UC12

    Teacher --> UC6
    Teacher --> UC7
    Teacher --> UC8

    Student --> UC9
    Student --> UC10

    Parent --> UC11
```

### UML Class Diagram

```mermaid
classDiagram
    class User {
        +int id
        +string identifier
        +string fullName
        +string role
        +string status
        +login()
        +logout()
    }

    class Admin {
        +manageTeachers()
        +manageStudents()
        +createSection()
        +approveResult()
    }

    class Teacher {
        +enterMarks()
        +updateMarks()
        +manageAttendance()
        +submitResult()
    }

    class Student {
        +viewResult()
        +viewTranscript()
        +viewAttendance()
    }

    class Parent {
        +viewChildResult()
        +viewAnalytics()
    }

    class Course {
        +int id
        +string courseCode
        +string courseName
        +decimal credit
    }

    class Section {
        +int id
        +string sectionName
        +int capacity
        +string status
    }

    class Enrollment {
        +int id
        +string status
        +datetime enrolledAt
    }

    class AssessmentComponent {
        +int id
        +string name
        +decimal marksOutOf
        +decimal convertTo
    }

    class Result {
        +decimal totalMarks
        +string grade
        +decimal gradePoint
        +string status
    }

    User <|-- Admin
    User <|-- Teacher
    User <|-- Student
    User <|-- Parent

    Course "1" --> "many" Section
    Section "1" --> "many" Enrollment
    Student "1" --> "many" Enrollment
    Section "1" --> "many" AssessmentComponent
    Enrollment "1" --> "1" Result
```

### Sequence Diagram — Marks Entry and Result Approval

```mermaid
sequenceDiagram
    actor Teacher
    participant UI as Teacher UI
    participant PHP as PHP Backend
    participant DB as MySQL Database
    actor Admin

    Teacher->>UI: Enter component marks
    UI->>PHP: POST save marks
    PHP->>PHP: Validate teacher session
    PHP->>DB: Save component marks
    PHP->>DB: Recalculate total and grade
    DB-->>PHP: Updated result
    PHP-->>UI: JSON success response

    Teacher->>UI: Submit result
    UI->>PHP: POST submit result
    PHP->>DB: Create/update result submission
    PHP-->>UI: Submission success

    Admin->>PHP: Review submitted result
    PHP->>DB: Fetch submitted result
    Admin->>PHP: Approve result
    PHP->>DB: Update result status to approved
    PHP-->>Admin: Approval success
```

---

## Dependency Graphs

### Application Dependency Graph

```mermaid
graph TD
    Login[login.php] --> Dashboard[dashboard.php]
    Dashboard --> AdminModule[modules/admin.php]
    Dashboard --> TeacherModule[modules/teacher.php]
    Dashboard --> StudentModule[modules/student.php]
    Dashboard --> ParentModule[modules/parent.php]

    AdminModule --> AdminJS[academic_admin.js]
    TeacherModule --> MainJS[script.js]
    StudentModule --> MainJS
    ParentModule --> MainJS

    AdminJS --> FetchAcademic[fetch_academic_setup.php]
    AdminJS --> CreateSection[create_section.php]
    AdminJS --> EnrollStudent[enroll_student.php]
    AdminJS --> CheckPrereq[check_prerequisites.php]

    MainJS --> GetStudents[get_section_students.php]
    MainJS --> SaveMarks[save_component_mark.php]
    MainJS --> UpdateConfig[update_component_config.php]
    MainJS --> SubmitResult[submit_result.php]

    CreateSection --> DB[(MySQL Database)]
    EnrollStudent --> DB
    SaveMarks --> DB
    SubmitResult --> DB
```

### Backend Helper Dependency Graph

```mermaid
graph LR
    Config[config/database.php] --> Helpers[includes/helpers.php]
    Config --> AcademicHelpers[includes/academic_helpers.php]
    Config --> AdminHelpers[includes/admin_helpers.php]

    Helpers --> JSON[json_response]
    Helpers --> Auth[require_role]
    AcademicHelpers --> Prereq[prerequisite_check]
    AcademicHelpers --> Enrollment[enroll_student]
    AcademicHelpers --> Components[create_default_components]

    CreateSection[create_section.php] --> AcademicHelpers
    EnrollEndpoint[enroll_student.php] --> AcademicHelpers
    AdminData[fetch_admin_data.php] --> AdminHelpers
```

---

## Code Visualization

### Recommended Project Structure

```text
urams_final/
│
├── config/
│   └── database.php
│
├── database/
│   ├── 000_IMPORT_THIS_FULL_FINAL_DEMO.sql
│   ├── 007_academic_setup.sql
│   └── other_migrations.sql
│
├── includes/
│   ├── header.php
│   ├── footer.php
│   ├── helpers.php
│   ├── academic_helpers.php
│   └── admin_helpers.php
│
├── modules/
│   ├── admin.php
│   ├── teacher.php
│   ├── student.php
│   └── parent.php
│
├── public/
│   └── assets/
│       ├── css/
│       │   └── style.css
│       └── js/
│           ├── script.js
│           └── academic_admin.js
│
├── uploads/
│   └── .gitkeep
│
├── docs/
│   └── index.html
│
├── login.php
├── logout.php
├── dashboard.php
├── create_section.php
├── enroll_student.php
├── check_prerequisites.php
├── fetch_academic_setup.php
├── get_section_students.php
├── save_component_mark.php
├── update_component_config.php
├── submit_result.php
├── approve_result.php
├── README.md
└── .gitignore
```

### Code Execution Flow

```mermaid
flowchart TD
    A[dashboard.php] --> B{User Role}
    B -->|admin| C[modules/admin.php]
    B -->|teacher| D[modules/teacher.php]
    B -->|student| E[modules/student.php]
    B -->|parent| F[modules/parent.php]

    C --> G[academic_admin.js]
    D --> H[script.js]
    E --> H
    F --> H

    G --> I[Admin PHP Endpoints]
    H --> J[Teacher/Student/Parent PHP Endpoints]

    I --> K[(Database)]
    J --> K

    K --> L[JSON Response]
    L --> M[Frontend UI Update]
```

---

## Core Backend Endpoints

| Endpoint | Method | Purpose |
|---|---:|---|
| `login.php` | POST | Authenticates user |
| `logout.php` | GET | Destroys user session |
| `fetch_admin_data.php` | GET | Loads admin dashboard data |
| `fetch_academic_setup.php` | GET | Loads programs, curricula, courses, sections |
| `create_section.php` | POST | Creates course section and default components |
| `check_prerequisites.php` | POST | Checks student prerequisites |
| `enroll_student.php` | POST | Enrolls student into section |
| `get_section_students.php` | GET | Loads students for selected section |
| `save_component_mark.php` | POST | Saves component-wise marks |
| `update_component_config.php` | POST | Updates component marks-out-of and convert-to |
| `recalculate_section.php` | POST | Recalculates result for a section |
| `grade_process.php` | POST | Processes grades |
| `submit_result.php` | POST | Teacher submits result |
| `approve_result.php` | POST | Admin approves or rejects result |
| `download_marks_excel.php` | GET | Downloads marks sheet |
| `upload_marks_excel.php` | POST | Uploads marks sheet |

---

## Installation Guide

### Requirements

- XAMPP installed.
- PHP 8.x recommended.
- MySQL/MariaDB.
- Web browser.
- Git installed.

### Step 1 — Clone Repository

```bash
git clone https://github.com/your-username/urams-university-result-management-system.git
```

### Step 2 — Move Project to XAMPP

Move or copy the project folder to:

```text
C:\xampp\htdocs\urams_final
```

### Step 3 — Start Server

Open XAMPP Control Panel and start:

```text
Apache
MySQL
```

### Step 4 — Create Database

Open phpMyAdmin:

```text
http://localhost/phpmyadmin
```

Create a database:

```sql
CREATE DATABASE urams_db;
```

### Step 5 — Import SQL

Import the SQL files from the `database/` folder.

Recommended order:

```text
1. Full final demo SQL
2. Academic setup SQL
3. Any later migration SQL files
```

### Step 6 — Configure Database

Open:

```text
config/database.php
```

Check database credentials:

```php
$host = "localhost";
$dbname = "urams_db";
$username = "root";
$password = "";
```

### Step 7 — Run Project

Open browser:

```text
http://localhost/urams_final/login.php
```

---

## Default Credentials

> Change these credentials before using the system in production.

| Role | Username / ID | Password |
|---|---|---|
| Admin | `admin001` | `password123` |
| Teacher | `MRI` | `password123` |
| Teacher | `TT1` | `password123` |
| Student | `0242220005` | `password123` |
| Test Student | `0242220099` | `password123` |
| Parent | `PARENT0242220005` | `password123` |
| Test Parent | `PARENT0242220099` | `password123` |

---

## Common SQL Queries

### Select Database

```sql
USE urams_db;
```

### Show All Tables

```sql
SHOW TABLES;
```

### View Users

```sql
SELECT id, identifier, full_name, role, email, status
FROM users
ORDER BY role, id;
```

### View Course Sections

```sql
SELECT 
    cs.id,
    c.course_code,
    c.course_name,
    cs.section_name,
    tr.name AS trimester,
    t.identifier AS teacher_initial,
    t.full_name AS teacher_name,
    cs.status
FROM course_sections cs
JOIN courses c ON c.id = cs.course_id
JOIN trimesters tr ON tr.id = cs.trimester_id
LEFT JOIN users t ON t.id = cs.teacher_id
ORDER BY tr.start_date DESC, c.course_code, cs.section_name;
```

### View Enrolled Students

```sql
SELECT 
    e.id AS enrollment_id,
    s.identifier AS student_id,
    s.full_name AS student_name,
    c.course_code,
    cs.section_name
FROM enrollments e
JOIN users s ON s.id = e.student_id
JOIN course_sections cs ON cs.id = e.section_id
JOIN courses c ON c.id = cs.course_id
ORDER BY e.id DESC;
```

### View Approved Transcript Data

```sql
SET @student_uiu_id = '0242220005';

SELECT
    s.identifier AS student_id,
    s.full_name AS student_name,
    tr.name AS trimester,
    c.course_code,
    c.course_name,
    c.credit,
    cs.section_name,
    COALESCE(ssr.total_marks, r.total_marks) AS total_marks,
    COALESCE(ssr.grade, r.grade) AS grade,
    COALESCE(ssr.grade_point, r.grade_point) AS grade_point
FROM enrollments e
JOIN users s ON s.id = e.student_id
JOIN course_sections cs ON cs.id = e.section_id
JOIN courses c ON c.id = cs.course_id
JOIN trimesters tr ON tr.id = cs.trimester_id
JOIN results r ON r.enrollment_id = e.id AND r.status = 'approved'
LEFT JOIN student_section_results ssr ON ssr.enrollment_id = e.id
WHERE s.identifier = @student_uiu_id
ORDER BY tr.start_date DESC, c.course_code ASC;
```

### Calculate CGPA

```sql
SET @student_uiu_id = '0242220005';

SELECT
    s.identifier AS student_id,
    s.full_name AS student_name,
    SUM(c.credit) AS credits_completed,
    ROUND(
        SUM(c.credit * COALESCE(ssr.grade_point, r.grade_point)) / SUM(c.credit),
        2
    ) AS cgpa
FROM enrollments e
JOIN users s ON s.id = e.student_id
JOIN course_sections cs ON cs.id = e.section_id
JOIN courses c ON c.id = cs.course_id
JOIN results r ON r.enrollment_id = e.id AND r.status = 'approved'
LEFT JOIN student_section_results ssr ON ssr.enrollment_id = e.id
WHERE s.identifier = @student_uiu_id;
```

---

## Testing Checklist

### Admin Testing

- [ ] Admin can login.
- [ ] Admin can add teacher.
- [ ] Admin can add student.
- [ ] Admin can create course section.
- [ ] Admin can assign teacher to section.
- [ ] Admin can enroll student.
- [ ] Admin can approve result.
- [ ] Admin can reject result.
- [ ] Admin can view audit logs.

### Teacher Testing

- [ ] Teacher can login.
- [ ] Teacher can view assigned sections.
- [ ] Teacher can select trimester, course, and section.
- [ ] Teacher can enter marks.
- [ ] Teacher can update component configuration.
- [ ] Teacher can apply grace marks.
- [ ] Teacher can manage attendance.
- [ ] Teacher can submit result.
- [ ] Teacher cannot edit approved section marks.

### Student Testing

- [ ] Student can login.
- [ ] Student can view approved result.
- [ ] Student cannot view unapproved result.
- [ ] Student can view transcript.
- [ ] Student can view GPA/CGPA.

### Parent Testing

- [ ] Parent can login.
- [ ] Parent can view linked child result.
- [ ] Parent cannot edit data.
- [ ] Parent can view analytics.

---

## Troubleshooting

### Error: No database selected

Run:

```sql
USE urams_db;
```

Then run the query again.

### Error: Invalid JSON response

Possible reasons:

- PHP endpoint returned HTML/warning instead of JSON.
- Session role is invalid.
- SQL error occurred.
- File path is wrong.
- User logged into multiple roles in the same browser session.

Fix:

```text
Logout from all roles.
Login with only one role.
Open F12 → Network → Response.
Check actual backend error.
```

### Error: 403 Forbidden

Reason:

```text
The current logged-in user does not have permission for that endpoint.
```

Fix:

```text
Logout first, then login with the correct role.
```

### Teacher page shows 0 students

Possible reasons:

- Student is not enrolled in that section.
- Wrong trimester/course/section selected.
- Teacher is not assigned to that section.
- Student enrollment status is inactive.

Fix:

```text
Admin → Academic Setup → Enroll Student
Teacher → Select Trimester/Course/Section → Apply
```

### Transcript is blank

Possible reasons:

- Result is not approved.
- Section is not approved.
- Student has no enrollment.
- Grade process not completed.

Fix:

```text
Teacher submits result.
Admin approves result.
Student refreshes transcript page.
```

---

## Future Improvements

- RESTful API structure.
- Laravel migration in future version.
- Export transcript as official PDF.
- Email notification system.
- Role-based permission middleware.
- Better charting library.
- Bulk student import.
- Bulk teacher import.
- Advanced analytics dashboard.
- Secure password reset system.
- Production-ready deployment support.

---

## Security Notes

This project is developed for academic demonstration. Before production use:

- Hash passwords securely using `password_hash()`.
- Use HTTPS.
- Validate all inputs.
- Use prepared statements for every SQL query.
- Restrict direct file access.
- Implement CSRF protection.
- Remove demo credentials.
- Protect upload directories.
- Separate `.env` configuration from source code.

---

## License

This project is prepared for academic and educational purposes.

---

## Author

**URAMS Project Team**  
University Result and Academic Management System
