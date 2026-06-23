 import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../themes/app_theme.dart';

void showSuccessToast(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    backgroundColor: AppTheme.secondary,
    textColor: Colors.white,
  );
}

void showErrorToast(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    backgroundColor: AppTheme.danger,
    textColor: Colors.white,
  );
}