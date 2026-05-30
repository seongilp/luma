import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../models/sort_filter.dart';
import '../services/file_ops.dart';
import '../state/app_state.dart';
import 'compare_view.dart';
import 'dialogs.dart';
import 'export_presets.dart';

/// 그리드 위 컨트롤 스트립.
/// 왼쪽: 선택 시 작업 버튼(삭제·이름변경·이동·복사·즐겨찾기).
/// 오른쪽: 검색·정렬·정렬방향·필터·썸네일 크기.
class ControlBar extends StatelessWidget {
  final AppState state;
  const ControlBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hasSel = state.selectedCount > 0;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasSel) ..._actions(context) else _viewLabel(),
          const Spacer(),
          _filter(context),
          const SizedBox(width: 8),
          _sort(context),
          _orderButton(),
          const SizedBox(width: 10),
          _viewModeToggle(),
          const SizedBox(width: 10),
          _thumbSlider(context),
        ],
      ),
    );
  }

  /// 비선택 시 왼쪽: 현재 보기 이름 + 장수.
  Widget _viewLabel() {
    return Text(
      '${state.viewTitle}  ·  ${state.visibleItems.length}장',
      style: const TextStyle(fontSize: 13, color: Colors.grey),
    );
  }

  // ── 선택 시 작업 ──────────────────────────────────────────
  List<Widget> _actions(BuildContext context) {
    return [
      Text('${state.selectedCount}개 선택', style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 10),
      _ActionBtn(
        icon: CupertinoIcons.rectangle_split_3x1,
        tip: '비교 (2~4장)',
        enabled: state.selectedCount >= 2 && state.selectedCount <= 4,
        onTap: () => _compare(context),
      ),
      _ActionBtn(icon: CupertinoIcons.heart, tip: '즐겨찾기', onTap: state.favoriteSelected),
      _ActionBtn(
        icon: CupertinoIcons.pencil,
        tip: '이름 변경',
        enabled: state.selectedCount == 1,
        onTap: () => _rename(context),
      ),
      _ActionBtn(icon: CupertinoIcons.folder, tip: '이동', onTap: () => _move(context, copy: false)),
      _ActionBtn(icon: CupertinoIcons.doc_on_doc, tip: '복사', onTap: () => _move(context, copy: true)),
      _ActionBtn(icon: CupertinoIcons.square_arrow_up, tip: '내보내기', onTap: () => _export(context)),
      _ActionBtn(
        icon: CupertinoIcons.macwindow,
        tip: 'Finder에서 보기',
        enabled: state.selectedCount == 1,
        onTap: () => FileOps.showInFinder(state.selection.first),
      ),
      _ActionBtn(icon: CupertinoIcons.delete, tip: '삭제(휴지통)', danger: true, onTap: () => _delete(context)),
      const SizedBox(width: 8),
      _ActionBtn(icon: CupertinoIcons.clear, tip: '선택 해제', onTap: state.clearSelection),
    ];
  }

  Future<void> _rename(BuildContext context) async {
    final path = state.selection.first;
    final current = path.split('/').last;
    final name = await promptText(context, title: '이름 변경', initial: current);
    if (name != null) await state.renameOne(path, name);
  }

  Future<void> _delete(BuildContext context) async {
    final n = state.selectedCount;
    final messenger = ScaffoldMessenger.of(context);
    if (!state.confirmDelete) {
      final err = await state.deleteSelected();
      if (err != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(err), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final ok = await confirm(context,
        title: '휴지통으로 이동', message: '$n개의 사진을 휴지통으로 보낼까요?');
    if (!ok) return;
    final err = await state.deleteSelected();
    if (err != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _move(BuildContext context, {required bool copy}) async {
    final messenger = ScaffoldMessenger.of(context);
    final dest = await getDirectoryPath(confirmButtonText: copy ? '복사' : '이동');
    if (dest == null) return;
    final err = copy ? await state.copySelected(dest) : await state.moveSelected(dest);
    if (err != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err), behavior: SnackBarBehavior.floating));
    }
  }

  void _compare(BuildContext context) {
    final paths = [
      for (final it in state.visibleItems)
        if (state.isSelected(it.path) && !it.isVideo) it.path
    ];
    if (paths.length < 2) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => CompareView(paths: paths),
    ));
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final fmt = await pickExportFormat(context);
    if (fmt == null) return;
    final dest = await getDirectoryPath(confirmButtonText: '여기로 내보내기');
    if (dest == null) return;
    final total = state.selectedCount;
    final n = await FileOps.exportImages(
      state.selection.toList(),
      dest,
      format: fmt.format,
      maxDim: fmt.maxDim,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(n == total
              ? '$n개 내보내기 완료'
              : '$n/$total개 내보냄 (나머지는 미지원 형식이거나 실패)'),
          behavior: SnackBarBehavior.floating));
  }

  // ── 별점/즐겨찾기 필터 ────────────────────────────────────
  Widget _filter(BuildContext context) {
    return _CompactDropdown<RatingFilter>(
      value: state.ratingFilter,
      values: RatingFilter.values,
      labelOf: (f) => f.label,
      onChanged: (v) => state.setRatingFilter(v),
    );
  }

  // ── 보기 옵션 ─────────────────────────────────────────────
  Widget _sort(BuildContext context) {
    return _CompactDropdown<SortField>(
      value: state.sortField,
      values: SortField.values,
      labelOf: (f) => f.label,
      onChanged: (v) => state.setSort(v),
    );
  }

  Widget _viewModeToggle() {
    final list = state.gridMode == GridMode.list;
    return Row(
      children: [
        IconButton(
          icon: Icon(CupertinoIcons.square_grid_2x2,
              size: 15, color: list ? Colors.grey : null),
          onPressed: () => state.setGridMode(GridMode.grid),
        ),
        IconButton(
          icon: Icon(CupertinoIcons.list_bullet,
              size: 15, color: list ? null : Colors.grey),
          onPressed: () => state.setGridMode(GridMode.list),
        ),
      ],
    );
  }

  Widget _orderButton() {
    return IconButton(
      icon: Icon(
        state.ascending ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
        size: 16,
      ),
      onPressed: state.toggleOrder,
    );
  }

  Widget _thumbSlider(BuildContext context) {
    return Row(
      children: [
        const Icon(CupertinoIcons.photo, size: 14, color: Colors.grey),
        const SizedBox(width: 2),
        SizedBox(
          width: 96,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: state.thumbSize,
              min: 110,
              max: 300,
              onChanged: state.setThumbSize,
            ),
          ),
        ),
      ],
    );
  }
}

/// 밑줄 없는 컴팩트 드롭다운 (컨트롤바용).
class _CompactDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final void Function(T) onChanged;
  const _CompactDropdown({
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(CupertinoIcons.chevron_down, size: 11),
          style: TextStyle(fontSize: 13, color: cs.onSurface),
          padding: EdgeInsets.zero,
          items: [
            for (final v in values)
              DropdownMenuItem(value: v, child: Text(labelOf(v))),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  const _ActionBtn({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: IconButton(
        icon: Icon(
          icon,
          size: 18,
          color: !enabled
              ? Colors.grey
              : danger
                  ? Colors.redAccent
                  : null,
        ),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}
