import 'dart:convert';

import 'package:http/http.dart' as http;

import 'update_policy.dart';
import 'version.dart';

/// Where release metadata comes from.
abstract class PrismUpdateSource {
  /// Fetches the latest version per channel.
  Future<Map<UpdateChannel, PrismVersion>> fetchLatest();
}

/// A source backed by a fixed map. Useful for tests, demos, and kill switches
/// where you want to ship a version bump without a server.
class StaticUpdateSource implements PrismUpdateSource {
  /// Creates a static source.
  const StaticUpdateSource(this.latestByChannel);

  /// Latest version per channel.
  final Map<UpdateChannel, PrismVersion> latestByChannel;

  @override
  Future<Map<UpdateChannel, PrismVersion>> fetchLatest() async =>
      latestByChannel;
}

/// Fetches release metadata from an HTTP endpoint returning JSON such as:
///
/// ```json
/// {
///   "latest": {"stable": "2.1.0", "beta": "2.2.0"},
///   "minimum": "1.9.0",
///   "notes": {"2.1.0": "Bug fixes and improvements"},
///   "urls": {"android": "https://example.com/app.apk"}
/// }
/// ```
class RemoteUpdateSource implements PrismUpdateSource {
  /// Creates a remote source.
  RemoteUpdateSource({
    required this.url,
    http.Client? client,
    Map<String, String>? headers,
  })  : _client = client ?? http.Client(),
        _headers = headers ?? const {};

  /// The metadata endpoint URL.
  final Uri url;

  /// Optional extra headers (auth tokens, cache busting).
  final Map<String, String> _headers;

  final http.Client _client;

  /// The last raw payload fetched, useful for custom fields.
  Map<String, dynamic> lastPayload = const {};

  @override
  Future<Map<UpdateChannel, PrismVersion>> fetchLatest() async {
    final response = await _client.get(url, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Update metadata request failed (${response.statusCode})',
        url,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Update metadata must be a JSON object');
    }
    lastPayload = body;
    final latest = (body['latest'] as Map<String, dynamic>?) ?? const {};
    return {
      for (final entry in latest.entries)
        if (UpdateChannel.values.asNameMap().containsKey(entry.key))
          UpdateChannel.values.byName(entry.key): PrismVersion.parse(
            entry.value.toString(),
          ),
    };
  }

  /// Download URL for [platform] key (e.g. `android`, `windows`, `ios`),
  /// when the payload contains a `urls` map.
  Uri? downloadUrlFor(String platform) {
    final urls = (lastPayload['urls'] as Map<String, dynamic>?) ?? const {};
    final value = urls[platform];
    return value is String && value.isNotEmpty ? Uri.tryParse(value) : null;
  }

  /// Release notes for a version, when the payload contains a `notes` map.
  String? notesFor(PrismVersion version) {
    final notes = (lastPayload['notes'] as Map<String, dynamic>?) ?? const {};
    final value = notes[version.toString()];
    return value is String ? value : null;
  }

  /// Minimum version from the payload, when present.
  PrismVersion? get minimumVersion {
    final value = lastPayload['minimum'];
    return value is String && value.isNotEmpty
        ? PrismVersion.parse(value)
        : null;
  }
}
