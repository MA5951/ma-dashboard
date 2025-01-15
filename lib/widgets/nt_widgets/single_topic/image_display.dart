import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:flutter/material.dart';
import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_dropdown_chooser.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ImageDisplayModel extends SingleTopicNTWidgetModel {
  @override
  String type = ImageDisplayWidget.widgetType;

  Map<String, String> _valueToImageMap = {};
  List<String> availableImages = [];

  Map<String, String> get valueToImageMap => _valueToImageMap;

  set valueToImageMap(Map<String, String> value) {
    _valueToImageMap = value;
    refresh();
  }

  ImageDisplayModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    Map<String, String>? valueToImageMap,
    super.dataType,
    super.period,
  })  : _valueToImageMap = valueToImageMap ?? {},
        super() {
    _loadAvailableImages();
  }

  ImageDisplayModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData) {
    _valueToImageMap = Map<String, String>.from(jsonData['value_to_image'] ?? {});
    _loadAvailableImages();
  }

  Future<void> _loadAvailableImages() async {
    try {
      // Load the asset manifest to get all image paths
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Filter image paths within the "assets/images/" directory and only `.png` files
      availableImages = manifestMap.keys
          .where((path) => path.startsWith('assets/images/') && path.endsWith('.png'))
          .map((path) => path.replaceFirst('assets/images/', ''))
          .toList();
    } catch (e) {
      availableImages = []; // Fallback if there is an error
    }
    refresh();
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'value_to_image': _valueToImageMap,
    };
  }

  @override
  List<Widget> getEditProperties(BuildContext context) {
    return [
      const Divider(),
      const Text('Map values to images'),
      for (var entry in _valueToImageMap.entries)
        Row(
          children: [
            Flexible(
              child: DialogTextInput(
                label: 'Value',
                initialText: entry.key,
                onSubmit: (newValue) {
                  _valueToImageMap.remove(entry.key);
                  _valueToImageMap[newValue] = entry.value;
                  refresh();
                },
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: DialogDropdownChooser<String>(
                // label: 'Image Name',
                choices: availableImages,
                initialValue: entry.value,
                onSelectionChanged: (newImage) {
                  if (newImage != null) {
                    _valueToImageMap[entry.key] = newImage;
                    refresh();
                  }
                },
              ),
            ),
          ],
        ),
      TextButton(
        onPressed: () {
          _valueToImageMap['new_value'] =
              availableImages.isNotEmpty ? availableImages.first : '';
          refresh();
        },
        child: const Text('Add Mapping'),
      ),
    ];
  }
}

class ImageDisplayWidget extends NTWidget {
  static const String widgetType = 'Image Display';

  const ImageDisplayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ImageDisplayModel model = cast(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (context, data, child) {
        String value = (data is String) ? data : data.toString();

        String? imageName = model.valueToImageMap[value];
        if (imageName == null || imageName.isEmpty) {
          return Center(
            child: Text(
              "No image mapped for value: $value",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return Container(
          child: Image.asset(
            'assets/images/$imageName',
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
