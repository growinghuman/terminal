# iOS Terminal App 개발 계획서

## 1. 프로젝트 개요

Termius, Blink Shell과 유사한 **iOS용 전문 터미널/SSH 클라이언트 앱** 개발 프로젝트.
원격 서버 관리, 개발 작업을 iOS 기기에서 수행할 수 있는 데스크탑급 터미널 환경을 제공한다.

### 프로젝트명 (가칭): **ShellCraft**

---

## 2. 경쟁 앱 분석

### 2.1 Termius
| 항목 | 내용 |
|------|------|
| 가격 | 무료(기본) / $15/월(프리미엄) |
| 핵심 기능 | SSH, SFTP, Mosh, Port Forwarding, Snippets |
| 차별점 | Cross-platform 동기화, End-to-end 암호화 Vault, AI Agent 연동 |
| 최근 동향 | Post-quantum 키 교환, Nerd Font 지원, CJK 입력 지원, AI 코딩 에이전트 통합 |

### 2.2 Blink Shell
| 항목 | 내용 |
|------|------|
| 가격 | $19.99/년 (14일 무료 체험) |
| 핵심 기능 | Mosh(핵심), SSH, 로컬 Unix 명령어, Split View |
| 차별점 | 오픈소스(GPL3), Mosh 클라이언트 Swift 재구현, 4K 외부 디스플레이 |
| 렌더링 | Chromium HTerm 기반 고속 렌더링 |

### 2.3 기타 경쟁 앱
| 앱 | 특징 |
|------|------|
| **Secure ShellFish** | SwiftTerm 기반, Apple 생태계 깊은 통합 (Files.app, Shortcuts) |
| **a-Shell** | 로컬 Unix 터미널, C/C++→WebAssembly 컴파일, Python/JS 실행 |
| **iSH Shell** | x86 에뮬레이션으로 Linux 환경 제공, Alpine Linux 패키지 |
| **rootshell** | 로컬 쉘 + SSH, 창 투명도, macOS 버전도 제공 |

---

## 3. 핵심 기능 스펙

### Phase 1: MVP (Minimum Viable Product)

#### 3.1 SSH 클라이언트
- SSH2 프로토콜 지원 (v2 only)
- 인증 방식:
  - Password
  - Public Key (RSA, ECDSA, Ed25519)
  - SSH Certificate
  - FIDO2/WebAuthn 하드웨어 키
- 기능:
  - Interactive shell session
  - Local port forwarding (`-L`)
  - Remote port forwarding (`-R`)
  - Dynamic port forwarding (SOCKS proxy, `-D`)
  - ProxyJump (`-J`) / ProxyCommand
  - SSH Agent forwarding
  - Keep-alive 설정
  - Known hosts 관리

#### 3.2 터미널 에뮬레이터
- VT100/VT220/xterm-256color 호환
- 기능:
  - True Color (24-bit) 지원
  - Unicode 완전 지원 (Emoji, CJK, Combining Characters)
  - 스크롤백 버퍼 (설정 가능한 크기)
  - 텍스트 선택 및 복사/붙여넣기
  - URL 감지 및 터치로 열기
  - 벨 알림 (시각/진동)

#### 3.3 연결 관리
- 호스트 목록 관리 (추가/편집/삭제/그룹화)
- 연결 프로필 저장
  - 호스트, 포트, 사용자명
  - 인증 방법
  - 터미널 설정 (테마, 폰트, 크기)
  - 환경 변수
- 키 관리 (생성/가져오기/내보내기)

#### 3.4 UI/UX
- 멀티탭 인터페이스
- iPad Split View / Slide Over 지원
- 가상 키보드:
  - 특수 키 바 (Ctrl, Alt, Esc, Tab, 방향키 등)
  - 제스처 기반 입력 (스와이프로 방향키, 탭으로 Tab)
- 블루투스 키보드 완전 지원
- 키보드 단축키 (Cmd+T 새 탭, Cmd+W 닫기 등)
- 다크모드 / 라이트모드
- 터미널 테마 시스템 (기본 10+ 테마 제공)
- 폰트 선택 (Nerd Font 지원)
- Pinch to Zoom (폰트 크기 조절)

### Phase 2: 확장 기능

#### 3.5 SFTP 파일 관리
- 그래픽 파일 브라우저
- 파일 업로드/다운로드
- 파일 편집 (내장 텍스트 에디터)
- 파일 권한 관리
- iOS Files.app 연동 (FileProvider Extension)
- 드래그 앤 드롭 지원

#### 3.6 Mosh (Mobile Shell)
- Mosh 프로토콜 지원
- 네트워크 로밍 (Wi-Fi ↔ 셀룰러 전환 시 연결 유지)
- 지능형 로컬 에코 (저지연 입력)
- 자동 재연결
- Mosh 자동 설치 (`--install-static` 방식)

#### 3.7 Snippets & 자동화
- 자주 사용하는 명령어 저장
- 변수 치환 지원 (`${HOST}`, `${USER}` 등)
- iOS Shortcuts 앱 연동
- URL Scheme 지원 (`shellcraft://connect?host=...`)
- 명령어 히스토리 (전역)

### Phase 3: 프리미엄 기능

#### 3.8 클라우드 동기화
- iCloud 기반 동기화 (호스트, 키, 스니펫, 설정)
- End-to-end 암호화
- 선택적 동기화 항목 설정

#### 3.9 고급 기능
- 외부 디스플레이 지원 (4K 해상도)
- 세션 로깅 (자동 기록 및 검색)
- 세션 공유 (읽기 전용)
- Telnet 지원
- 로컬 쉘 (샌드박스 내 제한된 명령어)
- 알림: 장시간 명령 실행 완료 시 푸시 알림

---

## 4. 기술 스택

### 4.1 개발 환경
| 항목 | 선택 | 이유 |
|------|------|------|
| 언어 | **Swift 5.9+** | Apple 공식 언어, 성능 및 안정성 |
| UI 프레임워크 | **SwiftUI + UIKit** | SwiftUI 기본, 터미널 렌더링은 UIKit |
| 최소 iOS 버전 | **iOS 17.0** | 최신 API 활용, 시장 커버리지 95%+ |
| 아키텍처 | **MVVM + Clean Architecture** | 테스트 용이성, 모듈화 |
| 패키지 관리 | **Swift Package Manager** | Apple 공식, 의존성 최소화 |

### 4.2 핵심 라이브러리

#### 터미널 에뮬레이션
| 라이브러리 | 설명 | 라이선스 |
|------------|------|----------|
| **[SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)** | VT100/xterm 터미널 에뮬레이터 (UIKit/AppKit) | MIT |

- Miguel de Icaza 개발 (Xamarin/Mono 창시자)
- 상용 앱에서 검증됨 (Secure ShellFish, La Terminal)
- iOS UIKit 네이티브 뷰 제공 (`iOSTerminalView`)
- Unicode, Emoji, CJK 완벽 지원
- 1,275+ GitHub Stars, 활발한 유지보수

#### SSH 구현
| 옵션 | 설명 | 추천 |
|------|------|------|
| **[SwiftNIO SSH](https://github.com/apple/swift-nio-ssh)** | Apple 공식 순수 Swift SSH 구현 | ★★★★★ |
| [SwiftSH](https://github.com/Frugghi/SwiftSH) | libssh2 래퍼 | ★★★☆☆ |
| [libssh2-apple](https://gitee.com/fandongtongxue_admin/libssh2-apple) | libssh2 Swift Package | ★★★☆☆ |

**권장: SwiftNIO SSH**
- Apple 공식 라이브러리
- 순수 Swift 구현 (C 의존성 없음)
- SwiftNIO 기반 비동기 네트워킹
- 활발한 유지보수 및 보안 패치

#### Mosh 구현
- Blink Shell의 Swift Mosh 재구현을 참고 (GPL3)
- 또는 libmosh C 라이브러리 빌드 + Swift 브릿지
- State Synchronization Protocol (SSP) 구현
- AES-128 OCB3 모드 암호화

#### 기타 의존성
| 라이브러리 | 용도 |
|------------|------|
| **SwiftNIO** | 비동기 네트워킹 기반 |
| **KeychainAccess** | 키/비밀번호 안전 저장 |
| **SwiftUI-Introspect** | SwiftUI ↔ UIKit 브릿지 |
| **GRDB.swift** 또는 **SwiftData** | 로컬 데이터베이스 |

### 4.3 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────┐
│                   Presentation                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ SwiftUI  │ │ Terminal │ │   SFTP Browser   │ │
│  │  Views   │ │   View   │ │      View        │ │
│  └────┬─────┘ └────┬─────┘ └───────┬──────────┘ │
│       │             │               │            │
│  ┌────▼─────────────▼───────────────▼──────────┐ │
│  │              ViewModels (MVVM)               │ │
│  └────┬─────────────┬───────────────┬──────────┘ │
├───────┼─────────────┼───────────────┼────────────┤
│       │         Domain Layer        │            │
│  ┌────▼─────┐ ┌─────▼─────┐ ┌──────▼─────────┐ │
│  │  Host    │ │  Session  │ │   Key/Auth     │ │
│  │ Manager  │ │  Manager  │ │   Manager      │ │
│  └────┬─────┘ └─────┬─────┘ └──────┬─────────┘ │
├───────┼─────────────┼───────────────┼────────────┤
│       │        Infrastructure       │            │
│  ┌────▼─────┐ ┌─────▼─────┐ ┌──────▼─────────┐ │
│  │ SwiftNIO │ │ SwiftTerm │ │   Keychain     │ │
│  │   SSH    │ │  Engine   │ │   Storage      │ │
│  └────┬─────┘ └─────┬─────┘ └──────┬─────────┘ │
│       │             │               │            │
│  ┌────▼─────────────▼───────────────▼──────────┐ │
│  │           Network / OS Layer                 │ │
│  │     (TCP/UDP Sockets, iOS Sandbox)           │ │
│  └──────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

---

## 5. iOS 플랫폼 제약 및 대응 전략

### 5.1 백그라운드 실행 제한
| 제약 | 대응 |
|------|------|
| 백그라운드 3분 후 세션 중단 | Mosh 프로토콜로 자동 재연결 |
| 백그라운드 소켓 유지 불가 | `beginBackgroundTask` 활용 (최대 ~30초 추가) |
| 장시간 백그라운드 불가 | 사용자에게 명확한 UX로 안내 |

### 5.2 샌드박스 제한
| 제약 | 대응 |
|------|------|
| 로컬 파일시스템 접근 제한 | 앱 샌드박스 내 파일만 접근 |
| 시스템 쉘 실행 불가 | SSH/Mosh를 통한 원격 쉘 집중 |
| 다른 앱 데이터 접근 불가 | Files.app 연동 (FileProvider) |
| 임의 바이너리 실행 불가 | 내장 유틸리티만 제공 |

### 5.3 App Store 심사 고려사항
- SSH/터미널 앱은 App Store에서 허용됨 (Termius, Blink 등 사례)
- Mosh GPL3 라이선스: Mosh 저작자가 App Store 배포를 명시적으로 허용
- 암호화 수출 규정 (ERN) 신고 필요 (SSH 암호화 사용)
- 개인정보 처리방침 필수 (네트워크 연결 정보)

---

## 6. 프로젝트 구조

```
ShellCraft/
├── ShellCraft.xcodeproj
├── Package.swift                    # SPM 의존성
├── ShellCraft/
│   ├── App/
│   │   ├── ShellCraftApp.swift      # 앱 엔트리 포인트
│   │   └── AppDelegate.swift
│   ├── Core/
│   │   ├── SSH/
│   │   │   ├── SSHClient.swift      # SSH 연결 관리
│   │   │   ├── SSHSession.swift     # 세션 래퍼
│   │   │   ├── SSHChannel.swift     # 채널 관리
│   │   │   ├── SFTPClient.swift     # SFTP 클라이언트
│   │   │   └── PortForwarding.swift # 포트 포워딩
│   │   ├── Terminal/
│   │   │   ├── TerminalManager.swift    # SwiftTerm 래퍼
│   │   │   ├── TerminalTheme.swift      # 테마 시스템
│   │   │   └── TerminalKeyboard.swift   # 가상 키보드
│   │   ├── Mosh/
│   │   │   ├── MoshClient.swift     # Mosh 프로토콜
│   │   │   └── MoshSession.swift    # Mosh 세션
│   │   ├── Auth/
│   │   │   ├── KeyManager.swift     # SSH 키 관리
│   │   │   ├── KeychainHelper.swift # Keychain 접근
│   │   │   └── AuthMethod.swift     # 인증 방식
│   │   └── Sync/
│   │       ├── iCloudSync.swift     # iCloud 동기화
│   │       └── SyncManager.swift
│   ├── Models/
│   │   ├── Host.swift               # 호스트 모델
│   │   ├── ConnectionProfile.swift  # 연결 프로필
│   │   ├── Snippet.swift            # 스니펫 모델
│   │   └── SessionLog.swift         # 세션 로그
│   ├── ViewModels/
│   │   ├── HostListViewModel.swift
│   │   ├── TerminalViewModel.swift
│   │   ├── SFTPViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── HostList/
│   │   │   ├── HostListView.swift
│   │   │   ├── HostDetailView.swift
│   │   │   └── AddHostView.swift
│   │   ├── Terminal/
│   │   │   ├── TerminalContainerView.swift
│   │   │   ├── TerminalTabBar.swift
│   │   │   └── VirtualKeyboardView.swift
│   │   ├── SFTP/
│   │   │   ├── SFTPBrowserView.swift
│   │   │   └── FileDetailView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ThemePickerView.swift
│   │   │   └── KeyManagementView.swift
│   │   └── Common/
│   │       ├── SearchBar.swift
│   │       └── EmptyStateView.swift
│   ├── Extensions/
│   ├── Resources/
│   │   ├── Themes/                  # 터미널 테마 JSON
│   │   ├── Fonts/                   # Nerd Fonts 번들
│   │   └── Assets.xcassets
│   └── Info.plist
├── ShellCraftTests/
├── ShellCraftUITests/
└── README.md
```

---

## 7. 개발 로드맵

### Phase 1: MVP — 핵심 SSH 터미널 (8~12주)

| 주차 | 마일스톤 | 상세 |
|------|----------|------|
| 1-2 | 프로젝트 셋업 | Xcode 프로젝트, SPM 의존성, CI/CD, 기본 아키텍처 |
| 3-4 | SSH 연결 | SwiftNIO SSH 통합, 기본 인증 (password, pubkey) |
| 5-6 | 터미널 에뮬레이션 | SwiftTerm 통합, 기본 터미널 UI, 가상 키보드 |
| 7-8 | 호스트 관리 | 호스트 목록 CRUD, 연결 프로필, 키 관리 |
| 9-10 | UI 완성 | 멀티탭, 테마 시스템, 폰트 설정, 키보드 단축키 |
| 11-12 | QA & 최적화 | 버그 수정, 성능 최적화, TestFlight 배포 |

#### Phase 1 완료 기준
- [x] SSH로 원격 서버 접속 가능
- [x] 터미널에서 명령어 입력/출력 정상 동작
- [x] 호스트 정보 저장/불러오기
- [x] 멀티탭 세션 지원
- [x] iPhone + iPad 지원

### Phase 2: 확장 기능 (8~10주)

| 주차 | 마일스톤 | 상세 |
|------|----------|------|
| 1-3 | SFTP | 파일 브라우저, 업/다운로드, Files.app 연동 |
| 4-6 | Mosh | Mosh 프로토콜 구현, 자동 재연결, 로컬 에코 |
| 7-8 | 스니펫 & 자동화 | 스니펫 관리, Shortcuts 연동, URL Scheme |
| 9-10 | 포트 포워딩 | Local/Remote/Dynamic 포워딩 UI |

### Phase 3: 프리미엄 & 출시 (6~8주)

| 주차 | 마일스톤 | 상세 |
|------|----------|------|
| 1-2 | iCloud 동기화 | 호스트, 키, 스니펫 동기화 |
| 3-4 | 세션 로깅 | 자동 로그 기록, 검색, 내보내기 |
| 5-6 | 고급 UI | 외부 디스플레이, Split View 개선 |
| 7-8 | App Store 출시 | 심사 준비, 마케팅, 출시 |

---

## 8. 수익 모델

### Freemium 구조

| 기능 | Free | Pro ($4.99/월) |
|------|------|----------------|
| SSH 연결 | 2개 호스트 | 무제한 |
| Mosh | ✕ | ✓ |
| SFTP | ✕ | ✓ |
| 포트 포워딩 | Local만 | 전체 |
| 테마 | 5개 | 전체 (20+) |
| 스니펫 | 10개 | 무제한 |
| iCloud 동기화 | ✕ | ✓ |
| 세션 로깅 | ✕ | ✓ |
| 키 유형 | RSA만 | 전체 |

---

## 9. 차별화 전략

Termius, Blink Shell 등 기존 앱과의 차별화 포인트:

### 9.1 UX 혁신
- **스마트 커맨드 팔레트**: Spotlight 스타일의 통합 검색 (호스트, 스니펫, 히스토리)
- **제스처 커스터마이징**: 사용자 정의 제스처 → 명령어 매핑
- **위젯**: iOS 홈 화면 위젯으로 서버 상태 모니터링

### 9.2 개발자 친화적
- **Git 통합**: 터미널 내 git 상태 표시 바
- **구문 강조**: cat/less 출력 시 코드 구문 강조
- **마크다운 미리보기**: README 등 마크다운 파일 인라인 렌더링

### 9.3 보안 강화
- **Biometric 인증**: Face ID/Touch ID로 앱 잠금
- **1Password/Bitwarden 연동**: 비밀번호 자동 완성
- **SSH 인증서 갱신 알림**

### 9.4 AI 연동 (Phase 3+)
- **명령어 제안**: 컨텍스트 기반 명령어 자동 완성
- **에러 설명**: 에러 메시지 AI 분석 및 해결 방안 제안
- **자연어 → 명령어**: "디스크 사용량 확인해줘" → `df -h`

---

## 10. 기술적 도전과 해결 방안

| 도전 | 해결 방안 |
|------|-----------|
| iOS 백그라운드 3분 제한 | Mosh 프로토콜 활용, 빠른 재연결 UX |
| SSH 키 보안 저장 | iOS Keychain + Secure Enclave 활용 |
| 터미널 성능 (대량 출력) | SwiftTerm의 최적화된 렌더링 + 가상 스크롤 |
| 네트워크 전환 시 끊김 | Mosh SSP 프로토콜 + NWPathMonitor 모니터링 |
| 다양한 SSH 서버 호환성 | SwiftNIO SSH의 포괄적 프로토콜 지원 + 광범위 테스트 |
| iPad 멀티태스킹 | UIKit Scene 기반 멀티 윈도우 구현 |
| 가상 키보드 한계 | 커스텀 Input Accessory View + 제스처 시스템 |

---

## 11. 테스트 전략

### 단위 테스트
- SSH 연결/인증 로직
- 터미널 에뮬레이션 정확성 (vttest 스위트)
- 호스트/키 관리 CRUD
- 데이터 모델 직렬화

### 통합 테스트
- 실제 SSH 서버 연결 (Docker 기반 테스트 환경)
- SFTP 파일 전송 정확성
- Mosh 연결/재연결 시나리오

### UI 테스트
- 호스트 추가/편집 플로우
- 터미널 입력/출력 플로우
- 멀티탭 전환
- iPad Split View

### 성능 테스트
- 대량 터미널 출력 (100MB+ 로그 파일 cat)
- 동시 다중 세션 (10+ 탭)
- 메모리 누수 테스트

---

## 12. 필요 리소스

### 개발팀
| 역할 | 인원 | 핵심 역량 |
|------|------|-----------|
| iOS 리드 개발자 | 1 | Swift, UIKit, SwiftUI, 네트워킹 |
| iOS 개발자 | 1-2 | SwiftUI, Core Data/SwiftData |
| 백엔드 (선택) | 0-1 | iCloud 동기화, 구독 관리 |
| 디자이너 | 1 | iOS HIG, 터미널 UX |
| QA | 1 | iOS 테스팅, SSH 서버 환경 |

### 필수 계정/장비
- Apple Developer Account ($99/년)
- 테스트 기기: iPhone, iPad (다양한 크기)
- 외부 키보드 (블루투스)
- 테스트용 Linux 서버 (SSH/Mosh)
- CI/CD: Xcode Cloud 또는 GitHub Actions

---

## 13. 결론

iOS용 터미널 앱 개발은 **기술적으로 충분히 가능**하다. SwiftTerm(터미널 에뮬레이션)과 SwiftNIO SSH(SSH 구현)라는 검증된 오픈소스 라이브러리가 존재하며, Termius와 Blink Shell이 이미 시장에서 성공적으로 운영되고 있어 기술적 실현 가능성이 입증되어 있다.

**성공의 핵심 요소:**
1. 안정적인 SSH/터미널 엔진 — SwiftTerm + SwiftNIO SSH 조합으로 해결
2. 뛰어난 모바일 UX — 터치 최적화된 가상 키보드와 제스처 시스템
3. iOS 제약 극복 — Mosh 프로토콜로 백그라운드 제한 대응
4. 차별화 — 스마트 커맨드 팔레트, AI 연동 등 기존 앱에 없는 기능

Phase 1 MVP는 검증된 라이브러리를 활용하여 구현할 수 있으며, 이후 SFTP, Mosh, 클라우드 동기화 등을 단계적으로 추가하는 전략이 적절하다.

---

## 참고 자료

- [SwiftTerm - GitHub](https://github.com/migueldeicaza/SwiftTerm)
- [SwiftNIO SSH - Apple GitHub](https://github.com/apple/swift-nio-ssh)
- [Blink Shell - GitHub](https://github.com/blinksh/blink)
- [Termius](https://termius.com)
- [Mosh - Mobile Shell](https://mosh.org)
- [a-Shell](https://holzschu.github.io/a-Shell_iOS/)
- [SwiftSH](https://github.com/Frugghi/SwiftSH)
