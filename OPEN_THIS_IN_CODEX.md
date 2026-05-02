# PineWave: 다른 컴퓨터에서 Codex에게 바로 보여줄 작업 지시서

이 프로젝트는 이미 어느 정도 구현된 Flutter + Android 네이티브 오디오 앱입니다.

중요:

- 이 프로젝트를 새로 재구현하지 말고, 현재 소스를 기준으로 그대로 이어서 작업하세요.
- `third_party/` 안의 Freeverb3, LAME 소스를 삭제하거나 교체하지 마세요.
- `android/app/src/main/cpp/`와 `android/app/src/main/kotlin/`은 핵심 오디오 엔진입니다.
- 저장/믹스/split은 Android SAF 기반이라 단순 파일 경로 방식으로 되돌리면 안 됩니다.

## 1. 프로젝트 정체

- 앱 이름: `PineWave`
- 목적: 모바일에서 DAW 스타일로 여러 트랙의 오디오를 로드하고, 파형을 보며 재생/녹음/믹스하는 앱
- 현재 우선 플랫폼: Android
- 프레임워크: Flutter
- 오디오 엔진: Android Kotlin + C++ native bridge
- 리버브: Freeverb3
- MP3 인코딩: LAME

## 2. 이 프로젝트에서 먼저 해야 할 일

이 순서대로 진행하세요.

1. 현재 PC에 Flutter/Android/JDK 환경이 준비되어 있는지 확인
2. 부족한 툴 설치
3. 프로젝트 의존성 복구
4. Android 빌드 가능 상태 확인
5. 앱의 현재 기능/구조를 빠르게 파악
6. 사용자의 다음 요청을 이어서 구현

## 3. 필요한 설치 항목

Windows 기준으로 아래가 필요합니다.

- Git
- Flutter SDK stable
- Dart SDK
- JDK 17
- Android Studio 또는 Android SDK 명령줄 툴
- Android SDK Platform
- Android SDK Build-Tools
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- Android NDK (Side by side)
- CMake 3.22.1 이상

권장 버전:

- Flutter: `3.41.7 stable`
- Dart: `3.11.5`
- Java: `17`

이 프로젝트는 Android 네이티브 C++ 빌드가 있으므로, NDK와 CMake가 반드시 필요합니다.

## 4. 설치/점검 절차

### 4-1. 먼저 확인할 명령

PowerShell에서 아래를 순서대로 확인하세요.

```powershell
git --version
flutter --version
dart --version
java -version
adb --version
```

### 4-2. Flutter가 없으면

Flutter stable SDK를 설치하고 `bin` 경로를 PATH에 추가하세요.

예시 경로:

```text
C:\src\flutter
```

PATH에 들어가야 할 예시:

```text
C:\src\flutter\bin
```

### 4-3. JDK 17이 없으면

JDK 17을 설치하세요.

가능한 예시:

- Microsoft OpenJDK 17
- Eclipse Temurin 17
- Android Studio bundled JBR가 Java 17이면 그것을 사용해도 됨

`JAVA_HOME` 예시:

```text
C:\Program Files\Microsoft\jdk-17.x.x
```

### 4-4. Android SDK가 없으면

Android Studio를 설치한 뒤 SDK Manager에서 아래를 설치하세요.

- Android SDK Platform 최신 버전
- Android SDK Build-Tools 최신 버전
- Android SDK Platform-Tools
- Android SDK Command-line Tools
- NDK (Side by side)
- CMake 3.22.1 이상

권장 SDK 루트:

```text
$env:LOCALAPPDATA\Android\Sdk
```

### 4-5. 환경 변수 예시

PowerShell 임시 설정 예시는 아래와 같습니다.

```powershell
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-17.0.x'
$env:ANDROID_HOME="$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT="$env:LOCALAPPDATA\Android\Sdk"
$env:Path='C:\src\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:ANDROID_HOME + '\platform-tools;' + $env:Path
```

환경이 준비되면 아래를 실행하세요.

```powershell
flutter doctor -v
flutter doctor --android-licenses
```

라이선스는 모두 동의하세요.

## 5. 이 ZIP에 포함되어 있어야 하는 핵심 파일

최소 압축본에는 아래가 포함되어 있어야 합니다.

- `lib/`
- `android/`
- `assets/`
- `third_party/`
- `test/`
- `docs/`
- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `.metadata`
- `README.md`
- `OPEN_THIS_IN_CODEX.md`

반대로 아래가 없어도 정상입니다.

- `build/`
- `.dart_tool/`
- `.tooling/`
- `ios/`
- `android/local.properties`
- `android/.gradle/`

없는 파일은 Flutter/Gradle이 재생성합니다.

## 6. 프로젝트를 연 직후 바로 실행할 명령

프로젝트 루트에서 아래를 순서대로 실행하세요.

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

빌드가 성공하면 release APK 기본 위치는 아래입니다.

```text
build\app\outputs\flutter-apk\app-release.apk
```

## 7. 만약 빌드가 실패하면 먼저 볼 것

1. `flutter doctor -v` 결과에 Android toolchain 문제가 없는지 확인
2. JDK가 17인지 확인
3. Android SDK, NDK, CMake가 설치되어 있는지 확인
4. `android/local.properties`가 자동 생성되었는지 확인
5. `flutter pub get`이 성공했는지 확인
6. `third_party/freeverb3`와 `third_party/lame`가 실제로 존재하는지 확인

특히 이 프로젝트는 C++ native build가 있으므로 아래가 빠지면 빌드가 잘 깨집니다.

- NDK
- CMake
- `third_party/`

## 8. 프로젝트의 핵심 구조

Flutter 주요 파일:

- `lib/app.dart`
- `lib/src/controllers/arrangement_session_controller.dart`
- `lib/src/models/track_model.dart`
- `lib/src/screens/arrangement_screen.dart`
- `lib/src/screens/help_screen.dart`
- `lib/src/services/audio_engine_bridge.dart`
- `lib/src/services/waveform_service.dart`
- `lib/src/widgets/timeline_ruler.dart`
- `lib/src/widgets/track_lane.dart`

Android 네이티브 핵심 파일:

- `android/app/src/main/kotlin/com/example/music_daw_player/MainActivity.kt`
- `android/app/src/main/cpp/CMakeLists.txt`
- `android/app/src/main/cpp/freeverb3_bridge.cpp`
- `android/app/src/main/cpp/lame_mp3_encoder.cpp`

외부 라이브러리 소스:

- `third_party/freeverb3/`
- `third_party/lame/`

브랜딩:

- `assets/branding/pinewave_icon.png`

## 9. 현재 앱 상태 요약

현재 구현되어 있는 핵심 기능:

- PineWave 앱 이름/아이콘
- 멀티트랙 waveform UI
- 오디오 파일 로드
- 동영상 파일에서 audio track 추출 로드
- play / pause / stop
- seek
- 재생 중 seek하면 그 위치부터 계속 재생
- timeline 끝까지 가면 stop
- 녹음 중에는 timeline 계속 확장
- track volume
- track pan
- track mute
- track solo
- track reverb amount
- reverb preset / detail sheet
- track peak meter
- track record arm 1개만 활성화
- recording + playback 동시 시작
- stop 시 recording/playback 둘 다 중지
- 기존 클립 구간 overwrite 녹음
- waveform move mode
- `-10`, `-1`, `+1`, `+10` ms nudge
- 최대 `64x` zoom
- 고배율 timeline 눈금 세분화
- selected tracks MP3 mix
- vocal/backing split
- session save/load
- save/load/mix/split 시 사용자 파일명 입력
- Android SAF 기반 폴더 선택 저장/로드
- loading overlay
- 도움말 화면

## 10. 현재 중요한 제약/주의점

- 현재 split은 진짜 AI stem separation이 아닙니다.
- 현재 split은 lightweight DSP 기반 quick split입니다.
- Demucs/MDX 같은 고품질 보컬 분리는 아직 미구현입니다.
- Android release 서명은 아직 debug signing config를 사용합니다.
- applicationId는 아직 예시값 `com.example.music_daw_player`입니다.
- iOS 빌드 완료 상태가 아닙니다.

## 11. 저장/믹스/split에서 절대 건드리면 안 되는 원칙

최신 Android에서는 `/storage/emulated/0/...` 직접 파일 쓰기가 EPERM을 일으킬 수 있습니다.

따라서 아래 원칙을 유지하세요.

- 저장 경로는 `ACTION_OPEN_DOCUMENT_TREE`
- URI 권한은 `takePersistableUriPermission`
- 파일 생성은 `DocumentsContract.createDocument`
- 파일 읽기/쓰기는 `contentResolver.openInputStream/openOutputStream`
- Dart 쪽에서 단순 절대경로 파일 쓰기로 되돌리지 말 것

## 12. Codex가 프로젝트를 열고 처음 사용자에게 보고해야 할 내용

프로젝트를 연 뒤에는 먼저 아래를 확인하고 사용자에게 짧게 보고하세요.

- 환경 설치가 끝났는지
- `flutter pub get` 성공 여부
- `flutter analyze` 성공 여부
- `flutter test` 성공 여부
- `flutter build apk --release` 성공 여부
- 실패했다면 정확히 어떤 단계에서 막혔는지

즉, 첫 번째 목표는 새 기능 구현보다 먼저 “이 PC에서도 PineWave가 다시 빌드되는지” 확인하는 것입니다.

## 13. 그 다음에 이어서 작업할 때 기본 태도

- 이미 있는 구조를 존중하고, 재구현보다 기존 코드 수정 위주로 진행하세요.
- `MainActivity.kt`는 길지만 현재 핵심 오디오 엔진이 몰려 있으므로 함부로 분해하지 마세요.
- 사용자 요청이 오면 먼저 현재 코드 경로를 읽고, 최소 수정으로 해결하세요.
- 오디오 엔진 관련 버그는 Dart와 Kotlin 쪽을 함께 확인하세요.
- UI 수정은 Flutter 화면만 바꾸면 되는지, 네이티브 동작도 필요한지 먼저 구분하세요.

## 14. 사용자가 다음에 자주 요청할 가능성이 큰 작업

가능성이 높은 다음 작업들:

- AI 기반 보컬/반주 분리 품질 개선
- 리버브/믹스 품질 개선
- 더 정밀한 waveform sync 편집
- 세션 저장 포맷 개선
- 앱 패키지명/applicationId 정리
- release signing 정식 적용
- 성능 최적화

## 15. 다른 문서

추가 참고:

- `docs/PineWave_REBUILD_GUIDE.md`
- `PineWave_HANDOFF.md`

하지만 가장 먼저 볼 문서는 이 파일입니다.

## 16. 사용자에게 처음 보낼 추천 메시지

프로젝트를 정상적으로 열었다면 사용자에게 이런 식으로 시작하세요.

```text
압축본 기준으로 PineWave 프로젝트를 이어받았고, 먼저 이 PC에서 Flutter/Android 빌드 환경을 확인한 다음 앱이 다시 빌드되는지 검증하겠습니다. 그 뒤 현재 구조를 빠르게 점검하고 바로 다음 작업으로 이어가겠습니다.
```

## 17. 최종 목표

이 프로젝트에서 지금 가장 중요한 목표는 아래입니다.

- 다른 컴퓨터에서도 기존 PineWave 소스를 그대로 이어서 개발 가능하게 만들기
- 새 기능 추가 전에 Android 빌드와 실행 가능 상태를 복구/검증하기
- 사용자의 다음 요청을 기존 프로젝트 기반으로 안전하게 이어서 구현하기

