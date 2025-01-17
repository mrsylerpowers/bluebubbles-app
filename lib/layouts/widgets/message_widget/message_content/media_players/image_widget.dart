import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ImageWidgetController extends GetxController {
  bool navigated = false;
  bool visible = true;
  final Rxn<Uint8List> data = Rxn<Uint8List>();
  final PlatformFile file;
  final Attachment attachment;
  final BuildContext context;
  ImageWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    initBytes();
    super.onInit();
  }

  void initBytes({bool runForcefully = false}) async {
    // initGate prevents this from running more than once
    // Especially if the compression takes a while
    if (!runForcefully && data.value != null) return;

    // Try to get the image data from the "cache"
    Uint8List? tmpData = CurrentChat.activeChat?.getImageData(attachment);
    if (tmpData == null) {
      // If it's an image, compress the image when loading it
      if (kIsWeb || file.path == null) {
        if (attachment.guid != "redacted-mode-demo-attachment") {
          tmpData = file.bytes;
        } else {
          data.value = Uint8List.view((await rootBundle.load(attachment.transferName!)).buffer);
          return;
        }
      } else if (AttachmentHelper.canCompress(attachment) &&
          attachment.guid != "redacted-mode-demo-attachment" &&
          !attachment.guid!.contains("theme-selector")) {
        tmpData = await AttachmentHelper.compressAttachment(attachment, file.path!);
        // All other attachments can be held in memory as bytes
      } else {
        if (attachment.guid == "redacted-mode-demo-attachment" || attachment.guid!.contains("theme-selector")) {
          data.value = (await rootBundle.load(file.path!)).buffer.asUint8List();
          return;
        }
        tmpData = await File(file.path!).readAsBytes();
      }

      if (tmpData == null || CurrentChat.activeChat == null) return;
      CurrentChat.activeChat?.saveImageData(tmpData, attachment);
      if (!(attachment.mimeType?.endsWith("heic") ?? false) && !(attachment.mimeType?.endsWith("heif") ?? false)) {
        await precacheImage(MemoryImage(tmpData), context, size: attachment.width == null ? null : Size.fromWidth(attachment.width! / 2));
      }
    }
    data.value = tmpData;
  }
}

class ImageWidget extends StatelessWidget {
  final PlatformFile file;
  final Attachment attachment;
  ImageWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageWidgetController>(
      global: false,
      init: ImageWidgetController(
        file: file,
        attachment: attachment,
        context: context,
      ),
      builder: (controller) => VisibilityDetector(
        key: Key(controller.attachment.guid!),
        onVisibilityChanged: (info) {
          if (!SettingsManager().settings.lowMemoryMode.value) return;
          if (info.visibleFraction == 0 && controller.visible && !controller.navigated) {
            controller.visible = false;
            CurrentChat.activeChat?.clearImageData(controller.attachment);
            controller.update();
          } else if (!controller.visible) {
            controller.visible = true;
            controller.initBytes(runForcefully: true);
          }
        },
        child: GestureDetector(
          child: buildSwitcher(context, controller),
          onTap: () async {
            controller.navigated = true;
            CurrentChat? currentChat = CurrentChat.activeChat;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  currentChat: currentChat,
                  attachment: controller.attachment,
                  showInteractions: true,
                ),
              ),
            );
            controller.navigated = false;
          },
        ),
      ),
    );
  }

  Widget buildSwitcher(BuildContext context, ImageWidgetController controller) => AnimatedSwitcher(
      duration: Duration(milliseconds: 150),
      child: Obx(
        () => controller.data.value != null
            ? Container(
              width: controller.attachment.guid == "redacted-mode-demo-attachment" ? controller.attachment.width!.toDouble() : null,
              height: controller.attachment.guid == "redacted-mode-demo-attachment" ? controller.attachment.height!.toDouble() : null,
              child: Image.memory(
                controller.data.value!,
                // prevents the image widget from "refreshing" when the provider changes
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  return Stack(children: [
                    buildPlaceHolder(context, controller, isLoaded: wasSynchronouslyLoaded),
                    AnimatedOpacity(
                      opacity: (frame == null &&
                          controller.attachment.guid != "redacted-mode-demo-attachment" &&
                          !controller.attachment.guid!.contains("theme-selector"))
                          ? 0
                          : 1,
                      child: child,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    )
                  ]);
                },
              ),
            )
            : buildPlaceHolder(context, controller),
      ));

  Widget buildPlaceHolder(BuildContext context, ImageWidgetController controller, {bool isLoaded = false}) {
    Widget empty = Container(height: 0, width: 0);

    // Handle the cases when the image is done loading
    if (isLoaded) {
      // If we have controller.data.value and the image has a valid size, return an empty container (no placeholder)
      if (controller.data.value != null && controller.data.value!.isNotEmpty) {
        return empty;
      } else {
        // If we don't have controller.data.value, show an invalid image placeholder
        return buildImagePlaceholder(
            context,
            controller.attachment,
            Center(
                child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text("Something went wrong! Tap to display in fullscreen", textAlign: TextAlign.center),
            )));
      }
    }

    // If it's not loaded, we are in progress
    return buildImagePlaceholder(context, controller.attachment,
        controller.attachment.guid != "redacted-mode-demo-attachment"
            ? Center(child: buildProgressIndicator(context)) : Container());
  }
}
