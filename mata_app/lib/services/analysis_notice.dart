import 'dart:async';

import 'package:http/http.dart' as http;

/// Why an analysis could not go ahead, told to the user in plain words:
/// what went wrong, and what to do about it.
class AnalysisNotice {
  const AnalysisNotice({
    required this.title,
    required this.message,
    required this.suggestion,
  });

  final String title;
  final String message;
  final String suggestion;

  /// Fewer words than this, with nothing found, reads as "too short".
  static const int _minWords = 4;

  static const tooShort = AnalysisNotice(
    title: 'Tell us a little more',
    message: 'Your description is too short for us to find any symptoms.',
    suggestion:
        'Say what you feel, where you feel it and since when. For example: '
        '“I’ve had a sore throat and a fever since yesterday.”',
  );

  static const notRecognized = AnalysisNotice(
    title: 'We couldn’t find any symptoms',
    message: 'We didn’t recognize a symptom in your description.',
    suggestion:
        'Try describing what you feel in simple, everyday words, such as '
        '“headache”, “fever” or “pain in my lower back”.',
  );

  static const notRecognizedLimited = AnalysisNotice(
    title: 'We couldn’t find any symptoms',
    message:
        'We didn’t recognize a symptom in your description. Part of our '
        'analysis is unavailable right now, so less common wording may be '
        'missed.',
    suggestion:
        'Try describing what you feel in simple, everyday words, such as '
        '“headache”, “fever” or “pain in my lower back”.',
  );

  static const notCurrent = AnalysisNotice(
    title: 'Nothing current to assess',
    message:
        'The symptoms we found seem to be from the past or part of a family '
        'history, not something you feel now.',
    suggestion:
        'Describe what you are feeling now. For example: '
        '“I’ve had a cough for three days.”',
  );

  static const noneConfirmed = AnalysisNotice(
    title: 'No symptoms to assess',
    message:
        'None of the symptoms were confirmed as present, '
        'so there is nothing to assess.',
    suggestion:
        'If you do feel unwell, edit your description '
        'to say what you feel now.',
  );

  static const unreachable = AnalysisNotice(
    title: "We couldn’t reach Ma'ta",
    message: 'The analysis service did not respond.',
    suggestion:
        "Check your internet connection and that the Ma'ta server "
        'is running, then try again.',
  );

  static const failed = AnalysisNotice(
    title: 'Something went wrong',
    message: 'We could not analyze your description this time.',
    suggestion: 'Please try again in a moment.',
  );

  /// The notice for an extraction result, or null when there is something
  /// for the user to review.
  static AnalysisNotice? fromExtraction(
    Map<String, dynamic> result,
    String description,
  ) {
    bool has(String field) {
      final value = result[field];
      return value is List && value.isNotEmpty;
    }

    if (['symptoms', 'negated', 'clarify', 'confirm'].any(has)) {
      return null;
    }

    // Found, but set aside: a past illness or a family history.
    final excluded = result['excluded'];
    if (excluded is List &&
        excluded.any(
          (e) =>
              e is Map && const {'historical', 'family'}.contains(e['status']),
        )) {
      return notCurrent;
    }

    final words = description.trim().split(RegExp(r'\s+'));
    if (words.length < _minWords) {
      return tooShort;
    }

    return result['degraded'] == true ? notRecognizedLimited : notRecognized;
  }

  /// The notice for a request that failed before any result came back.
  static AnalysisNotice fromError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return unreachable;
    }
    return failed;
  }
}
