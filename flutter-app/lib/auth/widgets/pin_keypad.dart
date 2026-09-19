import 'package:flutter/material.dart';

/// Set of dots indicating how many digits of a PIN have been entered.
///
/// Renders [total] circles; the first [length] are filled with the
/// primary color. Used by both the PIN setup and lock screens.
class PinDots extends StatelessWidget {
  const PinDots({
    required this.length,
    super.key,
    this.total = 6,
  });

  /// Number of digits currently entered.
  final int length;

  /// Total number of digits in the PIN (defaults to 6).
  final int total;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final outline = Theme.of(context).colorScheme.outline;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? primary : Colors.transparent,
            border: Border.all(
              color: filled ? primary : outline,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// On-screen numeric keypad for PIN entry.
///
/// Renders digits 0-9 plus a backspace key as large touch targets,
/// replacing the system keyboard. Callers manage their own entry
/// state and react via [onDigit] and [onBackspace].
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    super.key,
  });

  /// Called with the digit ('0'-'9') each time a number key is tapped.
  final ValueChanged<String> onDigit;

  /// Called when the backspace key is tapped.
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final key in row)
                  if (key == '')
                    const SizedBox(
                      width: 76,
                      height: 64,
                    )
                  else if (key == 'backspace')
                    SizedBox(
                      width: 76,
                      height: 64,
                      child: IconButton(
                        onPressed: onBackspace,
                        iconSize: 28,
                        icon: const Icon(Icons.backspace_outlined),
                        tooltip: 'Delete',
                      ),
                    )
                  else
                    SizedBox(
                      width: 76,
                      height: 64,
                      child: InkResponse(
                        onTap: () => onDigit(key),
                        radius: 32,
                        child: Center(
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
