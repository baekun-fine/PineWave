# PineWave Handoff Notes

이 문서는 소스 전체를 옮기지 못하더라도, 다른 컴퓨터에서 Codex/AI 개발 도구로 PineWave 앱을 최대한 이어서 재구현할 수 있도록 만든 인수인계 문서입니다.

중요: APK만으로는 정상적인 개발 이어받기가 어렵습니다. 가장 좋은 방법은 전체 Flutter 프로젝트 소스를 옮기는 것입니다. 이 문서는 차선책으로, 기능/구조/UI/네이티브 오디오 동작을 상세히 설명합니다.

## 앱 개요

- 앱 이름: PineWave
- 플랫폼: Android 우선
- 프레임워크: Flutter UI + Android Kotlin native audio engine
- 목적: 모바일에서 DAW처럼 여러 오디오 트랙을 불러오고, 파형을 보면서 재생/녹음/믹스/분리/저장을 하는 앱
- 앱 아이콘 컨셉: porcupine의 "pine"에서 온 날카로운 가시 + 오디오 파형
- 메인 컬러: 어두운 graphite/black 배경, neon teal 포인트, 일부 amber/blue 보조 포인트

## 현재 주요 기능

- 오디오 파일 로드
- 동영상 파일 로드 시 오디오 트랙만 추출해서 로드
- 여러 트랙에 오디오 배치
- 파형 표시
- 타임라인 눈금 표시
- play / pause / stop
- 재생 중 seek 후 해당 위치부터 계속 play
- 트랙별 volume
- 트랙별 pan L/R
- 트랙별 mute
- 트랙별 solo
- 트랙별 reverb amount
- 트랙별 reverb detail sheet
- Freeverb3 기반 native reverb
- track record arm
- 녹음 기능
- 녹음 중 play 동시 진행
- stop 시 녹음과 재생 같이 중지
- 기존 오디오가 있는 트랙에 녹음하면 해당 구간 overwrite
- 트랙은 유지하고 오디오만 삭제 가능
- 트랙 삭제 가능
- mix 선택 토글
- 선택 트랙 MP3 mix 저장
- split vocal/backing MP3 저장
- save session / load session
- 저장 시 파일 이름 직접 입력
- mix 저장 시 MP3 파일 이름 직접 입력
- split 저장 시 base name 입력 후 `_vocals.mp3`, `_backing.mp3` 생성
- Android 저장소 권한 문제 해결: SAF / `ACTION_OPEN_DOCUMENT_TREE` / `content://` 기반 저장
- 작업 중 loading overlay 표시
- bottom snackbar/popup 가독성 개선
- 도움말 화면

## 현재 한계

- split vocal/backing은 아직 진짜 AI stem separation이 아님
- 현재 split은 lightweight DSP 개선 버전:
  - center vocal estimation
  - vocal frequency band 추출
  - backing에서 vocal estimate 감산
- 실제 Demucs/MDX/Spleeter 수준의 분리를 원하면 AI 모델이 필요
- AI split을 앱 안에서 하려면 ONNX Runtime Mobile 또는 TensorFlow Lite 모델을 넣는 방식이 가능
- 서버 방식도 가능하지만 인터넷/서버비/개인정보 이슈가 있음

## 추천 다음 단계

1. 기존 split 이름을 Quick Split으로 변경
2. 새 기능으로 AI Split Vocal/Backing 추가
3. 오프라인 우선이면 ONNX Runtime Android + 작은 source separation model 검토
4. 품질 우선이면 서버 기반 Demucs/MDX 처리 검토
5. AI split 작업에는 progress, cancel, background processing 필수

## Flutter UI 구조

권장 파일 구조:

```text
lib/
  app.dart
  src/
    controllers/
      arrangement_session_controller.dart
    models/
      track_model.dart
    screens/
      arrangement_screen.dart
      help_screen.dart
    services/
      audio_engine_bridge.dart
      waveform_cache.dart
      waveform_service.dart
    widgets/
      timeline_ruler.dart
      track_lane.dart
```

## 핵심 모델

`TrackModel`:

- `id`
- `name`
- `volume`
- `pan`
- `reverb`
- `reverbSettings`
- `muted`
- `solo`
- `recordArmed`
- `mixSelected`
- `fallbackDurationMs`
- `clips`

`TrackClipModel`:

- `id`
- `name`
- `filePath`
- `startMs`
- `durationMs`
- `sourceOffsetMs`
- `sourceDurationMs`
- `waveformPeaks`

`ReverbSettings`:

- `presetId`
- `mix`
- `roomSize`
- `decay`
- `damp`
- `preDelayMs`
- `width`

## 컨트롤러 기능

`ArrangementSessionController`가 담당:

- tracks 상태 관리
- position/duration/speed 관리
- import tracks
- import clip into track
- add empty track
- play/pause/stop
- seek
- speed 변경
- volume/pan/reverb/mute/solo 변경
- record arm 관리
- recording start/stop
- 녹음 overwrite 처리
- clear track audio
- delete track
- move track by ms
- mix selected tracks
- separate selected tracks
- save/load session
- loading message 관리

중요 구현:

- `_syncTrackAudibility()`에서 mute/solo/record armed 상태를 native engine에 반영
- 녹음 중 record-armed track은 기존 오디오가 재생되지 않게 mute 처리
- `seekTo()`는 재생 중이면 native seek 후 `play()`를 다시 보장
- `moveTrackBy(trackId, deltaMs)`는 1ms/10ms 단위 이동 가능해야 함
- 저장 파일명은 sanitize 후 확장자를 보장해야 함

## 메인 화면 UI

상단:

- 앱 아이콘
- `PineWave`
- 트랙 수
- Add empty track 버튼
- Open files 버튼
- Help `?` 버튼
- Project actions menu

Project actions:

- Save session
- Load session
- Mix selected (.mp3)
- Split vocal/backing (.mp3)

가운데:

- zoom strip
- move mode toggle
- timeline ruler
- left fixed track header area
- right horizontally scrollable waveform area
- vertical track scrolling
- playhead overlay

하단:

- current time
- seek slider
- total time
- stop
- record
- play/pause
- speed menu

## Track UI

트랙 왼쪽 헤더:

- 상태: AUDIO / REC / EMPTY
- load file icon
- clear audio X
- delete track icon
- R: record arm
- M: mute
- S: solo
- Mix: mix selection
- peak meter
- Vol slider + `-` / `+`
- Pan slider + `-` / `+`
- Rev slider + `-` / `+`
- reverb detail tune icon
- Move mode일 때 `-10`, `-1`, `+1`, `+10` ms nudge buttons

트랙 오른쪽 파형:

- waveform clip
- clip filename at top-left of clip
- played region overlay
- move mode일 때 drag로 이동 가능
- nudge buttons로 더 미세하게 이동 가능

## Zoom / Timeline

현재 목표:

- max zoom: `64x`
- 확대할수록 눈금 단위가 작아져야 함
- 고확대 시:
  - 0.5s
  - 0.1s
  - 0.05s
  - 0.01s 수준까지 표시
- 눈금 색상은 어두운 배경에서 잘 보이게 밝은 회색/흰색 계열
- label은 고확대 시 `mm:ss.S` 또는 `mm:ss.SSS`

싱크 맞추기 UX:

- MR과 녹음 트랙을 불러온 뒤 move mode ON
- 녹음 트랙을 선택하고 `-10`, `-1`, `+1`, `+10` 버튼으로 이동
- zoom in 해서 세밀한 눈금을 보면서 보컬 시작점을 MR 박자에 맞춤

## Help Screen

도움말 화면에는 다음 섹션이 있음:

- 브랜드 카드: PineWave 아이콘, 앱 설명
- 기본 사용
- 트랙 버튼
- 믹서 조절
- 타임라인과 재생
- 저장과 출력

각 항목은 icon/textIcon, title, description으로 구성.

## Android Native Audio Engine

파일:

```text
android/app/src/main/kotlin/com/example/music_daw_player/MainActivity.kt
android/app/src/main/cpp/CMakeLists.txt
android/app/src/main/cpp/freeverb3_bridge.cpp
android/app/src/main/cpp/lame_mp3_encoder.cpp
third_party/freeverb3/
third_party/lame/
```

MethodChannel:

- `loadTrack`
- `removeTrack`
- `play`
- `pause`
- `seek`
- `setSpeed`
- `setTrackVolume`
- `setTrackPan`
- `setTrackReverb`
- `setTrackReverbSettings`
- `setTrackMute`
- `setTrackStart`
- `setTrackRegion`
- `mixTracks`
- `separateVocalBacking`
- `writeSessionFile`
- `readSessionFile`
- `pickOutputDirectory`
- `startRecording`
- `stopRecording`

EventChannel:

- `positionMs`
- `durationMs`
- `isPlaying`
- `recordingLevel`

## Native Audio Loading

Android `MediaExtractor`로 파일 안의 `audio/*` track을 찾음.

지원 의도:

- MP3
- WAV
- M4A/AAC
- FLAC
- OGG/OPUS
- MP4/MOV/MKV/WEBM/AVI 등 동영상 파일의 audio track

디코딩:

- `MediaCodec`으로 PCM 추출
- stereo float array로 변환
- sample rate가 다르면 44.1kHz로 resample
- waveform peaks 생성

## Playback Engine

- `AudioTrack` 기반 출력
- mix sample rate: 44100
- stereo output
- block size: 1024 frames
- 각 트랙은 startFrame, sourceOffsetFrame, clipFrameCount를 가짐
- volume/pan/reverb/mute를 render block에서 반영
- positionRevision으로 seek race condition 방지

## Recording

- `MediaRecorder`
- output: `.m4a`
- sample rate: 44100
- AAC 128kbps
- recording stop 후 waveform service로 load
- record armed track에 overwrite

## Reverb

- Freeverb3 native bridge
- track별 reverb amount
- detail settings:
  - mix
  - roomSize
  - decay
  - damp
  - preDelayMs
  - width
- UI에 preset 선택 sheet 있음

## MP3 Encoding

- LAME source를 `third_party/lame`에 포함
- native C++ JNI wrapper:
  - create
  - encode
  - flush
  - release
- mix/split output은 MP3 192kbps

## Android Storage

중요: 최신 Android에서는 `/storage/emulated/0/...`에 직접 `FileOutputStream` 쓰면 EPERM이 발생할 수 있음.

해결 방식:

- `Intent.ACTION_OPEN_DOCUMENT_TREE`
- `takePersistableUriPermission`
- `DocumentsContract.createDocument`
- `contentResolver.openOutputStream`
- 세션 저장/로드도 `content://` 기반으로 처리

저장 대상:

- mix: 사용자 지정 `name.mp3`
- split: 사용자 지정 base name으로 `base_vocals.mp3`, `base_backing.mp3`
- session: 사용자 지정 `name.json`

## Loading Overlay

작업 중 overlay 표시:

- audio/video file loading
- recording loading
- mix
- split
- save session
- load session

## Popup Message

SnackBar는 하단 컨트롤과 겹치지 않도록 위로 띄움.

- success: dark teal background + mint border
- error: dark red background + red border
- close icon 표시
- 글씨 밝고 굵게

## 앱 아이콘

프로젝트 내 아이콘:

```text
assets/branding/pinewave_icon.png
android/app/src/main/res/mipmap-*/ic_launcher.png
```

아이콘 디자인:

- porcupine quills
- audio waveform
- dark background
- teal glow
- no pine tree
- no text

## 현재 빌드 명령

Windows PowerShell 환경 예:

```powershell
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
$env:ANDROID_HOME='C:\Users\baekun\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT='C:\Users\baekun\AppData\Local\Android\Sdk'
$env:Path = 'D:\project\music\.tooling\flutter-sdk\bin;' + $env:JAVA_HOME + '\bin;' + $env:ANDROID_HOME + '\platform-tools;' + $env:Path
flutter analyze
flutter test
flutter build apk --release
```

현재 release APK 위치:

```text
D:\project\music\build\app\outputs\flutter-apk\app-release.apk
```

## 다른 컴퓨터에서 재구현 프롬프트 예시

다른 컴퓨터에서 Codex에게 아래처럼 요청하면 좋습니다.

```text
Flutter + Android Kotlin native audio engine으로 PineWave 앱을 만들어줘.
이 문서(PineWave_HANDOFF.md)를 기준으로 기능과 UI를 구현해줘.
우선 Android release APK 빌드가 되는 상태를 목표로 해줘.

핵심 요구:
- DAW 스타일 멀티트랙 파형 UI
- 오디오/동영상 파일에서 오디오 로드
- play/pause/stop/seek/speed
- track volume/pan/reverb/mute/solo
- recording with overwrite
- waveform move mode with 1ms/10ms nudge
- zoom 64x and fine timeline ruler
- MP3 mix using LAME
- quick vocal/backing split
- session save/load using Android SAF
- help screen
- PineWave branding/icon

구현 후 flutter analyze, flutter test, flutter build apk --release까지 통과시켜줘.
```

## 같이 가져가면 좋은 스크린샷

다른 컴퓨터에서 재구현 정확도를 높이려면 이 문서와 함께 아래 스크린샷을 준비하세요.

- 메인 화면 전체
- 트랙 헤더 close-up
- waveform/timeline close-up
- move mode ON 상태
- reverb detail sheet
- project menu
- help screen
- save/mix/split file name dialog
- loading overlay
- bottom popup/snackbar

스크린샷은 `docs/screenshots/` 같은 폴더에 넣고, 이 문서에 이미지 링크로 추가하면 좋습니다.

예:

```md
![Main screen](docs/screenshots/main.png)
![Move mode](docs/screenshots/move-mode.png)
![Help screen](docs/screenshots/help.png)
```

## 현실적인 결론

이 문서와 UI 스크린샷만 있으면 다른 컴퓨터에서 AI를 이용해 꽤 비슷하게 다시 만들 수 있습니다.

하지만 가장 안전한 방법은 여전히 전체 소스 프로젝트를 GitHub/private repo 또는 ZIP으로 옮기는 것입니다. 특히 native audio engine, Freeverb3, LAME, storage permission, recording overwrite 같은 부분은 문서만으로 재현하면 시간이 더 걸릴 수 있습니다.
