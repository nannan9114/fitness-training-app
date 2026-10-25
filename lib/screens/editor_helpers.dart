import 'package:flutter/material.dart';

Future<String?> requestName(
  BuildContext context,
  String title,
  String initial,
) {
  var value = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '名称'),
          onChanged: (text) => update(() => value = text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: value.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

class EditorBackGuard extends StatefulWidget {
  const EditorBackGuard({
    super.key,
    required this.dirty,
    required this.onSave,
    required this.child,
  });
  final bool dirty;
  final Future<bool> Function() onSave;
  final Widget child;
  @override
  State<EditorBackGuard> createState() => _EditorBackGuardState();
}

class _EditorBackGuardState extends State<EditorBackGuard> {
  bool _allowPop = false;
  bool _asking = false;

  Future<void> _handleBack(bool didPop, Object? result) async {
    if (didPop || _asking) return;
    _asking = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('有未保存的修改'),
        content: const Text('保存修改后再离开？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('放弃修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final leave =
        action == 'discard' || (action == 'save' && await widget.onSave());
    _asking = false;
    if (!mounted || !leave) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.dirty || _allowPop,
    onPopInvokedWithResult: _handleBack,
    child: widget.child,
  );
}
