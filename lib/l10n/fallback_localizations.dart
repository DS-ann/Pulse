import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FallbackMaterialLocalizationDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['mai', 'sa', 'mr', 'pa', 'ne', 'bn', 'te', 'ta', 'kn', 'or', 'ml', 'gu', 'ur', 'as', 'fr'].contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return await GlobalMaterialLocalizations.delegate.load(const Locale('hi'));
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

class FallbackCupertinoLocalizationDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['mai', 'sa', 'mr', 'pa', 'ne', 'bn', 'te', 'ta', 'kn', 'or', 'ml', 'gu', 'ur', 'as', 'fr'].contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    return await GlobalCupertinoLocalizations.delegate.load(const Locale('hi'));
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FallbackWidgetsLocalizationDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => ['mai', 'sa', 'mr', 'pa', 'ne', 'bn', 'te', 'ta', 'kn', 'or', 'ml', 'gu', 'ur', 'as', 'fr'].contains(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    return await GlobalWidgetsLocalizations.delegate.load(const Locale('hi'));
  }

  @override
  bool shouldReload(FallbackWidgetsLocalizationDelegate old) => false;
}
