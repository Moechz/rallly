# Notices — Rallly for TerraMaster TOS (`rallydocker`)

**Package version:** `4.17.2-1`
**Packager:** Moechz (independent community package)
**Upstream application:** Rallly 4.17.2, <https://github.com/lukevella/rallly>
**App Center:** <https://developer.terra-master.com>

This file records the licences, image provenance and trademark attributions for
the Rallly TOS package. It is not the licence of the upstream application; the
upstream licence text and source are available at the links below.

---

## 1. Upstream application — Rallly 4.17.2

| Item | Value |
|---|---|
| Project | Rallly — open-source scheduling and date-polling software |
| Upstream source | <https://github.com/lukevella/rallly> (tag `v4.17.2`) |
| Licence | **GNU Affero General Public License, version 3 or later (AGPL-3.0-or-later)** |
| Licence text | <https://github.com/lukevella/rallly/blob/main/LICENSE> |
| Copyright | Copyright Luke Vella and Rallly contributors |
| Container image | `lukevella/rallly:4.17.2` (official image on Docker Hub) |
| Multi-arch index digest | `lukevella/rallly@sha256:e43d8f750728ba500f512c4f3ae2c26d66c2666e68447659825a8ed2618f7ced` |
| `linux/amd64` manifest | `sha256:b8e0ea75cb2c34e42a02a6d09a8c72d21f62b95b67e81fefe868f32e8efbf605` |
| `linux/arm64` manifest | `sha256:e5410e445545bfc0c1f28cf226950cdeb4f51522424422b762c5b9a946245d41` |
| Base runtime | Debian slim with Node.js 24 (image built 2026-11-23) |

The TOS package **does not contain or modify Rallly source code**. It contains a
Compose file that pulls the official image unmodified from Docker Hub, the TOS
metadata and icon, and a small wrapper script that prepares secrets, the public
base URL, database migrations and the initial administrator account. Because the
image is pulled by the user's Docker daemon, the image itself is distributed by
the upstream project under the AGPL-3.0-or-later terms above; the corresponding
source is available at the upstream repository and tag. The wrapper is a
separate work and is not a derivative of the Rallly source.

## 2. Database — PostgreSQL 16.16

| Item | Value |
|---|---|
| Image | `postgres:16.16-alpine` (official Docker Hub image) |
| Image digest | `postgres@sha256:f2f98726820d0342055351c6e9d36e705f5bfffb3dd53ff556325114b08afb6d` |
| Licence | **PostgreSQL License** (permissive, BSD-style) |
| Licence text | <https://www.postgresql.org/about/licence/> |
| Copyright | Copyright The PostgreSQL Global Development Group |
| Project | <https://www.postgresql.org/> |

The package runs the unmodified official PostgreSQL image as a private,
non-root service. No PostgreSQL source code or binaries are redistributed in
this repository.

PostgreSQL stays on 16.x on purpose: an existing `db/` cluster created by
`4.17.0-1` keeps working. Moving to PostgreSQL 17/18 needs `pg_upgrade` or a
dump/restore and is therefore not done silently.

## 3. Base operating-system components

The images above are Debian/Alpine based. Debian, Alpine and the packages
inside the images are distributed under their own open-source licences (MIT,
BSD, Apache-2.0, GPL, PostgreSQL and others). The exact package set and licence
files are part of each image and can be inspected with:

```bash
docker run --rm lukevella/rallly:4.17.2 cat /etc/debian_version
docker run --rm lukevella/rallly:4.17.2 ls /usr/share/doc | head
docker run --rm postgres:16.16-alpine cat /etc/alpine-release
```

No operating-system binaries are redistributed in this repository.

## 4. Trademarks

- **Rallly** and the Rallly logo are trademarks of the Rallly project / Luke
  Vella. The icon shipped with this package is the upstream application icon,
  used only to identify the application in the App Center.
- **TerraMaster**, **TOS** and **App Center** are trademarks of TerraMaster.
- **Docker** and **Docker Hub** are trademarks of Docker, Inc.
- **PostgreSQL** is a trademark of the PostgreSQL Community Association of
  Canada.

This package is an independent community submission by Moechz. It is not
affiliated with, endorsed by or sponsored by the Rallly project, TerraMaster or
Docker, Inc.

## 5. Package tooling

The packaging files in this repository (Compose file, wrapper entrypoint, TOS
metadata, `.lang`, `.svg` export and build scripts) are released under the MIT
licence; see [LICENSE](LICENSE). They do not contain upstream Rallly code. The
icon is the upstream application icon, covered by the upstream licence and
trademark notice above.

## 6. No warranty

The package is provided "as is", without warranty of any kind. The upstream
project and the packager are not liable for data loss, service interruption or
damage resulting from the use of this package. Back up
`/Volume1/DockerAppData/rallydocker/` before upgrading or uninstalling.
