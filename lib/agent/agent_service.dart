import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_agent.dart';
import 'fitness_agent.dart';
import 'rule_engine_agent.dart';

/// Central service that manages the FitnessAgent backends.
///
/// Always has a [RuleEngineAgent] available. Optionally configures an
/// [ApiAgent] when the user provides API credentials.
///
/// Listens for config changes via [addListener] / [removeListener].
class FitnessAgentService extends ValueNotifier<FitnessAgentServiceSnapshot> {
  FitnessAgentService._()
      : super(FitnessAgentServiceSnapshot._(
          ruleEngine: RuleEngineAgent(),
          apiAgent: null,
          config: const ApiAgentConfig(),
        ));

  static final FitnessAgentService _instance = FitnessAgentService._();
  static FitnessAgentService get instance => _instance;

  RuleEngineAgent get ruleEngine => value.ruleEngine;
  ApiAgent? get apiAgent => value.apiAgent;
  ApiAgentConfig get config => value.config;

  /// Returns the best available agent: API if enabled, otherwise rule engine.
  FitnessAgent get currentAgent {
    final api = value.apiAgent;
    if (api != null && api.isAvailable) return api;
    return value.ruleEngine;
  }

  /// Whether the API agent is currently being used.
  bool get isUsingApi => value.apiAgent?.isAvailable ?? false;

  /// Update API config and persist it.
  Future<void> updateConfig(ApiAgentConfig newConfig) async {
    final api = newConfig.enabled && newConfig.apiKey.isNotEmpty
        ? ApiAgent(newConfig)
        : null;

    value = FitnessAgentServiceSnapshot._(
      ruleEngine: value.ruleEngine,
      apiAgent: api,
      config: newConfig,
    );

    await _saveConfig(newConfig);
  }

  // ── Persistence (encrypted via flutter_secure_storage) ────────────────

  static const _kPrefix = 'kailian_agent';
  static const _kEndpoint = '$_kPrefix:endpoint';
  static const _kApiKey = '$_kPrefix:apiKey';
  static const _kModel = '$_kPrefix:model';
  static const _kEnabled = '$_kPrefix:enabled';

  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> loadConfig() async {
    try {
      final storedEndpoint = await _storage.read(key: _kEndpoint);
      // Migrate the old OpenAI placeholder so a fresh DeepSeek setup does not
      // silently keep sending requests to an endpoint the user never chose.
      final endpoint = storedEndpoint == null ||
              storedEndpoint.contains('api.openai.com')
          ? _defaultConfig.endpoint
          : storedEndpoint;
      final apiKey =
          await _storage.read(key: _kApiKey) ?? _defaultConfig.apiKey;
      final storedModel = await _storage.read(key: _kModel);
      final model = storedModel == null || storedModel == 'gpt-4o-mini'
          ? _defaultConfig.model
          : storedModel;
      final enabledStr = await _storage.read(key: _kEnabled);
      final enabled = enabledStr == 'true';

      final loadedConfig = ApiAgentConfig(
        endpoint: endpoint,
        apiKey: apiKey,
        model: model,
        enabled: enabled,
      );
      // Skip updateConfig to avoid writing back what we just read.
      final api = enabled && apiKey.isNotEmpty ? ApiAgent(loadedConfig) : null;
      value = FitnessAgentServiceSnapshot._(
        ruleEngine: value.ruleEngine,
        apiAgent: api,
        config: loadedConfig,
      );
    } catch (e) {
      debugPrint('FitnessAgentService.loadConfig: $e');
    }
  }

  Future<void> _saveConfig(ApiAgentConfig cfg) async {
    try {
      await Future.wait([
        _storage.write(key: _kEndpoint, value: cfg.endpoint),
        _storage.write(key: _kApiKey, value: cfg.apiKey),
        _storage.write(key: _kModel, value: cfg.model),
        _storage.write(key: _kEnabled, value: cfg.enabled.toString()),
      ]);
    } catch (e) {
      debugPrint('FitnessAgentService._saveConfig: $e');
    }
  }

  static ApiAgentConfig get _defaultConfig => const ApiAgentConfig();

  /// Call on app startup to restore persisted config.
  static Future<void> initialize() async {
    await instance.loadConfig();
  }
}

/// Immutable snapshot of the agent service state.
class FitnessAgentServiceSnapshot {
  final RuleEngineAgent ruleEngine;
  final ApiAgent? apiAgent;
  final ApiAgentConfig config;

  FitnessAgentServiceSnapshot._({
    required this.ruleEngine,
    required this.apiAgent,
    required this.config,
  });
}
