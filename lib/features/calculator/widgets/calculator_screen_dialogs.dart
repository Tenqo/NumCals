import 'package:material_ui/material_ui.dart';

import '../../currency/currency_service.dart';
import '../../history/calculation_history_entry.dart';

Future<void> showCalculatorSettingsDialog({
  required BuildContext context,
  required ThemeMode themeMode,
  required ValueChanged<ThemeMode> onThemeModeChanged,
  required bool isPinned,
  required Future<void> Function(bool) onPinnedChanged,
  required bool isScientific,
  required bool useDegrees,
  required ValueChanged<bool> onDegreesChanged,
  required VoidCallback onDiagnostics,
  required VoidCallback onKeyboardShortcuts,
}) {
  final pageContext = context;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.brightness_auto_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('Change appearance'),
                subtitle: const Text('System, light, or dark'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  showCalculatorAppearanceDialog(
                    context: pageContext,
                    themeMode: themeMode,
                    onThemeModeChanged: onThemeModeChanged,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('App diagnostics'),
                subtitle: const Text('Check that the app and services work'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  onDiagnostics();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.keyboard_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: const Text('Keyboard shortcuts'),
                subtitle: const Text('Use the keyboard to calculate faster'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  onKeyboardShortcuts();
                },
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Keep on top'),
                        const SizedBox(height: 3),
                        Text(
                          'Show above other windows',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isPinned,
                    onChanged: (value) async {
                      await onPinnedChanged(value);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              if (isScientific) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(child: Text('Use radians')),
                    Switch(
                      value: !useDegrees,
                      onChanged: (value) {
                        onDegreesChanged(!value);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showCalculatorAppearanceDialog({
  required BuildContext context,
  required ThemeMode themeMode,
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      title: const Text('Appearance'),
      content: RadioGroup<ThemeMode>(
        groupValue: themeMode,
        onChanged: (mode) {
          if (mode == null) return;
          onThemeModeChanged(mode);
          Navigator.pop(dialogContext);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('System default'),
              subtitle: const Text('Match Windows appearance'),
              value: ThemeMode.system,
            ),
            RadioListTile<ThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Light'),
              value: ThemeMode.light,
            ),
            RadioListTile<ThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark'),
              value: ThemeMode.dark,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> showCalculatorKeyboardShortcutsDialog({
  required BuildContext context,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const Text('Keyboard shortcuts'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShortcutRow(keys: '0–9', action: 'Enter numbers'),
          _ShortcutRow(keys: '+  −  *  /', action: 'Choose an operation'),
          _ShortcutRow(keys: 'Enter  or  =', action: 'Calculate'),
          _ShortcutRow(keys: 'Backspace', action: 'Delete the last key'),
          _ShortcutRow(keys: 'Esc', action: 'Clear'),
          _ShortcutRow(keys: '(  )  %  ^', action: 'More operations'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> showCalculatorHistoryDialog({
  required BuildContext context,
  required List<CalculationHistoryEntry> Function() entries,
  required VoidCallback onClear,
  required ValueChanged<CalculationHistoryEntry> onSelect,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final currentEntries = entries();
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              const Expanded(child: Text('Recent calculations')),
              if (currentEntries.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: () {
                    onClear();
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: currentEntries.isEmpty
                ? Text(
                    'Your recent calculations will appear here.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: currentEntries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = currentEntries[index];
                      final resultLabel = entry.toCurrency == null
                          ? entry.result
                          : '${entry.result} ${entry.toCurrency}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          resultLabel,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 18),
                        ),
                        subtitle: Text(
                          entry.expression,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          onSelect(entry);
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> showCalculatorDiagnosticsDialog({
  required BuildContext context,
  required CurrencyService currencyService,
  required bool calculationWorks,
  required VoidCallback onOpenFrankfurter,
}) {
  var checkStarted = false;
  var currencyStatus = 'Checking...';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        if (!checkStarted) {
          checkStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              await currencyService.fetchCurrencies();
              await currencyService.fetchRate('USD', 'EUR');
              if (!dialogContext.mounted) return;
              setDialogState(
                () => currencyStatus = 'Working · daily, not live',
              );
            } on Object catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() => currencyStatus = 'Unavailable — $error');
            }
          });
        }

        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('App diagnostics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DiagnosticStatus(
                label: 'User interface',
                status: 'Working',
              ),
              const SizedBox(height: 12),
              _DiagnosticStatus(
                label: 'Calculator',
                status: calculationWorks ? 'Working' : 'Not working',
              ),
              const SizedBox(height: 12),
              _DiagnosticStatus(
                label: 'Currency:',
                status: currencyStatus,
                linkLabel: 'Stock license',
                onLinkTap: onOpenFrankfurter,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              keys,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(action)),
        ],
      ),
    );
  }
}

class _DiagnosticStatus extends StatelessWidget {
  const _DiagnosticStatus({
    required this.label,
    required this.status,
    this.linkLabel,
    this.onLinkTap,
  });

  final String label;
  final String status;
  final String? linkLabel;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChecking = status == 'Checking...';
    final color = isChecking
        ? colorScheme.onSurfaceVariant
        : status.startsWith('Working')
        ? isDark
              ? const Color(0xFF30D158)
              : const Color(0xFF287840)
        : colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (linkLabel == null)
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
        else
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onLinkTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  linkLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 3),
        Text(status, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
