import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050608),
      appBar: AppBar(
        title: const Text('PineWave Help'),
        backgroundColor: const Color(0xFF050608),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          _BrandCard(theme: theme),
          const SizedBox(height: 16),
          _HelpSection(
            title: '기본 사용',
            children: const <_HelpItem>[
              _HelpItem(
                icon: Icons.add_box_rounded,
                title: '빈 트랙 추가',
                description: '새 오디오 트랙을 만들고, 나중에 파일을 넣거나 녹음 대상으로 사용할 수 있습니다.',
              ),
              _HelpItem(
                icon: Icons.folder_open_rounded,
                title: '파일 열기',
                description:
                    '오디오 파일과 동영상 파일을 불러옵니다. 동영상은 안에 들어있는 사운드만 추출해서 로드합니다.',
              ),
              _HelpItem(
                icon: Icons.more_vert_rounded,
                title: '프로젝트 메뉴',
                description: '세션 저장/불러오기, 선택 트랙 MP3 믹스, 보컬/반주 분리 기능을 실행합니다.',
              ),
              _HelpItem(
                icon: Icons.help_outline_rounded,
                title: '도움말',
                description: '현재 화면입니다. 아이콘 뜻과 주요 기능을 빠르게 확인할 수 있습니다.',
              ),
            ],
          ),
          _HelpSection(
            title: '트랙 버튼',
            children: const <_HelpItem>[
              _HelpItem(
                textIcon: 'R',
                title: 'Record Arm',
                description:
                    '녹음할 트랙을 선택합니다. 전체 트랙 중 하나만 켜지며, 아래 녹음 버튼이 활성화됩니다.',
              ),
              _HelpItem(
                textIcon: 'M',
                title: 'Mute',
                description: '해당 트랙 소리를 끕니다. 재생과 믹스에서 들리지 않습니다.',
              ),
              _HelpItem(
                textIcon: 'S',
                title: 'Solo',
                description: '해당 트랙만 들리게 합니다. 다른 트랙은 자동으로 잠시 비활성화됩니다.',
              ),
              _HelpItem(
                textIcon: 'Mix',
                title: 'Mix 선택',
                description: 'MP3로 합치거나 보컬/반주 분리할 트랙을 선택합니다.',
              ),
              _HelpItem(
                icon: Icons.close_rounded,
                title: '트랙 오디오 삭제',
                description: '트랙은 남기고 안에 들어있는 오디오 파일만 지웁니다.',
              ),
              _HelpItem(
                icon: Icons.delete_outline_rounded,
                title: '트랙 삭제',
                description: '트랙 전체와 그 안의 오디오를 함께 삭제합니다.',
              ),
            ],
          ),
          _HelpSection(
            title: '믹서 조절',
            children: const <_HelpItem>[
              _HelpItem(
                icon: Icons.volume_up_rounded,
                title: 'Vol',
                description: '트랙별 볼륨을 조절합니다. 피크미터와 실제 재생/믹스에 바로 반영됩니다.',
              ),
              _HelpItem(
                icon: Icons.swap_horiz_rounded,
                title: 'Pan',
                description: '소리를 왼쪽 L, 중앙 C, 오른쪽 R 방향으로 배치합니다.',
              ),
              _HelpItem(
                icon: Icons.graphic_eq_rounded,
                title: '피크미터',
                description: '현재 소리 크기를 초록, 주황, 빨강으로 표시합니다. 빨강은 피크에 가깝다는 뜻입니다.',
              ),
              _HelpItem(
                icon: Icons.tune_rounded,
                title: 'Reverb 세부 설정',
                description:
                    '트랙별 리버브 프리셋과 Mix, Room, Decay, Damp, Pre-delay, Width 값을 조절합니다.',
              ),
            ],
          ),
          _HelpSection(
            title: '타임라인과 재생',
            children: const <_HelpItem>[
              _HelpItem(
                icon: Icons.play_arrow_rounded,
                title: 'Play / Pause',
                description: '전체 트랙을 같은 플레이헤드 기준으로 재생하거나 일시정지합니다.',
              ),
              _HelpItem(
                icon: Icons.stop_rounded,
                title: 'Stop',
                description: '재생을 멈추고 처음 위치로 돌아갑니다. 녹음 중에는 녹음과 재생을 함께 멈춥니다.',
              ),
              _HelpItem(
                icon: Icons.fiber_manual_record,
                title: 'Record',
                description:
                    'R 버튼으로 선택한 트랙에 녹음합니다. 기존 오디오 위에 녹음하면 해당 구간만 덮어씁니다.',
              ),
              _HelpItem(
                icon: Icons.open_with_rounded,
                title: 'Move Mode',
                description: '파형을 좌우로 밀어 트랙 안의 오디오 시작 위치를 이동합니다.',
              ),
              _HelpItem(
                icon: Icons.zoom_in_rounded,
                title: 'Zoom',
                description: '파형을 한눈에 보거나 확대해서 세밀하게 확인합니다.',
              ),
              _HelpItem(
                icon: Icons.speed_rounded,
                title: 'Speed',
                description: '0.5x, 1.0x, 1.5x, 2.0x 배속으로 재생 속도를 바꿉니다.',
              ),
            ],
          ),
          _HelpSection(
            title: '저장과 출력',
            children: const <_HelpItem>[
              _HelpItem(
                icon: Icons.save_rounded,
                title: 'Save Session',
                description: '현재 트랙 배치, 볼륨, 팬, 리버브, 파일 경로를 세션 JSON으로 저장합니다.',
              ),
              _HelpItem(
                icon: Icons.folder_open_rounded,
                title: 'Load Session',
                description: '저장한 세션 폴더를 선택해서 작업 상태를 다시 불러옵니다.',
              ),
              _HelpItem(
                icon: Icons.merge_type_rounded,
                title: 'Mix selected (.mp3)',
                description: 'Mix로 선택한 트랙을 하나의 MP3 파일로 저장하고 새 트랙으로 불러옵니다.',
              ),
              _HelpItem(
                icon: Icons.call_split_rounded,
                title: 'Split vocal/backing (.mp3)',
                description: '선택한 트랙에서 보컬 중심 성분과 반주 성분을 나눠 MP3 파일로 저장합니다.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF101820), Color(0xFF071114)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF233241)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/branding/pinewave_icon.png',
              width: 74,
              height: 74,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PineWave',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '포큐파인의 가시처럼 날카로운 파형을 다루는 멀티트랙 모바일 플레이어입니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.children});

  final String title;
  final List<_HelpItem> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF3BE3C6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF10141A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF242C36)),
            ),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < children.length; index += 1)
                  _HelpTile(
                    item: children[index],
                    showDivider: index != children.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.item, required this.showDivider});

  final _HelpItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFF232A33)))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _HelpIcon(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpIcon extends StatelessWidget {
  const _HelpIcon({required this.item});

  final _HelpItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A222C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D3A47)),
      ),
      child: item.textIcon == null
          ? Icon(item.icon, color: const Color(0xFF3BE3C6), size: 21)
          : Text(
              item.textIcon!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF3BE3C6),
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _HelpItem {
  const _HelpItem({
    required this.title,
    required this.description,
    this.icon,
    this.textIcon,
  }) : assert(icon != null || textIcon != null);

  final IconData? icon;
  final String? textIcon;
  final String title;
  final String description;
}
