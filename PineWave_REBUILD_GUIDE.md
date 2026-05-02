# PineWave 재구현 인수인계 문서

이 문서는 현재 작업한 PineWave 앱을 다른 컴퓨터에서 Codex/AI 개발 도구로 다시 만들 수 있도록 정리한 상세 재구현 가이드입니다.

중요한 현실 체크부터 적습니다. 소스 코드 없이 Markdown 문서와 UI 스크린샷만 있으면 “거의 같은 앱을 다시 구현”할 수는 있지만, “지금 소스 그대로 이어받기”는 아닙니다. 특히 Android 네이티브 오디오 엔진, Freeverb3, LAME MP3 인코딩, Android 저장소 권한 처리처럼 세부 구현이 많은 부분은 원본 소스가 있을 때 가장 안전합니다. 그래도 이 문서와 스크린샷을 같이 넘기면 다른 컴퓨터에서도 충분히 같은 방향으로 재구현을 시작할 수 있습니다.

## 1. 프로젝트 개요

- 앱 이름: PineWave
- 플랫폼 우선순위: Android 우선, iOS는 추후 확장
- 앱 성격: 모바일 DAW 스타일 멀티트랙 오디오 플레이어/녹음 앱
- 주요 목표: 여러 오디오/비디오 파일을 트랙으로 불러오고, 파형과 타임라인을 보면서 재생, 녹음, 믹스, 저장, 간단한 보컬/반주 분리를 수행
- UI 스타일: 어두운 graphite/black 배경, neon teal 포인트 컬러, DAW 느낌의 트랙 레인과 파형
- 앱 아이콘 방향: 포큐파인의 가시와 오디오 파형을 결합한 이미지, 소나무 이미지 아님

## 2. 추천 기술 스택

- Flutter: 모바일 UI, CustomPaint 기반 waveform/timeline 렌더링
- Dart ChangeNotifier controller: 세션 상태, 트랙 상태, 재생 상태 관리
- Android Kotlin native audio engine: MediaExtractor, MediaCodec, AudioTrack, MediaRecorder
- Flutter MethodChannel/EventChannel: Dart UI와 Android native engine 연결
- Freeverb3: 트랙별 리버브 native DSP
- LAME: mix/split 결과 MP3 저장
- Android SAF(Storage Access Framework): 저장/불러오기 폴더 선택 및 `content://` URI 기반 파일 쓰기/읽기

## 3. 현재 주요 기능

- 오디오 파일 로드
- 동영상 파일 선택 시 내부 audio track만 추출해서 로드
- 여러 트랙 로드
- 빈 트랙 추가
- 트랙에 파일 불러오기
- 트랙은 유지하고 오디오 클립만 삭제
- 트랙 자체 삭제
- waveform 표시
- timeline ruler 표시
- play, pause, stop
- 재생 중 timeline/seek bar 이동 시 해당 위치부터 계속 재생
- timeline 끝까지 재생되면 자동 stop 및 처음으로 이동
- 녹음 중에는 timeline이 계속 늘어나며 자동 stop 예외 처리
- 배속 재생: 0.5x, 1.0x, 1.5x, 2.0x
- 트랙별 volume
- 트랙별 pan L/R
- 트랙별 mute
- 트랙별 solo
- 트랙별 reverb amount
- 트랙별 reverb 세부 설정 bottom sheet
- reverb preset 선택
- 트랙별 peak meter
- track record arm
- 전체 녹음 버튼은 record armed track이 있을 때만 활성화
- record arm은 전체 트랙 중 하나만 활성화
- 녹음 버튼을 누르면 playback도 같이 시작
- stop 버튼을 누르면 playback과 recording 둘 다 stop
- 오디오가 있는 트랙 위에 녹음하면 기존 오디오를 해당 구간만 overwrite
- 예: 10초짜리 클립에서 0초부터 5초 녹음하면 0~5초는 새 녹음, 5~10초는 기존 오디오 유지
- waveform move mode
- move mode에서 waveform drag 이동
- 1ms, 10ms 단위 nudge 버튼으로 미세 싱크 조정
- zoom 64x까지 확대
- 확대 시 timeline 눈금이 더 작은 단위로 표시
- Mix 선택 트랙 MP3 출력
- Split vocal/backing MP3 출력
- Session save/load
- save/load/mix/split 파일 이름 직접 입력
- save/load/mix/split/audio load/video load 시 loading overlay 표시
- bottom popup/snackbar 가독성 개선
- 도움말 페이지

## 4. 중요한 한계

- 현재 vocal/backing split은 진짜 AI stem separation이 아닙니다.
- 현재 방식은 lightweight DSP 기반입니다. 중앙 보컬 추정, 보컬 대역 필터링, backing에서 보컬 추정치 감산 같은 방식입니다.
- Demucs, MDX-Net, Spleeter 수준의 분리를 원하면 AI 모델이 필요합니다.
- 앱 내부에서 AI split을 하려면 ONNX Runtime Mobile 또는 TensorFlow Lite 모델을 붙이는 구조가 필요합니다.
- 서버 기반 AI split을 쓰면 품질은 좋지만 인터넷, 비용, 서버비, 개인정보 이슈가 생깁니다.
- 로그인/유료가입 없이 앱 내부에서만 처리하려면 on-device AI 모델이 맞지만 APK 용량과 처리 시간이 크게 늘 수 있습니다.

## 5. 권장 폴더 구조

```text
lib/
  main.dart
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

android/
  app/
    src/main/
      AndroidManifest.xml
      kotlin/com/example/music_daw_player/MainActivity.kt
      cpp/
        CMakeLists.txt
        freeverb3_bridge.cpp
        lame_mp3_encoder.cpp

assets/
  branding/
    pinewave_icon.png

third_party/
  freeverb3/
  lame/

test/
  widget_test.dart
```

## 6. Dart 데이터 모델

`TrackModel`은 트랙 하나의 상태를 가진다.

```text
TrackModel
- id
- name
- volume: 0.0 ~ 1.0
- pan: -1.0(left) ~ 1.0(right)
- reverb: 0.0 ~ 1.0
- reverbSettings
- muted
- solo
- recordArmed
- mixSelected
- fallbackDurationMs
- clips: List<TrackClipModel>
```

`TrackClipModel`은 트랙 안에 놓인 실제 오디오 클립을 가진다.

```text
TrackClipModel
- id
- name
- filePath
- startMs
- durationMs
- sourceOffsetMs
- sourceDurationMs
- waveformPeaks
```

`ReverbSettings`는 Freeverb3에 넘길 리버브 세부 파라미터를 가진다.

```text
ReverbSettings
- presetId
- mix
- roomSize
- decay
- damp
- preDelayMs
- width
```

권장 preset 예시:

```text
Studio Vocal
- mix 0.48
- roomSize 0.58
- decay 0.62
- damp 0.42
- preDelayMs 32
- width 0.78

Wide Hall
- mix 0.65
- roomSize 0.86
- decay 0.82
- damp 0.32
- preDelayMs 48
- width 0.95

Plate Shine
- mix 0.56
- roomSize 0.70
- decay 0.74
- damp 0.26
- preDelayMs 22
- width 0.88

Small Room
- mix 0.34
- roomSize 0.38
- decay 0.42
- damp 0.55
- preDelayMs 12
- width 0.62
```

## 7. Flutter Controller 요구사항

`ArrangementSessionController`가 앱의 중심 상태 관리자입니다.

담당 기능:

- 트랙 목록 관리
- 위치, 전체 길이, 재생 속도 관리
- 오디오/비디오 파일 import
- 특정 트랙에 클립 import
- 빈 트랙 추가
- play/pause/stop
- seek
- speed 변경
- volume/pan/reverb/mute/solo 변경
- record arm 관리
- recording start/stop
- 녹음 overwrite 처리
- 트랙 오디오만 삭제
- 트랙 삭제
- waveform 이동
- 1ms/10ms nudge 이동
- selected tracks mix
- selected tracks vocal/backing split
- session save/load
- loading overlay message 관리

중요 동작:

- `recordArmed`는 한 번에 한 트랙만 true가 되어야 합니다.
- 녹음 중 record armed track은 기존 오디오가 재생되지 않아야 합니다.
- solo가 켜진 트랙이 하나 있으면 해당 트랙만 들리고 나머지는 mute처럼 처리합니다.
- 재생 중 seek하면 native seek 후 다시 play 상태가 유지되어야 합니다.
- 녹음이 아닐 때 timeline 끝에 도달하면 pause, seek(0), UI isPlaying false가 되어야 합니다.
- 녹음 중에는 timeline duration이 recording elapsed에 맞춰 늘어나야 합니다.
- save/load/mix/split처럼 오래 걸리는 작업은 loading overlay를 켜야 합니다.

## 8. Flutter UI 상세

전체 화면:

- 배경색: 거의 검정 `#050608`
- 핵심 포인트: neon teal `#00E0A4`
- 보조 포인트: cyan playhead `#11C9FF`, red record/error, amber zoom thumb
- mobile portrait 기준으로 동작해야 함

상단 top bar:

- 왼쪽 앱 아이콘
- 앱 이름 `PineWave`
- 트랙 개수
- 빈 트랙 추가 버튼
- 파일 열기 버튼
- 도움말 `?` 버튼
- project menu

Project menu:

- Save session
- Load session
- Mix selected (.mp3)
- Split vocal/backing (.mp3)

Arrangement area:

- 상단 zoom strip
- move mode toggle
- timeline ruler
- 왼쪽 track header 영역은 고정
- 오른쪽 waveform 영역만 가로 스크롤
- timeline ruler도 waveform 영역과 같은 horizontal scroll을 따라가야 함
- track header와 waveform list는 세로 스크롤 동기화
- playhead는 waveform viewport 위에 overlay

Bottom transport:

- 현재 시간
- seek slider
- 총 시간
- stop 버튼
- record 버튼
- play/pause 버튼
- speed menu

Track header:

- AUDIO / REC / EMPTY 상태 표시
- load file icon
- clear audio X
- delete track icon
- R: record arm toggle
- M: mute toggle
- S: solo toggle
- Mix: mix selection toggle
- peak meter
- Vol slider와 `-`, `+` 버튼
- Pan slider와 `-`, `+` 버튼
- Rev slider와 `-`, `+` 버튼
- reverb detail tune icon
- move mode가 켜지면 `-10`, `-1`, `+1`, `+10` ms nudge 버튼 표시

Waveform area:

- 클립 배경은 teal 계열
- waveform은 검정/어두운 선으로 표시
- 파일 이름은 waveform 클립 왼쪽 위에 표시
- 재생된 구간 overlay 표시
- move mode가 켜지면 waveform drag로 startMs 변경
- move mode가 꺼지면 waveform/timeline tap 또는 drag는 seek 중심으로 동작

## 9. Timeline / Zoom 요구사항

- 기본 화면에서는 전체 파일이 한눈에 보이게 fit
- zoom max는 64x
- zoom in이 커질수록 timeline 단위가 작아져야 함
- 눈금은 어두운 배경에서도 잘 보이도록 밝은 회색/청록 계열로 표시
- 고확대 상태에서는 0.5s, 0.1s, 0.05s, 0.01s 같은 작은 단위까지 표현
- label은 상황에 따라 `mm:ss`, `mm:ss.S`, `mm:ss.SSS` 형태
- 싱크 맞추기 UX:
  - MR과 녹음 트랙을 불러온다.
  - move mode를 켠다.
  - 녹음 트랙을 선택하고 `-10`, `-1`, `+1`, `+10` 버튼으로 위치를 맞춘다.
  - zoom in을 해서 beat/transient를 보고 더 세밀하게 맞춘다.

## 10. AudioEngineBridge 인터페이스

Flutter에서 native로 연결하는 MethodChannel 이름:

```text
music_daw_player/audio_engine
```

EventChannel 이름:

```text
music_daw_player/audio_engine/events
```

필수 MethodChannel 메서드:

```text
loadTrack(id, filePath)
removeTrack(id)
play()
pause()
seek(positionMs)
setSpeed(speed)
setTrackVolume(id, volume)
setTrackPan(id, pan)
setTrackReverb(id, reverb)
setTrackReverbSettings(id, mix, roomSize, decay, damp, preDelayMs, width)
setTrackMute(id, muted)
setTrackStart(id, startMs)
setTrackRegion(id, startMs, sourceOffsetMs, durationMs)
mixTracks(ids, outputDirectory, outputFileName)
separateVocalBacking(ids, outputDirectory, outputBaseName)
pickOutputDirectory()
writeSessionFile(directoryUri, fileName, contents)
readSessionFile(directoryUri, fileName)
startRecording()
stopRecording()
```

EventChannel payload:

```text
positionMs
durationMs
isPlaying
recordingLevel
```

## 11. Android Native Audio Engine 요구사항

Android 구현 파일:

```text
android/app/src/main/kotlin/com/example/music_daw_player/MainActivity.kt
```

오디오 로드:

- `MediaExtractor`로 파일 안의 `audio/*` track을 찾는다.
- 파일 경로 또는 `content://` URI 둘 다 처리한다.
- `MediaCodec`으로 PCM 디코딩한다.
- mono는 stereo로 복제한다.
- sample rate가 다르면 44.1kHz로 resample한다.
- 내부 samples는 stereo float array로 관리한다.
- waveform peaks를 생성해서 Dart로 넘긴다.

지원 목표:

- MP3
- WAV
- M4A/AAC
- FLAC
- OGG/OPUS
- MP4/MOV/MKV/WEBM/AVI 등 비디오 파일의 audio track

재생:

- `AudioTrack` 기반 stereo output
- mix sample rate: 44100
- output channel count: 2
- render block size: 1024 frames
- 각 clip은 startFrame, sourceOffsetFrame, clipFrameCount를 가진다.
- render block에서 volume, pan, mute, reverb를 반영한다.
- pan은 equal-power pan 권장
- seek race condition 방지를 위해 position revision 같은 값으로 playback loop를 안정화한다.

녹음:

- `MediaRecorder` 사용
- output format: MPEG_4
- audio encoder: AAC
- output extension: `.m4a`
- sample rate: 44100
- bit rate: 128kbps
- stop 후 해당 파일을 다시 native decoder로 load해서 waveform 생성
- record armed track에 overwrite 적용

MP3:

- LAME를 `third_party/lame`에 vendoring
- native JNI wrapper `lame_mp3_encoder.cpp`
- mix/split output bitrate는 192kbps 권장

Reverb:

- Freeverb3를 `third_party/freeverb3`에 vendoring
- native JNI bridge `freeverb3_bridge.cpp`
- 각 native DecodedTrack은 Freeverb3 handle을 가진다.
- amount는 track reverb와 settings mix를 조합해서 적용한다.
- track reverb settings 변경 시 다음 render block부터 반영한다.

## 12. Android 저장소 처리

최신 Android에서는 `/storage/emulated/0/...` 같은 경로에 직접 `FileOutputStream`을 열면 EPERM이 발생할 수 있습니다.

반드시 다음 구조를 사용합니다.

- 폴더 선택: `Intent.ACTION_OPEN_DOCUMENT_TREE`
- 권한 유지: `takePersistableUriPermission`
- 파일 생성: `DocumentsContract.createDocument`
- 파일 쓰기: `contentResolver.openOutputStream`
- 파일 읽기: `contentResolver.openInputStream`
- save/load/mix/split은 모두 사용자가 선택한 폴더 URI를 기준으로 처리

출력 규칙:

- session save: 사용자가 입력한 `name.json`
- session load: 사용자가 입력한 `name.json`을 선택 폴더에서 읽기
- mix: 사용자가 입력한 `name.mp3`
- split: 사용자가 입력한 base name으로 `base_vocals.mp3`, `base_backing.mp3`

파일명 sanitize:

- `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|` 제거 또는 `_` 치환
- 확장자가 없으면 자동 추가
- 빈 이름이면 fallback 사용

## 13. Mix 기능

사용 흐름:

- 각 트랙의 `Mix` 버튼으로 믹스 대상 선택
- project menu에서 `Mix selected (.mp3)` 실행
- 파일 이름 입력 dialog 표시
- Android folder picker 표시
- 선택한 폴더에 MP3 저장
- 저장된 MP3를 새 트랙으로 다시 로드

렌더링 규칙:

- 선택한 트랙들의 clips만 offline render
- 현재 volume/pan/reverb/mute 상태를 반영
- solo 상태는 mix 정책에 따라 반영해도 되고, 초기 구현은 selected clips 기준으로 충분
- 출력은 stereo MP3 192kbps

## 14. Split Vocal/Backing 기능

현재 재구현 기준:

- `Mix` 선택된 트랙이 있으면 그 트랙들을 대상으로 split
- 선택된 트랙이 없고 audio track이 하나뿐이면 해당 트랙 대상으로 split
- project menu에서 `Split vocal/backing (.mp3)` 실행
- base file name 입력
- Android folder picker 표시
- `base_vocals.mp3`, `base_backing.mp3` 저장
- 저장된 두 파일을 새 트랙 두 개로 로드

현재 DSP split 알고리즘 예시:

- stereo input에서 center = `(L + R) / 2`
- side = `(L - R) / 2`
- center에 vocal band filter 적용
- vocal band는 대략 120Hz high-pass, 6500Hz low-pass
- center dominance를 계산해서 vocal estimate 생성
- vocals output은 vocal estimate를 mono/stereo로 출력
- backing output은 원본 L/R에서 vocal estimate를 감산

주의:

- 이 방식은 AI 분리가 아니므로 완벽하게 보컬/반주가 분리되지 않습니다.
- 품질 개선 요구가 크면 다음 단계는 ONNX/TFLite 기반 AI source separation입니다.

## 15. Session Save/Load

Session JSON에 저장할 내용:

```json
{
  "version": 1,
  "savedAt": "ISO timestamp",
  "positionMs": 0,
  "speed": 1.0,
  "tracks": []
}
```

각 track JSON:

```text
id
name
volume
pan
reverb
reverbSettings
muted
solo는 저장해도 load 시 false 권장
recordArmed는 저장해도 load 시 false 권장
mixSelected
fallbackDurationMs
clips
```

각 clip JSON:

```text
id
name
filePath
startMs
durationMs
sourceOffsetMs
sourceDurationMs
waveformPeaks는 저장 가능하지만 load 시 파일에서 다시 추출해도 됨
```

주의:

- session은 오디오 파일 자체를 포함하지 않습니다.
- filePath 또는 content URI가 다른 컴퓨터/다른 폰에서 유효하지 않을 수 있습니다.
- 완전한 프로젝트 포맷을 원하면 나중에 audio asset까지 복사하는 bundle export가 필요합니다.

## 16. Help Screen 요구사항

도움말은 `?` 버튼으로 진입합니다.

포함할 내용:

- PineWave 소개
- 파일 열기
- 빈 트랙 추가
- 트랙에 파일 불러오기
- 트랙 삭제
- 오디오 클립 삭제
- R/M/S/Mix 설명
- volume/pan/reverb 설명
- reverb 세부 설정 설명
- timeline/zoom 설명
- move mode와 nudge 설명
- play/stop/record 설명
- mix/save/load/split 설명
- split 기능의 한계 설명

아이콘 설명은 실제 UI icon과 같은 의미로 맞춥니다.

## 17. 앱 아이콘/브랜딩

요구사항:

- 앱 이름은 `PineWave`
- pine은 소나무가 아니라 porcupine의 pine 느낌
- 아이콘에는 소나무가 나오면 안 됨
- porcupine quill, audio waveform, dark background, teal glow 조합
- 텍스트 없는 앱 아이콘

파일 위치:

```text
assets/branding/pinewave_icon.png
android/app/src/main/res/mipmap-*/ic_launcher.png
```

`pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/branding/pinewave_icon.png
```

Android manifest label:

```xml
android:label="PineWave"
```

## 18. 빌드 환경

현재 Windows PowerShell 기준 빌드 환경 예시:

```powershell
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
$env:ANDROID_HOME='C:\Users\baekun\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT='C:\Users\baekun\AppData\Local\Android\Sdk'
$env:Path = 'D:\project\music\.tooling\flutter-sdk\bin;' + $env:JAVA_HOME + '\bin;' + $env:ANDROID_HOME + '\platform-tools;' + $env:Path

flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --release
```

release APK 위치:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 19. 검증 체크리스트

- 앱 실행 시 PineWave 이름과 앱 아이콘이 보인다.
- 오디오 파일 1개를 불러오면 waveform이 표시된다.
- 동영상 파일을 선택하면 audio만 추출되어 waveform이 표시된다.
- 여러 파일을 불러오면 여러 트랙으로 배치된다.
- play/pause/stop이 동작한다.
- 재생 중 seek bar를 움직이면 그 위치부터 재생된다.
- timeline 끝까지 가면 녹음 중이 아닐 때 stop된다.
- volume을 줄이면 실제 소리도 줄어든다.
- pan을 왼쪽/오른쪽으로 옮기면 stereo 위치가 바뀐다.
- mute를 누르면 해당 트랙이 안 들린다.
- solo를 누르면 해당 트랙만 들린다.
- R 버튼은 한 트랙만 활성화된다.
- 트랙 R을 켠 뒤 하단 record를 누르면 녹음과 재생이 같이 시작된다.
- stop을 누르면 녹음과 재생이 모두 멈춘다.
- 기존 오디오가 있는 트랙에 녹음하면 해당 구간만 새 녹음으로 덮인다.
- move mode에서 waveform drag로 클립을 이동할 수 있다.
- nudge 버튼으로 1ms/10ms 단위 이동이 가능하다.
- zoom in 시 timeline 눈금이 더 촘촘해진다.
- reverb slider와 detail preset이 실제 소리에 반영된다.
- Mix selected가 MP3 파일을 만든다.
- Split vocal/backing이 두 MP3 파일을 만든다.
- Save session이 사용자가 선택한 폴더에 JSON으로 저장된다.
- Load session이 선택한 JSON 이름을 읽어 트랙 상태를 복원한다.
- 저장/믹스/split/load 중 loading overlay가 보인다.
- error popup 글씨가 잘 보인다.

## 20. 스크린샷을 같이 넘길 때 권장 파일명

스크린샷은 이 폴더에 넣는 것을 권장합니다.

```text
docs/screenshots/
```

권장 스크린샷:

- `main-empty.png`: 빈 화면
- `main-one-track.png`: 파일 하나 로드된 화면
- `multi-track.png`: 여러 트랙 화면
- `track-header-closeup.png`: R/M/S/Mix, volume/pan/reverb 영역 close-up
- `timeline-zoom.png`: zoom in된 timeline 눈금
- `move-mode.png`: move mode와 nudge 버튼이 보이는 화면
- `reverb-sheet.png`: reverb detail/preset sheet
- `project-menu.png`: save/load/mix/split 메뉴
- `filename-dialog.png`: 저장 파일명 입력 dialog
- `loading-overlay.png`: loading overlay
- `help-screen.png`: 도움말 페이지
- `error-popup.png`: 하단 popup/snackbar

Markdown에서 스크린샷을 연결하려면 아래처럼 작성합니다.

```md
![Main one track](screenshots/main-one-track.png)
![Move mode](screenshots/move-mode.png)
![Reverb sheet](screenshots/reverb-sheet.png)
```

## 21. 다른 컴퓨터에서 Codex에게 줄 프롬프트

다른 컴퓨터에서 빈 폴더를 열고 Flutter/Android 개발 환경을 준비한 뒤, 이 문서와 스크린샷을 첨부하고 아래처럼 요청하면 됩니다.

```text
이 문서 docs/PineWave_REBUILD_GUIDE.md와 첨부한 UI 스크린샷을 기준으로 PineWave 앱을 새로 구현해줘.

목표는 Android release APK가 빌드되는 Flutter 앱이야.

반드시 포함해야 하는 핵심 기능:
- PineWave 앱 이름과 포큐파인 가시/파형 느낌의 아이콘
- DAW 스타일 멀티트랙 waveform UI
- 오디오/비디오 파일 로드, 비디오는 audio track만 추출
- play/pause/stop/seek/speed
- 재생 중 seek하면 해당 위치부터 계속 play
- timeline 끝까지 가면 stop, 단 recording 중에는 timeline 계속 확장
- track volume/pan/mute/solo/reverb
- track별 peak meter
- record arm은 한 번에 한 트랙만 활성화
- 녹음 시 playback도 같이 시작
- stop 시 recording/playback 둘 다 정지
- 기존 오디오 트랙 위에 녹음하면 해당 구간 overwrite
- waveform move mode와 1ms/10ms nudge
- zoom 64x와 고확대 timeline 세부 눈금
- Freeverb3 기반 native reverb
- LAME 기반 MP3 mix output
- vocal/backing quick split output
- save/load session
- save/load/mix/split 시 파일 이름 직접 입력
- Android SAF folder picker로 저장/로드해서 EPERM 방지
- 작업 중 loading overlay
- 도움말 페이지

구현 후 반드시 실행:
- dart format lib test
- flutter analyze
- flutter test
- flutter build apk --release

split은 현재 AI stem separation이 아니라 lightweight DSP split이어도 된다. 단, 문서에 한계를 명확히 표시하고 나중에 ONNX/TFLite AI split으로 확장 가능한 구조로 만들어줘.
```

## 22. 더 안전한 이어받기 방법

가능하면 Markdown 문서와 스크린샷만 넘기기보다 원본 프로젝트 전체를 같이 넘기는 것을 추천합니다.

우선순위:

1. 가장 좋음: GitHub private repo 또는 USB/클라우드로 프로젝트 폴더 전체 이동
2. 괜찮음: 프로젝트 ZIP + 이 문서 + 스크린샷
3. 가능하지만 재구현 필요: 이 문서 + 스크린샷만 사용
4. 부적합: APK만 사용

APK만 있으면 앱 설치와 테스트는 가능하지만 정상적인 개발 이어받기는 거의 어렵습니다.

