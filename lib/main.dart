import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';

const Color _pageBackground = Color(0xFF020202);
const Color _sheetBackground = Color(0xFF252525);
const Color _cardBackground = Color(0xFF353535);
const Color _cardBorder = Color(0x33FFFFFF);
const Color _dividerColor = Color(0x66FFFFFF);
const Color _mutedText = Color(0xB8FFFFFF);
const Color _placeholderText = Color(0x66FFFFFF);

/// The handwritten/script font used for the "brand" moments only:
/// the page title, the bottom-sheet headlines, the search hint, and the
/// Confirm button. Everything else (emails, app names, passwords) stays
/// in the default system font for readability.
const String _brandFont = 'PlaywriteUSTrad';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.initialize();
  runApp(PasswordManagerApp(store: store));
}

class PasswordManagerApp extends StatelessWidget {
  const PasswordManagerApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Password',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _pageBackground,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color.fromARGB(255, 19, 19, 19),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF1F1F1F),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: VaultPage(store: store),
    );
  }
}

class VaultPage extends StatefulWidget {
  const VaultPage({super.key, required this.store});

  final AppStore store;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _visiblePasswords = <String, bool>{};
  String? _activeCardId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final groupedEntries = widget.store.groupedVisibleEntries();
        final isSearching = widget.store.searchQuery.isNotEmpty;
        return Scaffold(
          body: Stack(
            children: <Widget>[
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color.fromARGB(0, 4, 4, 4),
                      Color.fromARGB(0, 2, 2, 2),
                      Color.fromARGB(0, 0, 0, 0),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: <Widget>[
                      const SliverPersistentHeader(
                        pinned: true,
                        delegate: _VaultHeaderDelegate(),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                        sliver: SliverList.list(
                          children: <Widget>[
                            if (!isSearching) ...<Widget>[
                              _SectionHeader(
                                title: 'My Email',
                                onAdd: () => _openAddEmailSheet(context),
                              ),
                              const SizedBox(height: 14),
                              if (widget.store.emails.isEmpty)
                                const _EmptyStateCard(
                                  title: 'No email added yet',
                                  message:
                                      'Add your email accounts first. Those emails will be available while saving app and website passwords.',
                                )
                              else
                                ...widget.store.emails.map(_buildEmailCard),
                              const SizedBox(height: 24),
                            ],
                            if (groupedEntries.isEmpty)
                              const _EmptyStateCard(
                                title: 'No passwords saved yet',
                                message:
                                    'Use the floating add button to store passwords for apps and websites after you add at least one email.',
                              )
                            else
                              ...groupedEntries.entries.expand((group) {
                                return <Widget>[
                                  _AlphabetHeader(letter: group.key),
                                  const SizedBox(height: 10),
                                  ...group.value.map(_buildPasswordCard),
                                  const SizedBox(height: 16),
                                ];
                              }),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomControls(
                  controller: _searchController,
                  onChanged: widget.store.updateSearchQuery,
                  addButton: _buildFloatingButton(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingButton(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.store.emails.isEmpty) {
                _openAddEmailSheet(context);
                return;
              }
              _openAddPasswordSheet(context);
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color.fromARGB(43, 255, 255, 255),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF202020),
                    Color(0xFF181818),
                  ],
                ),
              ),
              child: const Center(child: Icon(Icons.add, size: 36)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard(EmailCredential email) {
    final isActive = _activeCardId == 'email:${email.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onLongPress: () => _setActiveCard('email:${email.id}'),
        onTap: isActive ? _clearActiveCard : null,
        child: _GlassCard(
          isActive: isActive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isActive
                    ? Padding(
                        key: const ValueKey('email-actions'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardActions(
                          onEdit: () => _editEmail(email),
                          onRemove: () => _removeEmail(email),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('email-actions-empty')),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      email.email,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleVisibility(email.id),
                    icon: Icon(
                      _visiblePasswords[email.id] == true
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    color: Colors.white70,
                    tooltip: 'Show password',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const _SoftDivider(),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _visiblePasswords[email.id] == true
                          ? email.password
                          : _maskPassword(email.password),
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPassword(email.password),
                    icon: const Icon(Icons.content_copy_outlined),
                    color: Colors.white70,
                    tooltip: 'Copy password',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordCard(PasswordEntry entry) {
    final linkedEmail = widget.store.emailById(entry.emailId);
    final title = entry.username.isEmpty
        ? entry.appName
        : '${entry.appName} (${entry.username})';
    final isActive = _activeCardId == 'entry:${entry.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onLongPress: () => _setActiveCard('entry:${entry.id}'),
        onTap: isActive ? _clearActiveCard : null,
        child: _GlassCard(
          isActive: isActive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isActive
                    ? Padding(
                        key: const ValueKey('entry-actions'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardActions(
                          onEdit: () => _editEntry(entry),
                          onRemove: () => _removeEntry(entry),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('entry-actions-empty')),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              const _SoftDivider(),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      linkedEmail?.email ?? 'Unknown email',
                      style: const TextStyle(fontSize: 16, color: _mutedText),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleVisibility(entry.id),
                    icon: Icon(
                      _visiblePasswords[entry.id] == true
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    color: Colors.white70,
                    tooltip: 'Show password',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const _SoftDivider(),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _visiblePasswords[entry.id] == true
                          ? entry.password
                          : _maskPassword(entry.password),
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 1.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyPassword(entry.password),
                    icon: const Icon(Icons.content_copy_outlined),
                    color: Colors.white70,
                    tooltip: 'Copy password',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bottom sheets -------------------------------------------------
  //
  // Both "add" flows now open as a bottom sheet over the current screen
  // (matching the mockup) instead of pushing a brand new full-screen
  // route. Two things changed on purpose, both aimed at the
  // lag/freeze on Confirm:
  //   1. A bottom sheet is a much lighter route than a full
  //      MaterialPageRoute with its own Scaffold/AppBar transition.
  //   2. The actual save (Hive write + notifyListeners, which rebuilds
  //      the whole list) now happens *while the sheet is still open and
  //      idle*, and the sheet only pops afterwards. Previously, Confirm
  //      popped the form page immediately and the save+rebuild ran
  //      concurrently with that pop animation, which is what caused the
  //      dropped frames / stutter.

  Future<void> _openAddEmailSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddEmailSheet(store: widget.store),
    );

    if (saved == true && mounted) {
      _clearActiveCard();
    }
  }

  Future<void> _openEditEmailSheet(
    BuildContext context,
    EmailCredential email,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddEmailSheet(store: widget.store, initialEmail: email),
    );

    if (saved == true && mounted) {
      _clearActiveCard();
    }
  }

  Future<void> _openAddPasswordSheet(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddPasswordSheet(store: widget.store),
    );

    if (saved == true && mounted) {
      _clearActiveCard();
    }
  }

  Future<void> _openEditPasswordSheet(
    BuildContext context,
    PasswordEntry entry,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddPasswordSheet(store: widget.store, initialEntry: entry),
    );

    if (saved == true && mounted) {
      _clearActiveCard();
    }
  }

  void _setActiveCard(String cardId) {
    setState(() {
      _activeCardId = cardId;
    });
  }

  void _clearActiveCard() {
    if (_activeCardId == null) {
      return;
    }
    setState(() {
      _activeCardId = null;
    });
  }

  Future<void> _editEmail(EmailCredential email) async {
    _clearActiveCard();
    await _openEditEmailSheet(context, email);
  }

  Future<void> _editEntry(PasswordEntry entry) async {
    _clearActiveCard();
    await _openEditPasswordSheet(context, entry);
  }

  Future<void> _removeEmail(EmailCredential email) async {
    await widget.store.deleteEmail(email.id);
    if (!mounted) {
      return;
    }
    _visiblePasswords.remove(email.id);
    _clearActiveCard();
  }

  Future<void> _removeEntry(PasswordEntry entry) async {
    await widget.store.deleteEntry(entry.id);
    if (!mounted) {
      return;
    }
    _visiblePasswords.remove(entry.id);
    _clearActiveCard();
  }

  void _toggleVisibility(String id) {
    setState(() {
      _visiblePasswords[id] = !(_visiblePasswords[id] ?? false);
    });
  }

  Future<void> _copyPassword(String password) async {
    await Clipboard.setData(ClipboardData(text: password));
    if (!mounted) {
      return;
    }
    // _showSnackBar('Password copied');
  }

  String _maskPassword(String password) {
    final length = password.isEmpty ? 8 : password.length.clamp(8, 18);
    return List<String>.filled(length, '•').join();
  }

  // void _showSnackBar(String message) {
  //   ScaffoldMessenger.of(context)
  //     ..hideCurrentSnackBar()
  //     ..showSnackBar(SnackBar(content: Text(message)));
  // }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    this.height = 52,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x52FFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF202020),
            Color(0xFF181818),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Transform.translate(
            offset: const Offset(0, 1), // icon sits slightly lower
            child: const Icon(
              Icons.search,
              color: Color(0xB3FFFFFF),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                  },
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  color: Color(0xFFDDDDDD),
                  // fontFamily: _brandFont,
                  fontSize: 18,
                  height: 1,
                ),
                cursorColor: Colors.white70,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search for app name',
                  hintStyle: TextStyle(
                    color: Color(0x88FFFFFF),
                    fontFamily: _brandFont,
                    fontSize: 18,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _VaultHeaderDelegate();

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 248;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (1 - (shrinkOffset / (maxExtent - minExtent))).clamp(
      0.0,
      1.0,
    );
    return _VaultHeader(progress: progress);
  }

  @override
  bool shouldRebuild(covariant _VaultHeaderDelegate oldDelegate) => false;
}

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final titleSize = lerpDouble(18, 30, progress)!;
    final titleTop = lerpDouble(18, 120, progress)!;
    final titleOpacity = Curves.easeOut.transform(
      ((progress - 0.08) / 0.92).clamp(0.0, 1.0),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 0, 0, 0),
            Color.fromARGB(236, 0, 0, 0),
            Color.fromARGB(185, 0, 0, 0),
            Color.fromARGB(72, 0, 0, 0),
            Color.fromARGB(0, 0, 0, 0),
          ],
          stops: [0.00, 0.12, 0.42, 0.78, 1.00],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: titleTop,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: titleOpacity,
                  child: Text(
                    'Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _brandFont,
                      fontSize: titleSize,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.controller,
    required this.onChanged,
    required this.addButton,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget addButton;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.fromARGB(0, 0, 0, 0),
              Color.fromARGB(190, 0, 0, 0),
              Color.fromARGB(255, 0, 0, 0),
            ],
            stops: <double>[0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SearchField(
                    controller: controller,
                    onChanged: onChanged,
                    height: 58,
                  ),
                ),
                const SizedBox(width: 14),
                addButton,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, color: _mutedText),
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              color: _mutedText,
              iconSize: 24,
              splashRadius: 24,
            ),
          ],
        ),
        // const SizedBox(height: 10),
        const _SoftDivider(),
      ],
    );
  }
}

class _AlphabetHeader extends StatelessWidget {
  const _AlphabetHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          letter,
          style: const TextStyle(fontSize: 18, color: _mutedText),
        ),
        const SizedBox(height: 10),
        const _SoftDivider(),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 10, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: _mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: _dividerColor,
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.isActive = false});

  final Widget child;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // NOTE: this fakes a "frosted glass" look with a translucent fill +
    // hairline border instead of a real backdrop blur. A real blur
    // (BackdropFilter/ImageFilter.blur) behind every card in a scrolling
    // list is one of the more reliable ways to make a Flutter list janky,
    // since each blurred card has to be re-rendered as you scroll. This
    // keeps the vibe without paying that cost.
    return RepaintBoundary(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isActive ? 1.02 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(20, 8, 10, 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? const Color(0x66FFFFFF) : _cardBorder,
            ),
            color: _cardBackground,
            boxShadow: isActive
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({required this.onEdit, required this.onRemove});

  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _ActionChip(
          label: 'Edit',
          icon: Icons.edit_rounded,
          color: Colors.blueAccent,
          onTap: onEdit,
        ),
        const SizedBox(width: 10),
        _ActionChip(
          label: 'Remove',
          icon: Icons.delete_outline_rounded,
          color: Colors.redAccent,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared chrome for both bottom sheets: a drag handle, a title, and a
/// keyboard-aware scroll view so fields never get hidden by the keyboard.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Text(
                  // "- - - - - - - - - $title - - - - - - - - -",
                  title,
                  style: const TextStyle(
                    fontFamily: _brandFont,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new email + password identity.
class _AddEmailSheet extends StatefulWidget {
  const _AddEmailSheet({required this.store, this.initialEmail});

  final AppStore store;
  final EmailCredential? initialEmail;

  @override
  State<_AddEmailSheet> createState() => _AddEmailSheetState();
}

class _AddEmailSheetState extends State<_AddEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorText;

  bool get _isEditing => widget.initialEmail != null;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail;
    if (initialEmail != null) {
      _emailController.text = initialEmail.email;
      _passwordController.text = initialEmail.password;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      if (_isEditing) {
        await widget.store.updateEmail(
          id: widget.initialEmail!.id,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.store.addEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on StateError catch (error) {
      setState(() {
        _isSaving = false;
        _errorText = error.message.toString();
      });
    } catch (_) {
      setState(() {
        _isSaving = false;
        _errorText = 'Could not save email';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: _isEditing ? 'edit email' : 'add email',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetField(
              controller: _emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter an email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _SheetField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the password';
                }
                return null;
              },
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            _ConfirmButton(isLoading: _isSaving, onPressed: _confirm),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new app/website password, linked to one of
/// the already-saved emails.
class _AddPasswordSheet extends StatefulWidget {
  const _AddPasswordSheet({required this.store, this.initialEntry});

  final AppStore store;
  final PasswordEntry? initialEntry;

  @override
  State<_AddPasswordSheet> createState() => _AddPasswordSheetState();
}

class _AddPasswordSheetState extends State<_AddPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _appNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorText;
  late String _selectedEmailId = widget.store.emails.first.id;

  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final initialEntry = widget.initialEntry;
    if (initialEntry != null) {
      _appNameController.text = initialEntry.appName;
      _usernameController.text = initialEntry.username;
      _passwordController.text = initialEntry.password;
      _selectedEmailId = initialEntry.emailId;
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      if (_isEditing) {
        await widget.store.updateEntry(
          id: widget.initialEntry!.id,
          appName: _appNameController.text,
          username: _usernameController.text,
          emailId: _selectedEmailId,
          password: _passwordController.text,
        );
      } else {
        await widget.store.addEntry(
          appName: _appNameController.text,
          username: _usernameController.text,
          emailId: _selectedEmailId,
          password: _passwordController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() {
        _isSaving = false;
        _errorText = 'Could not save password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: _isEditing ? 'edit password' : 'add password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetField(
              controller: _appNameController,
              hintText: 'App Name / Website',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the app or website name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _SheetField(
              controller: _usernameController,
              hintText: 'Username (optional)',
            ),
            const SizedBox(height: 16),
            _DropdownShell(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedEmailId,
                dropdownColor: const Color(0xFF242424),
                padding: const EdgeInsets.only(right: 20),
                decoration: const InputDecoration(
                  hintText: 'Email',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                iconEnabledColor: Colors.white,
                borderRadius: BorderRadius.circular(22),
                items: widget.store.emails
                    .map((email) => DropdownMenuItem<String>(
                          value: email.id,
                          child: Text(email.email),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedEmailId = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            _SheetField(
              controller: _passwordController,
              hintText: 'Password',
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the password';
                }
                return null;
              },
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            _ConfirmButton(isLoading: _isSaving, onPressed: _confirm),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _placeholderText, fontSize: 17),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0x88FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0x88FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x88FFFFFF)),
        color: Colors.transparent,
      ),
      child: child,
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed, this.isLoading = false});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        // width: 212,
        height: 64,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: const BorderSide(color: Color(0x44FFFFFF)),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF676767),
                  Color(0xFF4E4E4E),
                  Color(0xFF3B3B3B),
                ],
              ),
              // boxShadow: const <BoxShadow>[
              //   BoxShadow(
              //     color: Color(0x2AFFFFFF),
              //     blurRadius: 12,
              //     offset: Offset(-2, -2),
              //   ),
              //   BoxShadow(
              //     color: Color(0x66000000),
              //     blurRadius: 18,
              //     offset: Offset(8, 12),
              //   ),
              // ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(26)),
                border: Border.all(color: const Color(0x30FFFFFF)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(fontFamily: _brandFont, fontSize: 24),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
