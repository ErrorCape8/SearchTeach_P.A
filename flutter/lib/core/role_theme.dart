import 'package:flutter/material.dart';

ThemeData withRoleAccent(ThemeData theme, Color accent) => theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
    );
