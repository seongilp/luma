import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

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
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MacosTheme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasSel) ..._actions(context) else _viewLabel(),
          const Spacer(),
          _filter(),
          const SizedBox(width: 10),
          _sort(),
          const SizedBox(width: 4),
          _orderButton(),
          const SizedBox(width: 12),
          _viewModeToggle(),
          const SizedBox(width: 12),
          _thumbSlider(),
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
    final ok = await confirm(context,
        title: '휴지통으로 이동', message: '$n개의 사진을 휴지통으로 보낼까요?');
    if (ok) await state.deleteSelected();
  }

  Future<void> _move(BuildContext context, {required bool copy}) async {
    final dest = await getDirectoryPath(confirmButtonText: copy ? '복사' : '이동');
    if (dest == null) return;
    if (copy) {
      await state.copySelected(dest);
    } else {
      await state.moveSelected(dest);
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
    final fmt = await pickExportFormat(context);
    if (fmt == null) return;
    final dest = await getDirectoryPath(confirmButtonText: '여기로 내보내기');
    if (dest == null) return;
    await FileOps.exportImages(
      state.selection.toList(),
      dest,
      format: fmt.format,
      maxDim: fmt.maxDim,
    );
  }

  // ── 별점/즐겨찾기 필터 ────────────────────────────────────
  Widget _filter() {
    return MacosPopupButton<RatingFilter>(
      value: state.ratingFilter,
      items: RatingFilter.values
          .map((f) => MacosPopupMenuItem(value: f, child: Text(f.label)))
          .toList(),
      onChanged: (v) => v == null ? null : state.setRatingFilter(v),
    );
  }

  // ── 보기 옵션 ─────────────────────────────────────────────
  Widget _sort() {
    return MacosPopupButton<SortField>(
      value: state.sortField,
      items: SortField.values
          .map((f) => MacosPopupMenuItem(value: f, child: Text(f.label)))
          .toList(),
      onChanged: (v) => v == null ? null : state.setSort(v),
    );
  }

  Widget _viewModeToggle() {
    final list = state.gridMode == GridMode.list;
    return Row(
      children: [
        MacosIconButton(
          icon: MacosIcon(CupertinoIcons.square_grid_2x2,
              size: 15, color: list ? Colors.grey : null),
          onPressed: () => state.setGridMode(GridMode.grid),
        ),
        MacosIconButton(
          icon: MacosIcon(CupertinoIcons.list_bullet,
              size: 15, color: list ? null : Colors.grey),
          onPressed: () => state.setGridMode(GridMode.list),
        ),
      ],
    );
  }

  Widget _orderButton() {
    return MacosIconButton(
      icon: MacosIcon(
        state.ascending ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
        size: 16,
      ),
      onPressed: state.toggleOrder,
    );
  }

  Widget _thumbSlider() {
    return Row(
      children: [
        const MacosIcon(CupertinoIcons.photo, size: 14, color: Colors.grey),
        SizedBox(
          width: 100,
          child: MacosSlider(
            value: state.thumbSize,
            min: 110,
            max: 300,
            onChanged: state.setThumbSize,
          ),
        ),
      ],
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
    return MacosTooltip(
      message: tip,
      child: MacosIconButton(
        icon: MacosIcon(
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
