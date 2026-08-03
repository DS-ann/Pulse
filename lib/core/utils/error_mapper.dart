import 'package:flutter/widgets.dart';
import 'package:pulse/l10n/app_localizations.dart';

class ErrorMapper {
  // ── Active locale for background (context-free) usage ─────────────────────
  // Defaults to 'en'. Call ErrorMapper.setLocale(locale) when the user
  // changes their app language so background errors match the UI language.
  static Locale _activeLocale = const Locale('en');

  static void setLocale(Locale locale) {
    _activeLocale = locale;
  }

  // ── Background (no BuildContext) ───────────────────────────────────────────
  static String getLocalizedErrorBackground(dynamic error) {
    if (error == null) return '';
    final l10n = lookupAppLocalizations(_activeLocale);
    return _mapError(l10n, error.toString());
  }

  // ── UI (with BuildContext) ─────────────────────────────────────────────────
  static String getLocalizedError(BuildContext context, dynamic error) {
    if (error == null) return '';
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return error.toString();
    return _mapError(l10n, error.toString());
  }

  // ── Core mapping logic ─────────────────────────────────────────────────────
  static String _mapError(AppLocalizations l10n, String raw) {
    // Special Spotify RAW_403 protocol
    if (raw.startsWith('RAW_403:')) {
      final parts = raw.substring(8).split('|');
      final data = parts[0];
      final err = parts.length > 1 ? parts.sublist(1).join('|') : '';
      return l10n.spotifyRawResponseError(data, err);
    }

    final lower = raw.toLowerCase();

    // ── Network / connectivity ────────────────────────────────────────────────
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable')) {
      return l10n.apiErrorNetwork;
    }
    if (lower.contains('connection timeout') ||
        lower.contains('connect timeout') ||
        lower.contains('receive timeout') ||
        lower.contains('send timeout') ||
        lower.contains('timed out')) {
      return l10n.apiErrorSocketTimeout;
    }

    // ── HTTP status codes ─────────────────────────────────────────────────────
    if (lower.contains('bad request') || lower.contains('400')) {
      return l10n.apiErrorBadRequest;
    }
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return l10n.apiErrorUnauthorized;
    }
    if (lower.contains('forbidden') || lower.contains('403')) {
      return l10n.apiErrorForbidden;
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return l10n.apiErrorNotFound;
    }
    if (lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('too many')) {
      return l10n.apiErrorTooManyRequests;
    }
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('internal server') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return l10n.apiErrorServerError;
    }

    // ── Spotify / generic ─────────────────────────────────────────────────────
    if (lower.contains('invalid client')) return l10n.apiErrorInvalidClient;

    // ── Firebase Auth ─────────────────────────────────────────────────────────
    if (lower.contains('auth/email-already-in-use')) return l10n.apiErrorEmailInUse;
    if (lower.contains('auth/user-not-found')) return l10n.apiErrorUserNotFound;
    if (lower.contains('auth/wrong-password')) return l10n.apiErrorWrongPassword;
    if (lower.contains('auth/invalid-credential')) return l10n.apiErrorInvalidCredential;
    if (lower.contains('auth/invalid-email')) return l10n.apiErrorInvalidEmail;
    if (lower.contains('auth/weak-password')) return l10n.apiErrorWeakPassword;
    if (lower.contains('auth/too-many-requests')) return l10n.apiErrorTooManyAttempts;
    if (lower.contains('auth/network-request-failed')) return l10n.apiErrorNetwork;

    // ── Fallback: strip internal exception noise ───────────────────────────────
    return raw
        .replaceAll('Exception: ', '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll('Firebase: ', '')
        .replaceAll(RegExp(r'\(auth/.*\)'), '')
        .trim();
  }
}
