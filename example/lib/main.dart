import 'dart:io';

import 'package:flutter/material.dart';
import 'package:prism_updater/prism_updater.dart';

/// Serves release metadata on a local HTTP server so the example is fully
/// self-contained — no external endpoint needed.
///
/// In production you would host this JSON on GitHub Pages, S3, Firebase
/// Hosting, or your own API. The schema:
///
/// ```json
/// {
///   "latest":  { "stable": "2.1.0", "beta": "2.2.0" },
///   "minimum": { "stable": "1.5.0" },
///   "notes":   { "2.1.0": "What's new in this release" },
///   "urls": {
///     "android": "https://…/app.apk",
///     "ios":     "https://apps.apple.com/app/id…",
///     "windows": "https://…/setup.exe",
///     "web":     "https://…/download"
///   }
/// }
/// ```
const String releaseMetadata = '''
{
  "latest": {"stable": "2.1.0", "beta": "2.3.0"},
  "minimum": {"stable": "1.5.0"},
  "notes": {"2.1.0": "Bug fixes, a new gate widget, and faster checks."},
  "urls": {
    "android": "https://github.com/awaisdev5765/prism_updater/releases",
    "ios": "https://apps.apple.com/developer/example/id1",
    "windows": "https://github.com/awaisdev5765/prism_updater/releases",
    "web": "https://pub.dev/packages/prism_updater"
  }
}
''';

Future<void> main() async {
  final server = await _MetadataServer.start();
  runApp(_ExampleApp(metadataUrl: server.url));
}

/// Tiny HTTP server that serves [releaseMetadata] on any GET request.
class _MetadataServer {
  _MetadataServer._(this.url);

  final Uri url;

  static Future<_MetadataServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final _MetadataServer holder;
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(releaseMetadata);
      await request.response.close();
    });
    holder = _MetadataServer._(
      Uri.parse('http://localhost:${server.port}/updates.json'),
    );
    return holder;
  }
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp({required this.metadataUrl});

  final Uri metadataUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'prism_updater example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: UpdatePlayground(metadataUrl: metadataUrl),
    );
  }
}

/// Interactive playground: pick the installed version and the gate behavior,
/// then run a check and watch the update flow react.
/// Interactive playground showing the gate in action.
class UpdatePlayground extends StatefulWidget {
  /// Creates the playground.
  const UpdatePlayground({required this.metadataUrl, super.key});

  /// The release metadata endpoint.
  final Uri metadataUrl;

  @override
  State<UpdatePlayground> createState() => _UpdatePlaygroundState();
}

/// State for [UpdatePlayground].
class _UpdatePlaygroundState extends State<UpdatePlayground> {
  // Try changing this to '2.1.0' (up to date) or '1.2.0' (forced update).
  String _installedVersion = '1.4.2';

  // Try switching between block and banner to see both soft-update flows.
  GateBehavior _behavior = GateBehavior.block;

  bool _autoCheck = true;

  PrismUpdateController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _rebuildController() {
    _controller?.dispose();
    final controller = PrismUpdateController(
      source: RemoteUpdateSource(url: widget.metadataUrl),
      currentVersion: PrismVersion.parse(_installedVersion),
      autoCheck: _autoCheck,
    );
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    _rebuildController();
    final controller = _controller!;

    return Scaffold(
      appBar: AppBar(title: const Text('prism_updater example')),
      body: PrismUpdateGate(
        controller: controller,
        behavior: _behavior,
        child: _PlaygroundControls(
          installedVersion: _installedVersion,
          behavior: _behavior,
          autoCheck: _autoCheck,
          controller: controller,
          onVersionChanged: (v) =>
              setState(() => _installedVersion = v),
          onBehaviorChanged: (b) => setState(() => _behavior = b),
          onAutoCheckChanged: (v) => setState(() => _autoCheck = v),
          onRecheck: () => controller.checkNow(),
        ),
      ),
    );
  }
}

class _PlaygroundControls extends StatelessWidget {
  const _PlaygroundControls({
    required this.installedVersion,
    required this.behavior,
    required this.autoCheck,
    required this.controller,
    required this.onVersionChanged,
    required this.onBehaviorChanged,
    required this.onAutoCheckChanged,
    required this.onRecheck,
  });

  final String installedVersion;
  final GateBehavior behavior;
  final bool autoCheck;
  final PrismUpdateController controller;
  final ValueChanged<String> onVersionChanged;
  final ValueChanged<GateBehavior> onBehaviorChanged;
  final ValueChanged<bool> onAutoCheckChanged;
  final VoidCallback onRecheck;

  static const _versions = ['1.2.0', '1.4.2', '2.1.0', '2.3.0'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            Text(
              'Update playground',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick an installed version and a gate behavior, then watch the '
              'update flow react. The metadata is served by a local HTTP '
              'server embedded in this example.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                for (final v in _versions)
                  ButtonSegment(value: v, label: Text(v)),
              ],
              selected: {installedVersion},
              onSelectionChanged: (selection) => onVersionChanged(
                selection.first,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (installedVersion) {
                '1.2.0' => 'Below minimum (1.5.0) → forced update',
                '1.4.2' => 'Above minimum, below latest → soft update',
                _ => 'Up to date → nothing is shown',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<GateBehavior>(
              segments: const [
                ButtonSegment(
                  value: GateBehavior.block,
                  label: Text('Block'),
                ),
                ButtonSegment(
                  value: GateBehavior.banner,
                  label: Text('Banner'),
                ),
              ],
              selected: {behavior},
              onSelectionChanged: (s) => onBehaviorChanged(s.first),
            ),
            SwitchListTile(
              title: const Text('Auto-check on start'),
              value: autoCheck,
              onChanged: onAutoCheckChanged,
            ),
            FilledButton.icon(
              onPressed: onRecheck,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for updates now'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live controller state',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      PrismUpdateStatusView(state: controller.state),
                      const SizedBox(height: 4),
                      Text(
                        'Platform: ${controller.platformInfo.key}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
