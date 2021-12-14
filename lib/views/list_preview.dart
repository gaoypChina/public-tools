import 'package:flutter/material.dart';
import 'package:public_tools/core/plugin_manager.dart';
import 'package:public_tools/core/plugin_result_item.dart';

import 'result_item_view.dart';

class PluginListView extends StatefulWidget {
  final List<PluginListResultItem> list;

  final int selectedIndex;

  final Widget preview;

  final Function onTap;

  PluginListView({
    Key key,
    this.list,
    this.onTap,
    this.selectedIndex,
    this.preview,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PluginListViewState();
}

class _PluginListViewState extends State<PluginListView> {
  final scrollController = new ScrollController();
  final selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant PluginListView oldWidget) {
    // 计算是否需要滚动
    final visibleMinIndex = (scrollController.offset / 48).ceil();
    final visibleMaxIndex = visibleMinIndex + 8;
    final visible = visibleMinIndex <= widget.selectedIndex &&
        widget.selectedIndex <= visibleMaxIndex;
    if (!visible) {
      // 根据当前滚动的位置，和要滚动的位置，计算向上还是向下滚动
      final nextOffset = 48.0 * (widget.selectedIndex - 8);
      final isScrollDown = nextOffset > scrollController.offset;
      if (isScrollDown) {
        scrollController.jumpTo(nextOffset);
      } else {
        scrollController.jumpTo(widget.selectedIndex * 48.0);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    // final selectedItem = widget.list.length > widget.selectedIndex
    //     ? widget.list.elementAt(widget.selectedIndex)
    //     : null;
    // if (selectedItem != null) {
    //   PluginManager.instance.handleResultSelected(selectedItem);
    // }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 2,
        child: ListView.builder(
          controller: scrollController,
          itemBuilder: (pluginContext, itemIndex) {
            var resultItem = widget.list.elementAt(itemIndex);
            var pluginView = PluginResultItemView(
              key: itemIndex == widget.selectedIndex
                  ? selectedKey
                  : Key(widget.selectedIndex.toString()),
              item: resultItem.result,
              selected: itemIndex == widget.selectedIndex,
              onTap: () => PluginManager.instance.handleTap(resultItem),
            );
            return pluginView;
          },
          itemCount: widget.list.length,
        ),
      ),
      if (widget.preview != null)
        Expanded(
          flex: 3,
          child: Container(
              height: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.grey[300],
              child: Container(
                child: widget.preview,
              )),
        )
    ]);
  }
}
