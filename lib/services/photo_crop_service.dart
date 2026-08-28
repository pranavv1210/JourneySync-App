import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

class PhotoCropService {
  PhotoCropService._();

  static Future<CroppedFile?> pickAndCrop({
    required ImageSource source,
    required String title,
    required CropAspectRatio aspectRatio,
    CropAspectRatioPreset initAspectRatio = CropAspectRatioPreset.square,
    int imageQuality = 88,
    double? maxWidth,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
    if (picked == null) return null;

    return ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: aspectRatio,
      compressQuality: imageQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppColors.forest,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: initAspectRatio,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
  }
}
