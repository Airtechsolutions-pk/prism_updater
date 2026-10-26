import 'version.dart';

/// Update channel a release belongs to.
enum UpdateChannel {
  /// Stable public releases.
  stable,

  /// Beta channel — receives releases earlier.
  beta,

  /// Alpha/nightly channel.
  alpha,
}

/// What the policy decided the app should do.
enum UpdateDecision {
  /// Current version satisfies the policy; nothing to show.
  upToDate,

  /// A newer version exists but updating is optional.
  softUpdate,

  /// The current version is below the minimum; updating is required.
  forcedUpdate,
}

/// The result of evaluating an update policy.
class UpdatePolicyResult {
  /// Creates a policy result.
  const UpdatePolicyResult(this.decision, {this.latest, this.minimum});

  /// The decision reached.
  final UpdateDecision decision;

  /// The latest available version, when known.
  final PrismVersion? latest;

  /// The minimum supported version, when known.
  final PrismVersion? minimum;

  /// Whether a forced update is required.
  bool get isForced => decision == UpdateDecision.forcedUpdate;

  /// Whether an update is available (soft or forced).
  bool get isUpdateAvailable => decision != UpdateDecision.upToDate;
}

/// Decides whether the running app should update.
///
/// Extend or compose this to plug in custom rules (staged rollouts, kill
/// switches, per-country gating, etc.).
class UpdatePolicy {
  /// Creates a policy.
  const UpdatePolicy({
    this.minimumVersion,
    this.channels = const {UpdateChannel.stable},
    this.allowSkippedVersions = true,
  });

  /// Builds a policy from a remote configuration map, e.g.:
  ///
  /// ```json
  /// {
  ///   "latest": {"stable": "2.1.0", "beta": "2.2.0-beta.1"},
  ///   "minimum": {"stable": "1.9.0"}
  /// }
  /// ```
  factory UpdatePolicy.fromJson(Map<String, dynamic> json) {
    final latestMap = (json['latest'] as Map<String, dynamic>?) ?? const {};
    final minimumMap = (json['minimum'] as Map<String, dynamic>?) ?? const {};
    final minimumForStable = minimumMap['stable'] as String?;
    return UpdatePolicy(
      minimumVersion:
          minimumForStable == null ? null : PrismVersion.parse(minimumForStable),
      channels: {
        for (final channel in UpdateChannel.values)
          if (latestMap.containsKey(channel.name)) channel,
      },
    );
  }

  /// Below this version an update is forced. `null` disables forced updates.
  final PrismVersion? minimumVersion;

  /// Channels considered when resolving the latest version.
  final Set<UpdateChannel> channels;

  /// Whether users may skip non-forced versions they've dismissed before.
  final bool allowSkippedVersions;

  /// Evaluates [current] against the policy using the latest known
  /// version per channel in [latestByChannel].
  UpdatePolicyResult evaluate(
    PrismVersion current,
    Map<UpdateChannel, PrismVersion> latestByChannel,
  ) {
    final candidates = [
      for (final channel in channels) ...[
        ?latestByChannel[channel],
      ],
    ];
    if (candidates.isEmpty) {
      return const UpdatePolicyResult(UpdateDecision.upToDate);
    }
    final latest = candidates.reduce(
      (a, b) => a >= b ? a : b,
    );

    final minimum = minimumVersion;
    if (minimum != null && current < minimum) {
      return UpdatePolicyResult(
        UpdateDecision.forcedUpdate,
        latest: latest,
        minimum: minimum,
      );
    }
    if (current < latest) {
      return UpdatePolicyResult(
        UpdateDecision.softUpdate,
        latest: latest,
        minimum: minimum,
      );
    }
    return UpdatePolicyResult(
      UpdateDecision.upToDate,
      latest: latest,
      minimum: minimum,
    );
  }
}
