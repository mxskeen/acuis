/// AI Provider Configuration
///
/// Supports OpenAI-compatible APIs (NVIDIA NIM, OpenAI, Groq, Together, etc.)
class AIConfig {
  // Default configuration - uses our secure backend proxy
  // Backend URL is injected at build time via --dart-define=BACKEND_URL
  // This is set via GitHub Secrets in CI/CD - never hardcoded in source code
  static const String defaultBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  static const String defaultApiUrl = '$defaultBackendUrl/api/chat/completions';
  static const String defaultModel = 'mistralai/mistral-small-4-119b-2603';

  // No API key needed for built-in backend - it's handled server-side
  // This keeps the key secure and never exposed in the client app
  static const String builtInApiKey = 'backend-proxy';

  final String? customApiKey;
  final String? customApiUrl;
  final String? customModel;
  final bool useCustomProvider;

  const AIConfig({
    this.customApiKey,
    this.customApiUrl,
    this.customModel,
    this.useCustomProvider = false,
  });

  /// Get the effective API key
  String get effectiveApiKey {
    if (useCustomProvider && customApiKey != null && customApiKey!.isNotEmpty) {
      return customApiKey!;
    }
    return builtInApiKey;
  }

  /// Get the effective API URL
  String get effectiveApiUrl {
    if (useCustomProvider && customApiUrl != null && customApiUrl!.isNotEmpty) {
      return customApiUrl!;
    }
    return defaultApiUrl;
  }

  /// Get the effective model
  String get effectiveModel {
    if (useCustomProvider && customModel != null && customModel!.isNotEmpty) {
      return customModel!;
    }
    return defaultModel;
  }

  /// Check if AI is available (has valid key and backend URL)
  bool get isAvailable => effectiveApiKey.isNotEmpty && defaultBackendUrl.isNotEmpty;

  /// Check if using built-in provider
  bool get usingBuiltIn => !useCustomProvider;

  /// Check if using custom provider
  bool get usingCustom => useCustomProvider && customApiKey != null && customApiKey!.isNotEmpty;

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      customApiKey: json['customApiKey'] as String?,
      customApiUrl: json['customApiUrl'] as String?,
      customModel: json['customModel'] as String?,
      useCustomProvider: json['useCustomProvider'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'customApiKey': customApiKey,
    'customApiUrl': customApiUrl,
    'customModel': customModel,
    'useCustomProvider': useCustomProvider,
  };

  AIConfig copyWith({
    String? customApiKey,
    String? customApiUrl,
    String? customModel,
    bool? useCustomProvider,
  }) {
    return AIConfig(
      customApiKey: customApiKey ?? this.customApiKey,
      customApiUrl: customApiUrl ?? this.customApiUrl,
      customModel: customModel ?? this.customModel,
      useCustomProvider: useCustomProvider ?? this.useCustomProvider,
    );
  }
}
