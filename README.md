# 🌌 SpaceDrop

**SpaceDrop** is a decentralized, high-speed file distribution platform built with Flutter. It transforms any device on a local network into a powerful local server, allowing users to seamlessly broadcast, manage, and share files with multiple connected clients simultaneously—completely offline and without relying on the public internet.

---

## 🎯 System Requirements

### Functional Requirements
- **Lobby Creation & Discovery:** Users can create virtual sharing lobbies and other users on the same LAN/Wi-Fi can discover them automatically.
- **File Distribution:** A host (and authorized co-hosts) can upload and share multiple files to the lobby.
- **Concurrent Downloading:** Clients can download multiple shared files concurrently.
- **Participant Management:** The host must approve/reject join requests, kick users, and delegate moderation powers (co-host).
- **Access Control:** Lobbies can optionally be secured via PIN.
- **History Tracking:** The system must maintain a history log of all past downloaded files, their status, and storage locations.

### Non-Functional Requirements
- **High Availability & Fault Tolerance:** If a file transfer is interrupted, the client should be able to resume downloading from the last byte via range requests.
- **Zero Configuration:** The app must not require users to input IP addresses or port numbers manually.
- **Low Latency Synchronization:** The lobby state (files, users, pending requests) must sync in real-time across all connected clients.
- **Security & Integrity:** File downloads must be verified via SHA-256 checksums post-transfer to ensure no data corruption occurred over the local network.
- **Offline Capability:** The system must function entirely on Local Area Networks (LAN) without internet access.

---

## 🏗️ High-Level Design (HLD)

SpaceDrop is a localized client-server architecture dynamically established per session.

1. **Discovery Layer (mDNS):** 
   - Acts as the service registry. The Host broadcasts `_spacedrop._tcp` with metadata. Clients listen and discover available hosts.
2. **Orchestration/Control Plane (TCP Socket):** 
   - The primary communication channel for real-time state. Handles user authentication, connection lifecycle, and broadcasting JSON commands (`file_list_update`, `kick_user`, `promote_cohost`).
3. **Data Plane (HTTP Server):** 
   - A localized HTTP server running exclusively on the Host. Dedicated to moving raw binary data for uploading (POST) and downloading (GET with byte-range support).
4. **Local Persistence (SQFlite):** 
   - Manages the local device state (user preferences, download directory) and historic transfer logs.

---

## 🧩 Low-Level Design (LLD)

### Data Models
- **Lobby:** `lobbyId`, `hostIp`, `hostTcpPort`, `hostHttpPort`, `lobbyName`, `hostDeviceName`, `requiresPin`.
- **Participant:** `participantId`, `deviceId`, `deviceName`, `status` (PENDING/APPROVED), `permission` (HOST/CO_HOST/VIEWER), `sessionToken`.
- **SharedFile:** `fileId`, `fileName`, `fileSize`, `checksum`, `path` (host side).
- **HistoryItem:** `id`, `fileName`, `fileSize`, `transferType` (DOWNLOAD/UPLOAD), `status` (COMPLETED/FAILED), `timestamp`, `filePath` (client side).

### State Management (Riverpod)
- **HostNotifier:** Manages the active TCP Server, HTTP Server, active `participants`, `pendingRequests`, and the `sharedFiles` array.
- **ClientNotifier:** Manages the TCP Socket connection to the Host, handles incoming control messages to update UI state, and tracks HTTP download progress via `HttpClient`.

### Protocol Breakdown
- **TCP Control Payloads (JSON):** 
  - `{"command": "join_request", "deviceId": "...", "deviceName": "..."}`
  - `{"command": "file_list_update", "files": [...]}`
  - `{"command": "pending_requests_update", "requests": [...]}`
- **HTTP Transfer Protocol:**
  - **Download:** `GET /download?fileId={id}&token={token}`
    - Header: `Range: bytes=0-4096` -> Response: `206 Partial Content`.
  - **Upload:** `POST /upload?token={token}`
    - Header: `X-File-Name: document.pdf` -> Body: raw binary file stream.

---

## 🔄 Step-by-Step System Working Flow

### 1. Host Initialization
1. Host clicks "Create Lobby".
2. System binds a TCP `ServerSocket` and an `HttpServer` to dynamic open ports.
3. System initiates an mDNS broadcast containing the Host's IP, Lobby Name, and assigned ports.
4. Host enters the Lobby screen and awaits clients.

### 2. Client Discovery & Handshake
1. Client opens the app and begins mDNS discovery.
2. Client detects the Host's broadcast and selects the Lobby.
3. Client establishes a TCP connection to the Host's TCP Port.
4. Client sends a JSON `join_request` over TCP (with PIN if required).
5. Host's TCP Server parses the request and adds the Client to `pendingRequests`.

### 3. Approval & State Sync
1. Host (or Co-host) clicks "Approve" on the Client's request.
2. Host generates a secure, randomized `sessionToken` for the Client.
3. Host sends `join_approved` with the token via TCP to the specific Client.
4. Host broadcasts `file_list_update` to all connected clients to synchronize the shared files view.

### 4. File Sharing & Streaming
**Uploading (Co-host/Host):**
1. User selects a file via FilePicker.
2. Client sends an HTTP POST request to the Host's HTTP server containing the `sessionToken` and file bytes.
3. Host HTTP Server validates the token permissions, saves the file to a temp directory, calculates the SHA-256 checksum, and adds it to the `SharedFile` state.
4. Host broadcasts the updated file list over TCP.

**Downloading (Viewer):**
1. User selects a file and clicks Download.
2. Client sends an HTTP GET request to the Host's HTTP server with their `sessionToken` and the requested `fileId`.
3. Client streams the response to their local `Downloads` directory, tracking progress.
4. Upon completion, Client calculates the SHA-256 checksum and compares it to the Host's metadata.
5. The transfer is logged into the local SQLite `transfer_history` database.

---

## 🛡️ Roles & Permissions

SpaceDrop enforces strict RBAC (Role-Based Access Control) to maintain order in large networks.

| Capability | Host (Owner) | Co-host (Moderator) | Viewer (Participant) |
| :--- | :---: | :---: | :---: |
| **Download Files** | ✅ | ✅ | ✅ |
| **Upload Files** | ✅ | ✅ | ❌ |
| **Remove Files** | ✅ | ✅ | ❌ |
| **Approve/Reject Users** | ✅ | ✅ | ❌ |
| **Promote Users** | ✅ | ❌ | ❌ |
| **Kick Users** | ✅ | ❌ | ❌ |
| **Close Lobby** | ✅ | ❌ | ❌ |

---

## 🛠️ Tech Stack

- **Framework:** Flutter / Dart
- **Architecture:** MVVM with Feature-first Folder Structure
- **State Management:** Riverpod
- **Networking:** `dart:io` (Socket, ServerSocket, HttpServer)
- **Local Database:** SQFlite (SQLite)
- **Cryptography:** `crypto` (SHA-256 Checksums)
- **Local Services:** `shared_preferences` (Settings), `path_provider` (Directory Access)
