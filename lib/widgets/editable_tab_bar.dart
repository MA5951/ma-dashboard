import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transitioned_indexed_stack/transitioned_indexed_stack.dart';

import 'package:elastic_dashboard/services/settings.dart';
import 'package:elastic_dashboard/util/tab_data.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/pixel_ratio_override.dart';
import 'package:elastic_dashboard/widgets/tab_grid.dart';
import 'package:elastic_dashboard/services/nt_connection.dart';
import 'package:elastic_dashboard/services/nt4_client.dart';

class EditableTabBar extends StatefulWidget {
  final SharedPreferences preferences;
  final NTConnection ntConnection;

  final List<TabData> tabData;

  final Function() onTabCreate;
  final Function(int index) onTabDestroy;
  final Function() onTabMoveLeft;
  final Function() onTabMoveRight;
  final Function(int index, TabData newData) onTabRename;
  final Function(int index) onTabChanged;
  final Function(int index) onTabDuplicate;

  final int currentIndex;

  final double? gridDpiOverride;

  const EditableTabBar({
    super.key,
    required this.preferences,
    required this.ntConnection,
    required this.currentIndex,
    required this.tabData,
    required this.onTabCreate,
    required this.onTabDestroy,
    required this.onTabMoveLeft,
    required this.onTabMoveRight,
    required this.onTabRename,
    required this.onTabChanged,
    required this.onTabDuplicate,
    this.gridDpiOverride,
  });

  @override
  _EditableTabBarState createState() => _EditableTabBarState();
}

class _EditableTabBarState extends State<EditableTabBar> {
  NT4Subscription? colorSubscription;

  Color tabBarColor = Colors.grey;

  late Color fallbackColor;

  @override
  void initState() {
    super.initState();
    _initializeColorSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fallbackColor = Theme.of(context).colorScheme.primaryContainer;

    if (tabBarColor == Colors.grey) {
      tabBarColor = fallbackColor;
    }
  }

  void _initializeColorSubscription() {
    colorSubscription = widget.ntConnection.subscribe(
      '/MALog/Dash/TabBarColor',
      0.06,
    );

    colorSubscription?.listen((value, timestamp) {
      if (value is String && value.startsWith('#')) {
        final colorValue = int.tryParse(value.substring(1), radix: 16);
        if (colorValue != null) {
          setState(() {
            tabBarColor = Color(colorValue + 0xFF000000);
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          tabBarColor = fallbackColor;
        });
      }
    });
  }

  @override
  void dispose() {
    if (colorSubscription != null) {
      widget.ntConnection.unSubscribe(colorSubscription!);
    }
    super.dispose();
  }

  void renameTab(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Tab'),
          content: Container(
            constraints: const BoxConstraints(
              maxWidth: 200,
            ),
            child: DialogTextInput(
              onSubmit: (value) {
                widget.tabData[index].name = value;
                widget.onTabRename.call(index, widget.tabData[index]);
              },
              initialText: widget.tabData[index].name,
              label: 'Name',
              formatter: LengthLimitingTextInputFormatter(50),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void duplicateTab(BuildContext context, int index) {
    widget.onTabDuplicate.call(index);
  }

  void createTab() {
    widget.onTabCreate();
  }

  void closeTab(int index) {
    // Only close if there’s more than one tab
    if (widget.tabData.length == 1) {
      return;
    }
    widget.onTabDestroy.call(index);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    // Button style for left, add, right (west, add, east) in the upper-right area
    ButtonStyle endButtonStyle = const ButtonStyle(
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      maximumSize: WidgetStatePropertyAll(Size.square(34.0)),
      minimumSize: WidgetStatePropertyAll(Size.zero),
      padding: WidgetStatePropertyAll(EdgeInsets.all(4.0)),
      iconSize: WidgetStatePropertyAll(24.0),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // The row of tabs at the top
        ExcludeFocus(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: tabBarColor,
            width: double.infinity,
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: tabs
                Flexible(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: widget.tabData.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          widget.onTabChanged.call(index);
                        },
                        onSecondaryTapUp: (details) {
                          // If layout is locked, do nothing
                          if (widget.preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked) {
                            return;
                          }
                          // Otherwise show a context menu to rename/duplicate/close
                          showDialog(
                            context: context,
                            builder: (context) {
                              return SimpleDialog(
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => renameTab(context, index),
                                    child: const Text('Rename'),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => duplicateTab(context, index),
                                    child: const Text('Duplicate'),
                                  ),
                                  SimpleDialogOption(
                                    onPressed: () => closeTab(index),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutExpo,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 5.0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.currentIndex == index)
                                ? theme.colorScheme.onPrimaryContainer
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10.0),
                              topRight: Radius.circular(10.0),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.tabData[index].name,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: (widget.currentIndex == index)
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Right side: move-left, add, move-right
                Row(
                  children: [
                    IconButton(
                      style: endButtonStyle,
                      onPressed: !(widget.preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? widget.onTabMoveLeft
                          : null,
                      icon: const Icon(Icons.west),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed: !(widget.preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? createTab
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      style: endButtonStyle,
                      onPressed: !(widget.preferences.getBool(PrefKeys.layoutLocked) ??
                              Defaults.layoutLocked)
                          ? widget.onTabMoveRight
                          : null,
                      icon: const Icon(Icons.east),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // The rest of the screen: the tab contents
        Flexible(
          child: PixelRatioOverride(
            dpiOverride: widget.gridDpiOverride,
            child: Stack(
              children: [
                // Optional grid overlay if "showGrid" is true
                Visibility(
                  visible:
                      widget.preferences.getBool(PrefKeys.showGrid) ?? Defaults.showGrid,
                  child: GridPaper(
                    color: const Color.fromARGB(50, 195, 232, 243),
                    interval: (widget.preferences.getInt(PrefKeys.gridSize) ??
                            Defaults.gridSize)
                        .toDouble(),
                    divisions: 1,
                    subdivisions: 1,
                    child: Container(),
                  ),
                ),

                // The different tabs, displayed as a fade-in/out stack
                FadeIndexedStack(
                  curve: Curves.decelerate,
                  index: widget.currentIndex,
                  children: [
                    for (TabGridModel grid in widget.tabData.map((e) => e.tabGrid))
                      ChangeNotifierProvider<TabGridModel>.value(
                        value: grid,
                        child: const TabGrid(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
